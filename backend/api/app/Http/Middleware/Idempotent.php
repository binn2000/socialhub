<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\Response;

/**
 * Optional `Idempotency-Key` header. The first request inserts a row (unique on user + key) before
 * doing any work; a repeat with the same body gets the stored response, a different body is 409.
 * Only successful responses are kept, so a failed request can simply be sent again.
 */
class Idempotent
{
    private const TTL_HOURS = 24;

    private const STALE_MINUTES = 5; // an unfinished first request older than this is assumed dead

    public function handle(Request $request, Closure $next): Response
    {
        $key = $request->header('Idempotency-Key');

        if ($key === null) {
            return $next($request);
        }
        if (! preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $key)) {
            throw ValidationException::withMessages(['Idempotency-Key' => [__('The Idempotency-Key must be a UUID.')]]);
        }

        $this->rejectBrokenUploads($request);

        $key = strtolower($key);
        $userId = $request->user()->id;
        $hash = $this->fingerprint($request);

        if ($replay = $this->claim($userId, $key, $request, $hash)) {
            return $replay;
        }

        $finished = false;
        try {
            $response = $next($request);

            if ($response->isSuccessful() && $response instanceof JsonResponse) {
                $this->store($userId, $key, $response);
                $finished = true;
            }

            return $response;
        } finally {
            if (! $finished) {
                DB::table('idempotency_keys')->where(['user_id' => $userId, 'key' => $key])->delete();
            }
        }
    }

    /** Returns a response to send instead of running the request, or null when this request owns the key. */
    private function claim(string $userId, string $key, Request $request, string $hash, bool $retry = true): ?Response
    {
        try {
            DB::table('idempotency_keys')->insert([
                'user_id' => $userId, 'key' => $key, 'method' => $request->method(),
                'path' => substr($request->path(), 0, 255), 'request_hash' => $hash, 'created_at' => now(),
            ]);

            return null;
        } catch (UniqueConstraintViolationException) {
            $row = DB::table('idempotency_keys')->where(['user_id' => $userId, 'key' => $key])->first();
        }

        $age = $row ? now()->diffInMinutes($row->created_at, true) : null;
        $expired = $row && ($row->status_code !== null
            ? now()->diffInHours($row->created_at, true) >= self::TTL_HOURS
            : $age >= self::STALE_MINUTES);

        if (! $row || $expired) {
            if ($row) {
                DB::table('idempotency_keys')->where('id', $row->id)->delete();
            }

            return $retry ? $this->claim($userId, $key, $request, $hash, false) : $this->conflict('request_in_progress');
        }

        if ($row->request_hash !== $hash) {
            return $this->conflict('idempotency_key_reused', __('This Idempotency-Key was already used with a different request.'));
        }
        if ($row->status_code === null) {
            return $this->conflict('request_in_progress', __('The first request with this key is still running.'));
        }

        $stored = json_decode($row->response_body, true);

        return response()->json($stored['body'], $row->status_code, $stored['headers'] + ['Idempotent-Replayed' => 'true']);
    }

    private function store(string $userId, string $key, JsonResponse $response): void
    {
        $headers = array_filter(['Location' => $response->headers->get('Location')]);

        DB::table('idempotency_keys')->where(['user_id' => $userId, 'key' => $key])->update([
            'status_code' => $response->getStatusCode(),
            // MariaDB 10.1 has no JSON type, so the body is encoded by hand into a text column.
            'response_body' => json_encode(['headers' => $headers, 'body' => $response->getData(true)]),
        ]);
    }

    /**
     * A file PHP refused or lost (over upload_max_filesize, connection dropped) has no temporary file to
     * hash; answer 422 with the reason in the log instead of failing with a 500.
     */
    private function rejectBrokenUploads(Request $request): void
    {
        foreach (Arr::dot($request->allFiles()) as $name => $file) {
            if (! $file->isValid()) {
                Log::warning('Upload rejected: '.$file->getErrorMessage(), ['field' => $name, 'user' => $request->user()->id]);

                throw ValidationException::withMessages([
                    Str::before($name, '.') => [__('The upload failed: the file is too large or the connection was lost. Videos can be 50 MB, photos 10 MB.')],
                ]);
            }
        }
    }

    /** Same method, path and content => same fingerprint (files are hashed by content, not by multipart boundary). */
    private function fingerprint(Request $request): string
    {
        $input = $request->except(array_keys($request->allFiles()));
        ksort($input);
        $files = [];
        foreach (Arr::dot($request->allFiles()) as $name => $file) {
            $files[$name] = [$file->getClientOriginalName(), $file->getSize(), md5_file($file->getRealPath())];
        }

        return hash('sha256', json_encode([$request->method(), $request->path(), $input, $files]));
    }

    private function conflict(string $code, ?string $message = null): Response
    {
        return response()->json(['message' => $message ?? __('Conflict.'), 'code' => $code], 409);
    }
}
