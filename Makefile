.PHONY: deploy-cluster-dev deploy-cluster-prod deploy-apps-dev-platform deploy-apps-dev-ppp deploy-apps-prod-platform deploy-apps-prod-ppp

deploy-cluster-dev:
	terraform -chdir=./terraform init -backend-config="prefix=terraform/nextgendev" && terraform -chdir=./terraform apply -var-file="../profiles/nextgendev.tfvars"

deploy-cluster-prod:
	@read -p "confirm production cluster apply: " confirm; \
	if [ "$$confirm" = "confirm" ]; then \
		terraform -chdir=./terraform init -backend-config="prefix=terraform/production" && terraform -chdir=./terraform apply -var-file="../profiles/production.tfvars"; \
	else \
		echo "apply cancelled"; \
	fi

deploy-apps-dev-platform:
	helm upgrade nextgendev ./helm -f ./profiles/nextgendev-platform.yaml

deploy-apps-dev-ppp:
	helm upgrade nextgenpppdev ./helm -f ./profiles/nextgendev-ppp.yaml

deploy-apps-prod-platform:
	@helm lint ./helm && \
	helm diff upgrade production-platform ./helm -f ./profiles/production-platform.yaml; \
	read -p "confirm production platform apps deploy: " confirm; \
	if [ "$$confirm" = "confirm" ]; then \
		helm upgrade nextgenprod ./helm -f ./profiles/production-platform.yaml; \
	else \
		echo "deploy cancelled"; \
	fi

deploy-apps-prod-ppp:
	@helm lint ./helm && \
	helm diff upgrade production-ppp ./helm -f ./profiles/production-ppp.yaml; \
	read -p "confirm production ppp apps deploy: " confirm; \
	if [ "$$confirm" = "confirm" ]; then \
		helm upgrade nextgenpppprod ./helm -f ./profiles/production-ppp.yaml; \
	else \
		echo "deploy cancelled"; \
	fi
