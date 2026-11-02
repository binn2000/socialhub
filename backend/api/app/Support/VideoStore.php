<?php

namespace App\Support;

use Illuminate\Contracts\Filesystem\Filesystem;
use Illuminate\Http\File;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Process;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Uploaded videos. The upload is checked with ffprobe, kept as it came on the images disk,
 * and later converted by ProcessPostVideo into one H.264/AAC mp4 (720 px wide at most,
 * `faststart` so playback begins before the download ends) plus a JPEG thumbnail.
 */
class VideoStore
{
    public const MAX_KB = 51200;

    public const MAX_SECONDS = 60;

    /** Rules for the optional `video` field. */
    public static function rules(): array
    {
        return ['nullable', 'file', 'mimetypes:video/mp4,video/quicktime,video/webm', 'max:'.self::MAX_KB];
    }

    private static function disk(): Filesystem
    {
        return Storage::disk(config('filesystems.images_disk'));
    }

    public static function url(?string $path): ?string
    {
        return $path ? self::disk()->url($path) : null;
    }

    /**
     * Reads width, height and duration, or fails validation when the file is not a video
     * of at most MAX_SECONDS.
     *
     * @return array{width: int, height: int, duration: int}
     */
    public static function probe(string $file, string $field = 'video'): array
    {
        $result = Process::timeout(30)->run([
            config('services.ffmpeg.ffprobe'), '-v', 'error', '-print_format', 'json',
            '-show_streams', '-show_format', $file,
        ]);
        $info = $result->successful() ? json_decode($result->output(), true) : null;
        $video = collect($info['streams'] ?? [])->firstWhere('codec_type', 'video');

        if (! $video || empty($video['width']) || empty($video['height'])) {
            self::fail($field, __('The file must be a video.'));
        }

        $duration = (float) ($info['format']['duration'] ?? $video['duration'] ?? 0);
        if ($duration <= 0) {
            self::fail($field, __('The file must be a video.'));
        }
        if ($duration > self::MAX_SECONDS + 0.5) {
            self::fail($field, __('The video must be at most :seconds seconds long.', ['seconds' => self::MAX_SECONDS]));
        }

        return [
            'width' => (int) $video['width'],
            'height' => (int) $video['height'],
            'duration' => max(1, (int) round($duration)),
        ];
    }

    /** Keeps the upload as sent until it has been converted. */
    public static function storeSource(UploadedFile $file): string
    {
        $extension = strtolower(preg_replace('/[^a-z0-9]/i', '', $file->getClientOriginalExtension())) ?: 'mp4';
        $path = strtolower('videos/source/'.now()->format('Y/m').'/'.Str::ulid()->toBase32().'.'.$extension);
        self::disk()->putFileAs(dirname($path), $file, basename($path));

        return $path;
    }

    public static function delete(?string $path): void
    {
        if ($path) {
            self::disk()->delete($path);
        }
    }

    /**
     * Converts the stored source into the final mp4 and thumbnail and stores both.
     *
     * @return array{video: string, thumbnail: string, width: int, height: int, duration: int}
     */
    public static function convert(string $sourcePath): array
    {
        $work = sys_get_temp_dir().'/socialhub-video-'.Str::ulid()->toBase32();
        mkdir($work, 0700, true);

        try {
            $in = $work.'/in.'.pathinfo($sourcePath, PATHINFO_EXTENSION);
            $stream = self::disk()->readStream($sourcePath);
            file_put_contents($in, $stream);
            is_resource($stream) && fclose($stream);

            $ffmpeg = config('services.ffmpeg.binary');
            $out = $work.'/out.mp4';
            Process::timeout(240)->run([
                $ffmpeg, '-y', '-i', $in, '-t', (string) (self::MAX_SECONDS + 1),
                '-vf', "scale='min(720,iw)':-2",
                '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '28', '-pix_fmt', 'yuv420p',
                '-c:a', 'aac', '-b:a', '96k', '-movflags', '+faststart', $out,
            ])->throw();

            $meta = self::probe($out);
            $thumb = $work.'/thumb.jpg';
            Process::timeout(60)->run([
                $ffmpeg, '-y', '-ss', $meta['duration'] > 2 ? '1' : '0', '-i', $out,
                '-frames:v', '1', '-vf', 'scale=480:-2', $thumb,
            ])->throw();

            $base = strtolower('videos/'.now()->format('Y/m').'/'.Str::ulid()->toBase32());
            self::disk()->putFileAs(dirname($base), new File($out), basename($base).'.mp4');
            self::disk()->putFileAs(dirname($base), new File($thumb), basename($base).'.jpg');

            return [
                'video' => $base.'.mp4',
                'thumbnail' => $base.'.jpg',
                'width' => $meta['width'],
                'height' => $meta['height'],
                'duration' => $meta['duration'],
            ];
        } finally {
            array_map('unlink', glob($work.'/*') ?: []);
            @rmdir($work);
        }
    }

    private static function fail(string $field, string $message): never
    {
        throw ValidationException::withMessages([$field => [$message]]);
    }
}
