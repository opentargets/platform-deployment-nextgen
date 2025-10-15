.PHONY: deploy-cluster-dev deploy-cluster-prod deploy-apps-dev-platform deploy-apps-dev-ppp deploy-apps-prod-platform deploy-apps-prod-ppp port-forward-prometheus

deploy-cluster-dev:
	@terraform -chdir=./terraform init -backend-config="prefix=terraform/devcluster" && terraform -chdir=./terraform apply -var-file="../profiles/devcluster.tfvars"

deploy-cluster-prod:
	@terraform -chdir=./terraform init -backend-config="prefix=terraform/production" && terraform -chdir=./terraform apply -var-file="../profiles/production.tfvars"

deploy-apps-dev-platform:
	@helm diff upgrade devcluster-platform ./helm/app -f ./profiles/devcluster-platform.yaml; \
	read -p "press enter to continue..." nothing; \
	helm upgrade devcluster-platform ./helm/app -f ./profiles/devcluster-platform.yaml

deploy-apps-dev-ppp:
	@helm diff upgrade devcluster-ppp ./helm/app -f ./profiles/devcluster-ppp.yaml; \
	read -p "press enter to continue..." nothing; \
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
	@PROMETHEUS_REPO=$$(helm repo list | grep prometheus-community.github.io/helm-charts | awk '{print $$1}'); \
	if [ -z "$$PROMETHEUS_REPO" ]; then \
		echo "Adding the prometheus-community helm repo."; \
		helm repo add prometheus-community https://prometheus-community.github.io/helm-charts; \
		helm repo update; \
	fi; \
	if [ ! -d "helm/observability/charts" ]; then \
		helm dependency build ./helm/observability; \
	fi; \
	helm diff upgrade observability ./helm/observability --allow-unreleased --namespace observability; \
	read -p "press enter to continue..."; \
	helm upgrade observability ./helm/observability --namespace observability --install --create-namespace

port-forward-prometheus:
	@PROMETHEUS_POD=$$(kubectl get pods --namespace observability -l "app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=observability" -o jsonpath="{.items[0].metadata.name}"); \
	echo "Port-forwarding to Prometheus pod: $$PROMETHEUS_POD"; \
	kubectl port-forward --namespace observability $$PROMETHEUS_POD 9090:9090

port-forward-grafana:
	echo "Grafana admin password:"
	@kubectl get secret --namespace observability observability-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
	@GRAFANA_POD=$$(kubectl get pods --namespace observability -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=observability" -o jsonpath="{.items[0].metadata.name}"); \
	echo "Port-forwarding to Grafana pod: $$GRAFANA_POD"; \
	kubectl port-forward --namespace observability $$GRAFANA_POD 3000:3000
