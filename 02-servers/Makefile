.DEFAULT_GOAL := help

.PHONY: help
help: ## Show help
	@echo "Usage: make TARGET\n"
	@echo "Targets:"
	@awk -F ":.* ##" '/^[^#].*:.*##/{printf "%-13s%s\n", $$1, $$2}' \
	$(MAKEFILE_LIST) \
	| grep -v awk

.PHONY: init
init: ## Init
	terraform init \
		-backend-config="bucket=${TF_VAR_bucket}" \
		-backend-config="key=${TF_VAR_key_servers}" \
		-backend-config="region=${TF_VAR_region}"

.PHONY: apply
apply: MY_IP = $(shell curl -s https://ifconfig.co)/32
apply: ## Create the infrastructure
	terraform apply -var="my_ip_address=$(MY_IP)"

.PHONY: plan
plan: MY_IP = $(shell curl -s https://ifconfig.co)/32
plan: ## Dry run
	terraform plan -var="my_ip_address=$(MY_IP)"

.PHONY: destroy
destroy: ## Destroy the infrastructure
	terraform destroy
