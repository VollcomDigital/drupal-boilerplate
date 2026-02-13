<?php

declare(strict_types=1);

use Dotenv\Dotenv;

/**
 * Cloud-native settings for Drupal.
 *
 * This file intentionally relies on environment variables for all
 * environment-specific behavior and secret material.
 */

$project_root = dirname(__DIR__, 3);
$app_root = dirname(__DIR__, 2);

if (class_exists(Dotenv::class) && file_exists($project_root . '/.env')) {
  Dotenv::createImmutable($project_root)->safeLoad();
}

$env = static function (string $key, ?string $default = NULL): ?string {
  $value = $_ENV[$key] ?? $_SERVER[$key] ?? getenv($key);
  if ($value === FALSE || $value === NULL || $value === '') {
    return $default;
  }

  return (string) $value;
};

$env_bool = static function (string $key, bool $default = FALSE) use ($env): bool {
  $value = $env($key);
  if ($value === NULL) {
    return $default;
  }

  return in_array(strtolower($value), ['1', 'true', 'yes', 'on'], TRUE);
};

$environment = $env('DRUPAL_ENV', $env('APP_ENV', 'local'));
$hash_salt = $env('DRUPAL_HASH_SALT');
if ($hash_salt === NULL) {
  if ($environment === 'prod' || $environment === 'production') {
    throw new RuntimeException('DRUPAL_HASH_SALT is required in production.');
  }

  $hash_salt = 'local-dev-only-change-me';
}

$settings['hash_salt'] = $hash_salt;
$settings['skip_permissions_hardening'] = FALSE;
$settings['update_free_access'] = FALSE;
$settings['container_yamls'][] = $app_root . '/sites/default/services.yml';
$settings['config_sync_directory'] = $env('DRUPAL_CONFIG_SYNC_DIRECTORY', $project_root . '/config/sync');
$settings['file_private_path'] = $env('DRUPAL_PRIVATE_FILES_PATH', $project_root . '/private');
$settings['file_temp_path'] = $env('DRUPAL_TEMP_PATH', '/tmp');
$settings['php_storage']['twig']['directory'] = '/tmp/twig';
$settings['file_public_path'] = 'sites/default/files';

$trusted_host_patterns = array_values(array_filter(array_map(
  'trim',
  explode(',', (string) $env('DRUPAL_TRUSTED_HOST_PATTERNS', '^localhost$'))
)));
if ($trusted_host_patterns !== []) {
  $settings['trusted_host_patterns'] = $trusted_host_patterns;
}

$settings['reverse_proxy'] = $env_bool('DRUPAL_REVERSE_PROXY', FALSE);
if ($settings['reverse_proxy']) {
  $settings['reverse_proxy_addresses'] = array_values(array_filter(array_map(
    'trim',
    explode(',', (string) $env('DRUPAL_REVERSE_PROXY_ADDRESSES', '127.0.0.1'))
  )));
}

$db_driver = $env('DB_DRIVER', 'mysql');
if ($db_driver === 'pgsql') {
  $databases['default']['default'] = [
    'driver' => 'pgsql',
    'database' => $env('DB_NAME', 'drupal'),
    'username' => $env('DB_USER', 'drupal'),
    'password' => $env('DB_PASSWORD', 'drupal'),
    'host' => $env('DB_HOST', 'db'),
    'port' => (int) $env('DB_PORT', '5432'),
    'prefix' => '',
    'namespace' => 'Drupal\\Core\\Database\\Driver\\pgsql',
  ];
}
else {
  $databases['default']['default'] = [
    'driver' => 'mysql',
    'database' => $env('DB_NAME', 'drupal'),
    'username' => $env('DB_USER', 'drupal'),
    'password' => $env('DB_PASSWORD', 'drupal'),
    'host' => $env('DB_HOST', 'db'),
    'port' => (int) $env('DB_PORT', '3306'),
    'prefix' => '',
    'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
    'collation' => 'utf8mb4_general_ci',
    'init_commands' => [
      'isolation_level' => 'SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED',
    ],
  ];
}

$config['system.logging']['error_level'] = $environment === 'local' ? 'verbose' : 'hide';

if ($env_bool('DRUPAL_DISABLE_POORMANS_CRON', TRUE)) {
  $config['automated_cron.settings']['interval'] = 0;
}

if (extension_loaded('apcu')) {
  $settings['cache']['bins']['bootstrap'] = 'cache.backend.apcu';
  $settings['cache']['bins']['discovery'] = 'cache.backend.apcu';
}

$redis_host = $env('REDIS_HOST');
if ($redis_host !== NULL && extension_loaded('redis')) {
  $settings['cache']['default'] = 'cache.backend.redis';
  $settings['cache']['bins']['render'] = 'cache.backend.redis';
  $settings['cache']['bins']['dynamic_page_cache'] = 'cache.backend.redis';
  $settings['cache']['bins']['page'] = 'cache.backend.redis';
  $settings['redis.connection']['interface'] = 'PhpRedis';
  $settings['redis.connection']['host'] = $redis_host;
  $settings['redis.connection']['port'] = (int) $env('REDIS_PORT', '6379');
  $settings['redis.connection']['password'] = $env('REDIS_PASSWORD');
  $settings['cache_prefix']['default'] = $env('REDIS_PREFIX', 'drupal');
}

if ($env('DRUPAL_FILES_DRIVER', 'pvc') === 's3') {
  $settings['file_public_base_url'] = $env('S3_PUBLIC_BASE_URL', '');
}

if (is_readable($app_root . '/sites/default/settings.local.php')) {
  include $app_root . '/sites/default/settings.local.php';
}
