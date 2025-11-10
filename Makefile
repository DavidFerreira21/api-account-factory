.PHONY: tf-plan tf-apply test lint

TF_DIR=terraform

lint:
	bash scripts/lint.sh

test: lint
	python3 -m pytest

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
