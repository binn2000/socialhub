<?php

namespace App\Support;

use App\Jobs\DeleteStoredImage;
use GdImage;
use Illuminate\Contracts\Filesystem\Filesystem;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Uploaded images: the real content is checked (not the extension), the picture is
 * re-encoded (which drops EXIF/GPS metadata) and stored on the public disk as
 * {folder}/{yyyy}/{mm}/{ulid}.{jpg|png|webp}. Only that relative path goes in the database.
 */
class ImageStore
{
    public const MAX_KB = 10240;
    private const MAX_SIDE = 8000;
    private const TYPES = [
        IMAGETYPE_JPEG => 'jpg',
        IMAGETYPE_PNG => 'png',
        IMAGETYPE_WEBP => 'webp',
    ];

    /** Rules for an optional or required image field. */
    public static function rules(bool $required = false): array
    {
        return [$required ? 'required' : 'nullable', 'file', 'mimes:jpg,jpeg,png,webp', 'max:'.self::MAX_KB];
    }

    private static function disk(): Filesystem
    {
        return Storage::disk(config('filesystems.images_disk'));
    }

    public static function url(?string $path): ?string
    {
        return $path ? self::disk()->url($path) : null;
    }

    public static function delete(?string $path): void
    {
        if ($path) {
            self::disk()->delete($path);
        }
    }

    /** Deletes the file on the queue (used once the database no longer points at it). */
    public static function deleteLater(?string $path): void
    {
        if ($path) {
            DeleteStoredImage::dispatch($path)->afterCommit();
        }
    }

    /** @return string the stored relative path */
    public static function store(UploadedFile $file, string $folder, string $field = 'image'): string
    {
        $info = @getimagesize($file->getRealPath());

        if (! $info || ! isset(self::TYPES[$info[2]])) {
            self::fail($field, __('The file must be a JPEG, PNG or WebP image.'));
        }
        if ($info[0] > self::MAX_SIDE || $info[1] > self::MAX_SIDE) {
            self::fail($field, __('The image must be at most :side x :side pixels.', ['side' => self::MAX_SIDE]));
        }

        // A decoded 8000 x 8000 image needs far more than the default 128 MB.
        ini_set('memory_limit', '768M');

        $type = $info[2];
        $image = match ($type) {
            IMAGETYPE_JPEG => @imagecreatefromjpeg($file->getRealPath()),
            IMAGETYPE_PNG => @imagecreatefrompng($file->getRealPath()),
            IMAGETYPE_WEBP => @imagecreatefromwebp($file->getRealPath()),
        };
        if (! $image) {
            self::fail($field, __('The image could not be read.'));
        }

        if ($type === IMAGETYPE_JPEG) {
            $image = self::applyOrientation($image, $file->getRealPath());
        }

        $data = self::encode($image, $type);
        $path = $folder.'/'.now()->format('Y/m').'/'.Str::ulid()->toBase32().'.'.self::TYPES[$type];
        $path = strtolower($path);
        self::disk()->put($path, $data);

        return $path;
    }

    /** Stores a document as it is (the caller has already checked its type) under a random name. */
    public static function storeFile(UploadedFile $file, string $folder): string
    {
        $extension = strtolower(preg_replace('/[^a-z0-9]/i', '', $file->getClientOriginalExtension()));
        $path = strtolower($folder.'/'.now()->format('Y/m').'/'.Str::ulid()->toBase32().($extension !== '' ? '.'.$extension : ''));
        self::disk()->put($path, file_get_contents($file->getRealPath()));

        return $path;
    }

    public static function read(string $path): string
    {
        return self::disk()->get($path);
    }

    public static function size(string $path): int
    {
        return (int) self::disk()->size($path);
    }

    /** Width and height of a stored image. */
    public static function dimensions(string $path): ?array
    {
        $info = @getimagesizefromstring(self::disk()->get($path));

        return $info ? [$info[0], $info[1]] : null;
    }

    /** Phone photos are often stored sideways with an EXIF flag; bake the rotation in before the flag is dropped. */
    private static function applyOrientation(GdImage $image, string $file): GdImage
    {
        $exif = function_exists('exif_read_data') ? @exif_read_data($file) : false;
        $angle = match ($exif['Orientation'] ?? 1) {
            3 => 180,
            6 => -90,
            8 => 90,
            default => 0,
        };

        return $angle ? (imagerotate($image, $angle, 0) ?: $image) : $image;
    }

    private static function encode(GdImage $image, int $type): string
    {
        ob_start();
        match ($type) {
            IMAGETYPE_JPEG => imagejpeg($image, null, 85),
            IMAGETYPE_PNG => (function () use ($image) {
                imagealphablending($image, false);
                imagesavealpha($image, true);
                imagepng($image);
            })(),
            IMAGETYPE_WEBP => imagewebp($image, null, 85),
        };

        return ob_get_clean();
    }

    private static function fail(string $field, string $message): never
    {
        throw ValidationException::withMessages([$field => [$message]]);
    }
}
