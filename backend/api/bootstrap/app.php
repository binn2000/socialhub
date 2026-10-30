<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Foundation\Http\Exceptions\PostTooLargeException;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Symfony\Component\HttpKernel\Exception\TooManyRequestsHttpException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias(['idempotent' => \App\Http\Middleware\Idempotent::class]);

        // Behind a load balancer or reverse proxy, trust its forwarded headers so
        // the request IP (rate limits) and scheme (image URLs) are the client's.
        // TRUSTED_PROXIES is `*` or a comma separated list of proxy addresses.
        $proxies = env('TRUSTED_PROXIES');
        if ($proxies) {
            $middleware->trustProxies(at: $proxies === '*' ? '*' : explode(',', $proxies));
        }
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );

        // One error shape for the whole API: { message, code, errors? }.
        $isApi = fn (Request $request) => $request->is('api/*');

        $exceptions->render(fn (ValidationException $e, Request $r) => $isApi($r) ? response()->json([
            'message' => __('Validation failed.'),
            'code' => 'validation_failed',
            'errors' => $e->errors(),
        ], 422) : null);

        $exceptions->render(fn (AuthenticationException $e, Request $r) => $isApi($r) ? response()->json([
            'message' => __('Unauthenticated.'),
            'code' => 'unauthenticated',
        ], 401) : null);

        $exceptions->render(fn (PostTooLargeException $e, Request $r) => $isApi($r) ? response()->json([
            'message' => __('The upload is too large.'),
            'code' => 'payload_too_large',
        ], 413) : null);

        $exceptions->render(fn (NotFoundHttpException $e, Request $r) => $isApi($r) ? response()->json([
            'message' => __('Not found.'),
            'code' => 'not_found',
        ], 404) : null);

        $exceptions->render(fn (TooManyRequestsHttpException $e, Request $r) => $isApi($r) ? response()->json([
            'message' => __('Too many requests.'),
            'code' => 'too_many_requests',
        ], 429, $e->getHeaders()) : null);

        // Everything else gets the same shape too, and a production 500 never
        // shows the exception, SQL or file paths. Registered last: Laravel runs
        // the callbacks in order and uses the first answer.
        $exceptions->render(function (Throwable $e, Request $r) use ($isApi) {
            if (! $isApi($r) || $e instanceof HttpResponseException) {
                return null; // not the API, or already a finished response
            }
            if ($e instanceof ModelNotFoundException) {
                return response()->json(['message' => __('Not found.'), 'code' => 'not_found'], 404);
            }
            if ($e instanceof AuthorizationException) {
                return response()->json(['message' => __('This action is unauthorized.'), 'code' => 'forbidden'], 403);
            }
            if ($e instanceof HttpExceptionInterface) {
                $status = $e->getStatusCode();
                $code = match ($status) {
                    400 => 'bad_request',
                    403 => 'forbidden',
                    405 => 'method_not_allowed',
                    415 => 'unsupported_media_type',
                    default => 'http_error',
                };

                return response()->json(
                    ['message' => $e->getMessage() !== '' ? $e->getMessage() : __('Request failed.'), 'code' => $code],
                    $status,
                    $e->getHeaders(),
                );
            }

            // In development keep Laravel's detailed error output.
            return config('app.debug')
                ? null
                : response()->json(['message' => __('Server error.'), 'code' => 'server_error'], 500);
        });
    })->create();
