#!/bin/bash
# Starts everything the API needs while developing: the web server, the queue worker
# (notifications, image clean-up and video conversion with ffmpeg) and the scheduler. Stop with Ctrl+C.
#
#   backend/run-dev.sh              # listens on 0.0.0.0:8000
#   PORT=8080 backend/run-dev.sh
#
# MariaDB 10.11 must already be running: ./run-mariadb.sh (port 3307, in another terminal)
set -euo pipefail

PHP="${PHP_BIN:-/opt/homebrew/opt/php@8.5/bin/php}"   # the default `php` is 7.4 here
PORT="${PORT:-8000}"
cd "$(dirname "$0")/api"

# php.ini has no upload limits loaded here, and the defaults (2M/8M) reject photos and videos.
# `artisan serve` starts its server without our environment, so the server below is started
# with `php -d` instead of `artisan serve`.
PHP_LIMITS=(-d upload_max_filesize=52M -d post_max_size=56M -d memory_limit=768M)
# The built-in server handles one request at a time unless it has workers; chat polling
# and uploads need more.
export PHP_CLI_SERVER_WORKERS="${PHP_CLI_SERVER_WORKERS:-4}"

"$PHP" artisan migrate --force --no-interaction
[ -e public/storage ] || "$PHP" artisan storage:link --no-interaction

pids=()
cleanup() { kill "${pids[@]}" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

"$PHP" artisan queue:work --sleep=2 --tries=3 --timeout=320 --no-interaction & pids+=($!)
"$PHP" artisan schedule:work --no-interaction & pids+=($!)
# The router script is the one `artisan serve` uses; it must run from public/.
(cd public && exec "$PHP" "${PHP_LIMITS[@]}" -S "0.0.0.0:${PORT}" ../vendor/laravel/framework/src/Illuminate/Foundation/resources/server.php) & pids+=($!)
echo "API on http://0.0.0.0:${PORT}/api/v1  (queue worker and scheduler running)"
# `wait`, not a foreground server: bash only runs the exit trap once a foreground
# command ends, so Ctrl+C / kill would leave the worker and scheduler running.
wait
