.PHONY: fmt validate init test

TF_DIR := .

fmt:
	terraform -chdir=$(TF_DIR) fmt -recursive

init:
	terraform -chdir=$(TF_DIR) init -backend=false

validate: fmt init
	terraform -chdir=$(TF_DIR) validate

test:
	@bash tests/terraform_config_test.sh
