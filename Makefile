SHELL := /bin/bash
DC ?= docker compose
CLI_SERVICE ?= cli
DC_CLI ?= $(DC) --profile cli
DRUPAL_INSTALL_ACCOUNT_NAME ?= admin

.PHONY: help env up up-devtools up-observability up-tls down restart logs ps shell composer composer-install drush check-install-credentials install cron

help:
	@echo "Targets:"
	@echo "  make env                # Create .env from .env.example if missing"
	@echo "  make up                 # Start core stack (php, nginx, db, redis)"
	@echo "  make up-devtools        # Start stack with mailhog and adminer"
	@echo "  make up-observability   # Start stack with prometheus/grafana"
	@echo "  make up-tls             # Start stack with traefik TLS routing"
	@echo "  make shell              # Open shell in CLI container"
	@echo "  make composer ARGS='...'# Run composer in CLI container"
	@echo "  make drush ARGS='...'   # Run drush command in CLI container"
	@echo "  make install            # Install Drupal (requires DRUPAL_INSTALL_ACCOUNT_PASS)"
	@echo "  make cron               # Run drush cron once"
	@echo "  make down               # Stop and remove containers"

env:
	@test -f .env || cp .env.example .env

up: env
	$(DC) up -d --build

up-devtools: env
	$(DC) --profile dev-tools up -d --build

up-observability: env
	$(DC) --profile observability up -d --build

up-tls: env
	$(DC) --profile tls up -d --build

down:
	$(DC) down

restart:
	$(DC) down && $(DC) up -d --build

logs:
	$(DC) logs -f --tail=100

ps:
	$(DC) ps

shell: env
	$(DC_CLI) run --rm $(CLI_SERVICE) sh

composer: env
	$(DC_CLI) run --rm $(CLI_SERVICE) composer $(ARGS)

composer-install: env
	$(DC_CLI) run --rm $(CLI_SERVICE) composer install

drush: env
	$(DC_CLI) run --rm $(CLI_SERVICE) vendor/bin/drush $(ARGS)

check-install-credentials:
	@if [ -z "$(DRUPAL_INSTALL_ACCOUNT_PASS)" ]; then \
	  echo "Set DRUPAL_INSTALL_ACCOUNT_PASS for local install."; \
	  echo "Example: make install DRUPAL_INSTALL_ACCOUNT_PASS='change-me-local'"; \
	  exit 1; \
	fi

install: env check-install-credentials
	$(DC_CLI) run --rm $(CLI_SERVICE) vendor/bin/drush site:install standard --yes \
	  --account-name=$(DRUPAL_INSTALL_ACCOUNT_NAME) --account-pass=$(DRUPAL_INSTALL_ACCOUNT_PASS) \
	  --db-url=$${DB_DRIVER:-mysql}://$${DB_USER:-drupal}:$${DB_PASSWORD:-drupal}@$${DB_HOST:-db}:$${DB_PORT:-3306}/$${DB_NAME:-drupal}

cron: env
	$(DC_CLI) run --rm $(CLI_SERVICE) vendor/bin/drush cron --yes
