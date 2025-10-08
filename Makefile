.PHONY: deploy-cluster-dev deploy-cluster-prod deploy-apps-dev-platform deploy-apps-dev-ppp deploy-apps-prod-platform deploy-apps-prod-ppp port-forward-prometheus

deploy-cluster-dev:
	@terraform -chdir=./terraform init -backend-config="prefix=terraform/devcluster" && terraform -chdir=./terraform apply -var-file="../profiles/devcluster.tfvars"

deploy-cluster-prod:
	@terraform -chdir=./terraform init -backend-config="prefix=terraform/production" && terraform -chdir=./terraform apply -var-file="../profiles/production.tfvars"

deploy-apps-dev-platform:
	@helm diff upgrade devcluster-platform ./helm/app -f ./profiles/devcluster-platform.yaml; \
	read -p "press enter to continue..."; \
	helm upgrade devcluster-platform ./helm/app -f ./profiles/devcluster-platform.yaml

deploy-apps-dev-ppp:
	@helm diff upgrade devcluster-ppp ./helm/app -f ./profiles/devcluster-ppp.yaml; \
	read -p "press enter to continue..."; \
	helm upgrade devcluster-ppp ./helm/app -f ./profiles/devcluster-ppp.yaml

deploy-apps-prod-platform:
	@helm lint ./helm/app && \
	helm diff upgrade production-platform ./helm/app -f ./profiles/production-platform.yaml; \
	read -p "confirm production platform apps deploy: " confirm; \
	if [ "$$confirm" = "confirm" ]; then \
		helm upgrade production-platform ./helm/app -f ./profiles/production-platform.yaml; \
	else \
		echo "deploy cancelled"; \
	fi

deploy-apps-prod-ppp:
	@helm lint ./helm/app && \
	helm diff upgrade production-ppp ./helm/app -f ./profiles/production-ppp.yaml; \
	read -p "confirm production ppp apps deploy: " confirm; \
	if [ "$$confirm" = "confirm" ]; then \
		helm upgrade production-ppp ./helm/app -f ./profiles/production-ppp.yaml; \
	else \
		echo "deploy cancelled"; \
	fi

deploy-observability-dev-platform:
	@MONITORING_NAMESPACE=$$(kubectl get ns | grep monitoring | awk '{print $1}'); \
	if [ -z "$$MONITORING_NAMESPACE" ]; then \
		echo "Creating monitoring namespace"; \
		kubectl create namespace monitoring; \
	fi; \
	@PROMETHEUS_REPO=$$(helm repo list | grep prometheus-community | awk '{print $$1}'); \
	if [ -z "$$PROMETHEUS_REPO" ]; then \
		helm repo add prometheus-community https://prometheus-community.github.io/helm-charts; \
		helm repo update; \
	fi; \
	@helm diff upgrade -i prometheus prometheus-community/prometheus --namespace monitoring -f ./helm/app/prom.values.yaml; \
	read -p "press enter to continue..."; \
	helm upgrade -i prometheus prometheus-community/prometheus --namespace monitoring -f ./helm/app/prom.values.yaml

port-forward-prometheus:
	@PROMETHEUS_POD=$$(kubectl get pods --namespace monitoring -l "app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}"); \
	echo "Port-forwarding to Prometheus pod: $$PROMETHEUS_POD"; \
	kubectl port-forward --namespace monitoring $$PROMETHEUS_POD 9090:9090
