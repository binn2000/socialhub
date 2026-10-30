#!/bin/bash
# Starts the development MariaDB 10.11 (Homebrew) on port 3307, next to XAMPP's
# MySQL on 3306. Data lives in /opt/homebrew/var/mariadb-socialhub; the OS user
# that created it is the admin through the socket. Stop it with Ctrl+C.
#
# First time only:
#   M=/opt/homebrew/opt/mariadb@10.11
#   $M/bin/mariadb-install-db --datadir=/opt/homebrew/var/mariadb-socialhub --basedir=$M \
#     --auth-root-authentication-method=socket --auth-root-socket-user=$USER
set -euo pipefail
M=/opt/homebrew/opt/mariadb@10.11
exec "$M/bin/mariadbd" --basedir="$M" --datadir=/opt/homebrew/var/mariadb-socialhub \
  --port=3307 --bind-address=127.0.0.1 --socket=/tmp/socialhub-mariadb.sock
