.PHONY: $(MAKECMDGOALS)

RED=\033[31m
GREEN=\033[32m
YELLOW=\033[33m
CYAN=\033[36m
RESET=\033[0m

MAKEFLAGS += --no-print-directory

DC = docker compose
SCRIPT = ./scripts/backup.sh

run: ## Run container
	@echo "$(YELLOW)Starting container...$(RESET)"
	@$(DC) up -d
	@echo "$(GREEN)Container is running$(RESET)"

stop: ## Stop container
	@echo "$(YELLOW)Stopping container...$(RESET)"
	@$(DC) down
	@echo "$(GREEN)Container stopped$(RESET)"

restart: ## Restart container
	@echo "$(YELLOW)Restarting container...$(RESET)"
	@$(MAKE) stop
	@$(MAKE) run
	@echo "$(GREEN)Container restarted$(RESET)"

commit-and-push: ## Commit all changes with timestamp message and push on github
	@echo "$(YELLOW)Creating timestamp commit...$(RESET)"
	@git add -A
	@if git diff-index --quiet HEAD --; then \
		echo "$(YELLOW)No changes to commit$(RESET)"; \
	else \
		TIMESTAMP=$$(date '+%Y-%m-%d %H:%M:%S'); \
		git commit -m "$$TIMESTAMP"; \
		echo "$(GREEN)Commit $$TIMESTAMP is created$(RESET)"; \
	fi
	@git push

backup: ## Backup data directory
	@echo "$(YELLOW)Starting backup...$(RESET)"
	@$(SCRIPT) backup
	@echo "$(GREEN)Backup complete$(RESET)"

restore: ## Restore data directory from latest backup
	@echo "$(YELLOW)Starting restore...$(RESET)"
	@$(SCRIPT) restore
	@echo "$(GREEN)Restore complete$(RESET)"

.DEFAULT_GOAL := help

help: ## Shows a list of available commands
	@echo "$(GREEN)============================================================================================$(RESET)"
	@echo "$(GREEN)>>> Docker Self Host Commands:$(RESET)"
	@echo "$(GREEN)============================================================================================$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	awk 'BEGIN {FS = ":.*?## "}; {printf "$(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo "$(GREEN)============================================================================================$(RESET)"
