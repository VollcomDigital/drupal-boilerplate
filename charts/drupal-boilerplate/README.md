# drupal-boilerplate Helm Chart

Deploys Drupal with an Nginx + PHP-FPM pod, ingress, autoscaling, and external cron.

## Install

```bash
helm upgrade --install drupal charts/drupal-boilerplate \
  --namespace drupal \
  --create-namespace
```

## Required production values

```bash
--set image.php.tag='sha-<git-sha>' \
--set image.cli.tag='sha-<git-sha>' \
--set secrets.hashSalt='replace-with-secure-random' \
--set secrets.dbPassword='replace-with-db-password'
```

## Storage mode

- **S3 preferred:** `env.filesDriver=s3` with Flysystem S3 credentials
- **PVC fallback:** `env.filesDriver=pvc` with `persistence.enabled=true`

## Cron

The chart includes a CronJob (`drush cron`) and expects Drupal poormanscron to be disabled.
