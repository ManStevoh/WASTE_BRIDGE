# Laravel API — local / staging (php artisan serve). Use with docker-compose.
FROM php:8.3-cli-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    git unzip libzip-dev libpng-dev libonig-dev \
    && docker-php-ext-install pdo_mysql zip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app

COPY backend/ /app/

RUN composer install --prefer-dist --no-interaction --no-dev --optimize-autoloader \
    && php artisan config:clear || true

ENV APP_ENV=local
EXPOSE 8000

CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
