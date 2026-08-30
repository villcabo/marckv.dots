.PHONY: init up down logs
SHELL := /bin/bash
STACK ?= prometheus
COMPOSE := docker compose -f docker-compose.yml

init:
	@docker network inspect metrics_router >/dev/null 2>&1 || \
		docker network create metrics_router

up: init
	$(COMPOSE) up -d --remove-orphans

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f --tail 100 $(filter-out $@,$(MAKECMDGOALS))
