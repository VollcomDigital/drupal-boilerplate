# Deploying to Kubernetes

This project ships with a Helm chart at `charts/drupal-boilerplate`.

## 1. Create namespace

```bash
kubectl create namespace drupal
```

## 2. Provide secrets

Use an external secret manager in production (External Secrets, Sealed Secrets, Vault, etc.).

If you are not using `secrets.existingSecret`, set at minimum:

- `secrets.hashSalt`
- `secrets.dbPassword`

## 3. Install/upgrade chart

```bash
helm upgrade --install drupal charts/drupal-boilerplate \
  --namespace drupal \
  --set secrets.hashSalt='replace-with-secure-random' \
  --set secrets.dbPassword='replace-with-db-password'
```

## 4. Storage pattern

### Preferred: S3 object storage

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

### Fallback: PVC

```bash
helm upgrade --install drupal charts/drupal-boilerplate \
  --namespace drupal \
  --set env.filesDriver=pvc \
  --set persistence.enabled=true \
  --set persistence.accessMode=ReadWriteMany \
  --set persistence.size=50Gi
```

## 5. External cron

The chart installs a Kubernetes `CronJob` that runs `drush cron`.

Drupal poormanscron is disabled by default in `settings.php`:

```php
$config['automated_cron.settings']['interval'] = 0;
```
