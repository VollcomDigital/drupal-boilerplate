#!/usr/bin/env sh
set -eu

mkdir -p /tmp/twig
mkdir -p /var/www/html/web/sites/default/files
mkdir -p /var/www/html/private

exec "$@"
