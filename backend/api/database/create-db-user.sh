#!/bin/bash
# Creates the MariaDB user the app connects as, instead of root.
#
#   database/create-db-user.sh [--dml-only] <app_user> <app_password> [<mysql args for the admin login>...]
#
# By default the user gets every privilege on `socialhub` and `socialhub_test`
# (what development and the test suite need: migrations create and drop tables).
# With --dml-only it can only read and write rows, which is enough to *run* the
# app in production; migrations are then run with a separate, more privileged
# account (DB_USERNAME / DB_PASSWORD in the deploy environment).
set -euo pipefail

DML_ONLY=0
if [ "${1:-}" = "--dml-only" ]; then
  DML_ONLY=1
  shift
fi

APP_USER="${1:?usage: create-db-user.sh [--dml-only] <app_user> <app_password> [mysql args...]}"
APP_PASSWORD="${2:?missing password}"
shift 2

MYSQL="${MYSQL_BIN:-mysql}"
PRIVILEGES="ALL PRIVILEGES"
DATABASES=(socialhub socialhub_test)
if [ "$DML_ONLY" = 1 ]; then
  PRIVILEGES="SELECT, INSERT, UPDATE, DELETE"
  DATABASES=(socialhub)
fi

{
  for host in localhost 127.0.0.1; do
    # MariaDB 10.1 has no CREATE USER IF NOT EXISTS ... ALTER USER, so GRANT ... IDENTIFIED BY
    # creates the user or updates its password.
    for db in "${DATABASES[@]}"; do
      echo "GRANT ${PRIVILEGES} ON \`${db}\`.* TO '${APP_USER}'@'${host}' IDENTIFIED BY '${APP_PASSWORD}';"
    done
  done
  echo "FLUSH PRIVILEGES;"
} | "$MYSQL" "$@"

echo "User ${APP_USER} ready for: ${DATABASES[*]}"
