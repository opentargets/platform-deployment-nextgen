.PHONY: deploy-cluster-dev deploy-cluster-prod deploy-apps-dev-platform deploy-apps-dev-ppp deploy-apps-prod-platform deploy-apps-prod-ppp

deploy-cluster-dev:
	@terraform -chdir=./terraform init -backend-config="prefix=terraform/devcluster" && terraform -chdir=./terraform apply -var-file="../profiles/devcluster.tfvars"

deploy-cluster-prod:
	@terraform -chdir=./terraform init -backend-config="prefix=terraform/production" && terraform -chdir=./terraform apply -var-file="../profiles/production.tfvars"

deploy-apps-dev-platform:
	@helm diff upgrade devcluster-platform ./helm/platform -f ./profiles/devcluster-platform.yaml; \
	read -p "press enter to continue..."; \
	helm upgrade devcluster-platform ./helm/platform -f ./profiles/devcluster-platform.yaml

deploy-apps-dev-ppp:
	@helm diff upgrade devcluster-ppp ./helm/platform -f ./profiles/devcluster-ppp.yaml; \
	read -p "press enter to continue..."; \
	helm upgrade devcluster-ppp ./helm/platform -f ./profiles/devcluster-ppp.yaml

deploy-apps-prod-platform:
	@helm lint ./helm/platform && \
	helm diff upgrade production-platform ./helm/platform -f ./profiles/production-platform.yaml; \
	read -p "confirm production platform apps deploy: " confirm; \
	if [ "$$confirm" = "confirm" ]; then \
		helm upgrade production-platform ./helm/platform -f ./profiles/production-platform.yaml; \
	else \
		echo "deploy cancelled"; \
	fi

deploy-apps-prod-ppp:
	@helm lint ./helm/platform && \
	helm diff upgrade production-ppp ./helm/platform -f ./profiles/production-ppp.yaml; \
	read -p "confirm production ppp apps deploy: " confirm; \
	if [ "$$confirm" = "confirm" ]; then \
		helm upgrade production-ppp ./helm/platform -f ./profiles/production-ppp.yaml; \
	else \
		echo "deploy cancelled"; \
	fi
