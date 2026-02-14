# syntax=docker/dockerfile:1.7

ARG PHP_VERSION=8.3

FROM php:${PHP_VERSION}-fpm-alpine AS php-base

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/tmp/composer

RUN apk add --no-cache \
      bash \
      curl \
      freetype \
      git \
      icu \
      libjpeg-turbo \
      libpng \
      libpq \
      libzip \
      mariadb-connector-c \
      unzip \
  && apk add --no-cache --virtual .build-deps \
      ${PHPIZE_DEPS} \
      freetype-dev \
      icu-dev \
      libjpeg-turbo-dev \
      libpng-dev \
      libpq-dev \
      libzip-dev \
      mariadb-connector-c-dev \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install -j"$(nproc)" gd intl opcache pdo pdo_mysql pdo_pgsql zip \
  && pecl install apcu redis uploadprogress \
  && docker-php-ext-enable apcu redis uploadprogress \
  && apk del .build-deps

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

WORKDIR /var/www/html

COPY docker/php/conf.d/*.ini /usr/local/etc/php/conf.d/
COPY docker/php/php-fpm.d/zz-www.conf /usr/local/etc/php-fpm.d/zz-www.conf
COPY docker/php/entrypoint.sh /usr/local/bin/drupal-entrypoint
RUN chmod +x /usr/local/bin/drupal-entrypoint

FROM php-base AS dev-runtime

RUN addgroup -g 10001 -S drupal \
  && adduser -u 10001 -S -D -H -G drupal drupal \
  && mkdir -p /var/www/html/web/sites/default/files /var/www/html/private /tmp/twig

USER drupal:drupal
ENTRYPOINT ["/usr/local/bin/drupal-entrypoint"]
CMD ["php-fpm", "-F"]

FROM dev-runtime AS dev-cli
CMD ["sh"]

FROM php-base AS build-runtime

COPY composer.json composer.lock* ./
RUN --mount=type=cache,target=/tmp/composer/cache \
    composer install \
      --no-dev \
      --no-interaction \
      --prefer-dist \
      --optimize-autoloader \
      --classmap-authoritative
COPY config ./config
COPY drush ./drush
COPY web ./web

FROM php-base AS build-cli

COPY composer.json composer.lock* ./
RUN --mount=type=cache,target=/tmp/composer/cache \
    composer install \
      --no-interaction \
      --prefer-dist \
      --optimize-autoloader
COPY config ./config
COPY drush ./drush
COPY web ./web

FROM dev-runtime AS runtime

USER root
COPY --from=build-runtime --chown=drupal:drupal /var/www/html /var/www/html

USER drupal:drupal
CMD ["php-fpm", "-F"]

FROM runtime AS cli-runtime

USER root
COPY --from=build-cli --chown=drupal:drupal /var/www/html /var/www/html
USER drupal:drupal
CMD ["sh"]
