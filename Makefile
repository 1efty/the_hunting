.DEFAULT_GOAL:=help

.PHONY: build build/fedora

build: ## Build Ubuntu Droplet
	packer build build/templates/ubuntu.json

build/fedora: ## Build Fedora Droplet
	packer build build/templates/fedora.json

test: ## Test the_hunting
	@docker-compose -f docker-compose.test.yml build
	@docker-compose -f docker-compose.test.yml run f32_sut
	@docker-compose -f docker-compose.test.yml down --volumes

help: ## Show this help message
	@grep '^[a-zA-Z]' $(MAKEFILE_LIST) | sort | awk -F ':.*?## ' 'NF==2 {printf "\033[36m  %-25s\033[0m %s\n", $$1, $$2}'
