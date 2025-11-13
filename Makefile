.PHONY: tf-plan tf-apply test lint security-check

TF_DIR=terraform/

lint:
	bash scripts/lint.sh

test: lint
	python3 -m pytest

security-check:
	checkov -d $(TF_DIR) --check MEDIUM,HIGH,CRITICAL

tf-plan:
	terraform -chdir=$(TF_DIR) init
	terraform -chdir=$(TF_DIR) fmt -recursive
	terraform -chdir=$(TF_DIR) plan


tf-apply:
	terraform -chdir=$(TF_DIR) init
	terraform -chdir=$(TF_DIR) apply -auto-approve

tf-deploy: tf-apply


tf-destroy:
	terraform -chdir=$(TF_DIR) destroy -auto-approve
