# Drupal Cloud-Native Boilerplate

Modern, production-minded Drupal boilerplate designed for public/open-source use.

This repository uses the **Drupal Recommended Project** pattern with:

- Composer-managed Drupal core
- Environment-driven (`12-factor`) runtime configuration
- Docker local development stack (PHP-FPM + Nginx + MariaDB + Redis)
- Hardened multi-stage production image
- Kubernetes-first Helm chart (Ingress, HPA, PDB, CronJob)
- CI security gates (SAST/SCA/secrets/container scan) and branch-based image tagging

## Goals

- Safe to publish publicly (no private references, no secrets, no proprietary modules/submodules)
- Secure-by-default deployment posture
- Reproducible build flow with dependency lock + containerized build (commit `composer.lock` after initial dependency resolution)
- Scalable cloud-native architecture for multi-pod Drupal workloads

## Repository Layout

```text
.
├── Dockerfile
├── Makefile
├── docker-compose.yml
├── charts/drupal-boilerplate/      # Helm chart
├── docker/                         # Nginx, PHP, observability config
├── web/
│   ├── modules/custom/
│   ├── themes/custom/
│   └── sites/default/settings.php  # Env-driven, hardened settings
└── .github/workflows/              # CI, security, image publish
```

## Quickstart (Local Development)

### 1) Prepare environment

```bash
cp .env.example .env
```

### 2) Start services

```bash
make up
```

Core services:

- `nginx` (http://localhost:8080)
- `php` (php-fpm runtime)
- `db` (MariaDB)
- `redis`

Optional profiles:

```bash
make up-devtools        # Mailhog + Adminer
make up-observability   # Prometheus + Grafana + Redis exporter
make up-tls             # Traefik TLS routing for drupal.localhost
```

### 3) Install PHP dependencies and Drupal

```bash
make composer-install
make install DRUPAL_INSTALL_ACCOUNT_PASS='change-me-local'
```

Useful commands:

```bash
make shell
make drush ARGS="status"
make cron
make down
```

## Application Baseline

- Foundation: `drupal/core-recommended` + `drupal/core-composer-scaffold`
- Contrib modules included for cloud-native storage/cache patterns:
  - `drupal/redis`
  - `drupal/flysystem`
  - `drupal/flysystem_s3`
- `drush/drush` is available in the CLI image target for operational commands.

## Runtime Configuration (12-Factor)

`web/sites/default/settings.php` is environment-first:

- Database config from env vars (`DB_*`)
- Trusted host patterns from `DRUPAL_TRUSTED_HOST_PATTERNS`
- Reverse proxy config from env vars
- Redis/APCu integration when available
- No secrets stored in repository
- Automated Drupal cron disabled by default (`DRUPAL_DISABLE_POORMANS_CRON=true`)

## Production Container Design

- Multi-stage Docker build:
  - **build-runtime**: `composer install --no-dev --optimize-autoloader`
  - **build-cli**: includes dev tools (Drush) for ops/cron tasks
  - **runtime**: minimal non-root PHP-FPM image
- Hardening:
  - non-root user (`uid/gid 10001`)
  - no-new-privileges at runtime (Compose/K8s)
  - read-only root filesystem (Compose/K8s)
  - explicit writable mounts for `/tmp`, private files, and public files
- Performance:
  - OPcache tuned for production (`validate_timestamps=0`)
  - APCu enabled
  - Redis extension enabled

## Deploy to Kubernetes (Helm)

### Install

```bash
helm upgrade --install drupal charts/drupal-boilerplate \
  --namespace drupal \
  --create-namespace
```

### Required production overrides

```bash
helm upgrade --install drupal charts/drupal-boilerplate \
  --namespace drupal \
  --set image.php.tag='sha-<git-sha>' \
  --set image.cli.tag='sha-<git-sha>' \
  --set secrets.hashSalt='replace-with-secure-random' \
  --set secrets.dbPassword='replace-with-db-password'
```

### S3-first storage mode (recommended)

Use object storage for `sites/default/files` to avoid shared PVC coupling:

```bash
helm upgrade --install drupal charts/drupal-boilerplate \
  --namespace drupal \
  --set env.filesDriver=s3 \
  --set env.s3.bucket='drupal-assets' \
  --set env.s3.region='us-east-1' \
  --set env.s3.endpoint='https://s3.example.com' \
  --set secrets.s3AccessKeyId='...' \
  --set secrets.s3SecretAccessKey='...'
```

### PVC fallback mode

```bash
helm upgrade --install drupal charts/drupal-boilerplate \
  --namespace drupal \
  --set env.filesDriver=pvc \
  --set persistence.enabled=true \
  --set persistence.size=50Gi
```

### Included Kubernetes resources

- Deployment (Nginx + PHP-FPM pod)
- Service + Ingress
- HorizontalPodAutoscaler
- PodDisruptionBudget
- ConfigMap + Secret templates
- Optional PVC
- CronJob running external `drush cron`

## Cron Strategy

This boilerplate disables Drupal automated cron (`poormanscron`) and runs cron externally with Kubernetes `CronJob`.

Default schedule:

- `*/15 * * * *` running `vendor/bin/drush cron --yes`

## CI/CD and Security Gates

GitHub Actions include:

- Composer and YAML lint checks
- Helm lint
- Dependency review (PR)
- Trivy filesystem/config/container scanning
- Gitleaks secret scanning
- SonarCloud static analysis (optional, gated by repository configuration)
- Branch-based container tags (e.g. `main`, feature branch names, and `sha-*`)

### SonarCloud setup (optional)

The repository includes `.github/workflows/sonarcloud.yml` and `sonar-project.properties`.

To enable scanning:

1. Create a SonarCloud project.
2. Add GitHub repository variables:
   - `SONAR_ORGANIZATION`
   - `SONAR_PROJECT_KEY`
3. Add GitHub repository secret:
   - `SONAR_TOKEN`

The SonarCloud workflow runs on push and pull requests, and is skipped automatically when these settings are not configured.

## Security and Disclosure

See [SECURITY.md](SECURITY.md) for vulnerability reporting and responsible disclosure.

## License

MIT License. See [LICENSE](LICENSE).