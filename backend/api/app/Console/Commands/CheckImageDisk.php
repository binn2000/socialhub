<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Throwable;

/**
 * Proves the configured images disk really works: write a tiny file, read it back over
 * its public URL, delete it. Run it once against a real bucket after setting IMAGES_DISK=s3.
 * No per-file ACL is sent: R2 and B2 reject them, so the bucket itself must be public.
 */
class CheckImageDisk extends Command
{
    protected $signature = 'images:check-disk {--skip-url : do not fetch the public URL (for disks without one)}';

    protected $description = 'Write, read over HTTP and delete a test file on the images disk';

    public function handle(): int
    {
        $name = config('filesystems.images_disk');
        $disk = Storage::disk($name);
        $path = 'healthcheck/'.Str::ulid().'.txt';
        $body = 'socialhub '.now()->toIso8601String();
        $this->line("Disk: {$name}");

        try {
            $disk->put($path, $body) ?: throw new \RuntimeException('put() returned false');
            $this->info('1/3 upload ok');

            if ($this->option('skip-url')) {
                $this->warn('2/3 public URL skipped');
            } else {
                $url = $disk->url($path);
                $response = Http::timeout(15)->get($url);
                if (! $response->successful() || $response->body() !== $body) {
                    $this->error("2/3 {$url} answered {$response->status()}: files must be readable by URL without signing");
                    $disk->delete($path);

                    return self::FAILURE;
                }
                $this->info("2/3 public URL ok ({$url})");
            }

            $disk->delete($path);
            if ($disk->exists($path)) {
                $this->error('3/3 delete did not remove the file');

                return self::FAILURE;
            }
            $this->info('3/3 delete ok');
        } catch (Throwable $e) {
            $this->error('Failed: '.$e->getMessage());
            $disk->delete($path);

            return self::FAILURE;
        }

        return self::SUCCESS;
    }
}
