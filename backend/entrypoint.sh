#!/usr/bin/env bash
# SCRIPT: entrypoint.sh
# DESCRIPTION: Container entrypoint for the Django backend; applies migrations and collects static files.
# USAGE: ./entrypoint.sh [command...]
# PARAMETERS:
#   command: optional command to exec (defaults to CMD from the image)
# EXAMPLE: ./entrypoint.sh gunicorn home_monitor.wsgi:application
set -euo pipefail

python manage.py migrate --noinput
python manage.py collectstatic --noinput || true
exec "$@"
