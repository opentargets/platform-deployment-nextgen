.PHONY: deploy-cluster-dev destroy-cluster-dev deploy-cluster-prod \
	deploy-chart-dev-platform deploy-chart-dev-ppp deploy-chart-prod-platform deploy-chart-prod-ppp \
	deploy-observability-dev deploy-observability-prod \
	port-forward-prometheus port-forward-grafana \
	create-cluster-local delete-cluster-local tunnel-local refresh-secrets-local \
	help

help:
	@echo "Available make targets:"
	@echo
	@echo "  deploy-cluster-dev         - TF   — Deploy  the development GKE cluster"
	@echo "  deploy-cluster-prod        - TF   — Deploy  the production GKE cluster"
	@echo "  destroy-cluster-dev        - TF   — Destroy the development GKE cluster"
	@echo
	@echo "  deploy-chart-dev-platform  - HELM — Deploy the platform flavor on the dev  cluster"
	@echo "  deploy-chart-dev-ppp       - HELM — Deploy the PPP      flavor on the dev  cluster"
	@echo "  deploy-chart-prod-platform - HELM — Deploy the platform flavor on the prod cluster"
	@echo "  deploy-chart-prod-ppp      - HELM — Deploy the PPP      flavor on the prod cluster"
	@echo
	@echo "  deploy-observability-dev   - HELM — Deploy observability stack to the development cluster using Helm"
	@echo "  deploy-observability-prod  - HELM — Deploy observability stack to the production cluster using Helm"
	@echo "  port-forward-prometheus    - Port-forward to Prometheus in the currently active cluster"
	@echo "  port-forward-grafana       - Port-forward to Grafana in the currently active cluster and display the admin password"
	@echo
	@echo "  create-cluster-local       - MINK — Create a local minikube cluster with nginx ingress"
	@echo "  delete-cluster-local       - MINK — Delete the local minikube cluster"
	@echo "  tunnel-local               - MINK — Run minikube tunnel to expose ingress on platform.localhost"
	@echo "  refresh-secrets-local      - MINK — Refresh the GCR pull secret for the local minikube cluster"


# ----------------------------------------------------------------------------------------------------------------------
# Terraform
deploy-cluster-dev:
	@terraform -chdir=./terraform init -backend-config="prefix=terraform/devcluster" && \
	terraform -chdir=./terraform apply -var-file="../profiles/devcluster.tfvars"

destroy-cluster-dev:
	@terraform -chdir=./terraform init -backend-config="prefix=terraform/devcluster" && \
	terraform -chdir=./terraform destroy -var-file="../profiles/devcluster.tfvars"

deploy-cluster-prod:
	@terraform -chdir=./terraform init -backend-config="prefix=terraform/production" && \
	terraform -chdir=./terraform apply -var-file="../profiles/production.tfvars"

define CLUSTER_CONTEXT_CHECK
	@if ! kubectl config current-context | grep -q $1; then \
		echo "current cluster is not a $1 cluster, aborting deploy"; \
		exit 1; \
	fi;
endef

# ----------------------------------------------------------------------------------------------------------------------
# Helm
deploy-chart-dev-platform:
	@$(call CLUSTER_CONTEXT_CHECK,dev)
	helm diff upgrade --allow-unreleased devcluster-platform ./helm/platform -f ./profiles/devcluster-platform.yaml; \
	read -p "press enter to continue..." nothing; \
	helm upgrade --install devcluster-platform ./helm/platform -f ./profiles/devcluster-platform.yaml

deploy-chart-dev-ppp:
	@$(call CLUSTER_CONTEXT_CHECK,dev)
	helm diff upgrade --allow-unreleased devcluster-ppp ./helm/platform -f ./profiles/devcluster-ppp.yaml; \
	read -p "press enter to continue..." nothing; \
	helm upgrade --install devcluster-ppp ./helm/platform -f ./profiles/devcluster-ppp.yaml

deploy-chart-prod-platform:
	@$(call CLUSTER_CONTEXT_CHECK,production)
	helm lint ./helm/platform && \
	helm diff upgrade --allow-unreleased production-platform ./helm/platform -f ./profiles/production-platform.yaml; \
	read -p "confirm production platform chart deploy: " confirm; \
	if [ "$$confirm" = "confirm" ]; then \
		helm upgrade --install production-platform ./helm/platform -f ./profiles/production-platform.yaml; \
	else \
		echo "deploy cancelled"; \
	fi

deploy-chart-prod-ppp:
	@$(call CLUSTER_CONTEXT_CHECK,production)
	@helm lint ./helm/platform && \
	helm diff upgrade --allow-unreleased production-ppp ./helm/platform -f ./profiles/production-ppp.yaml; \
	read -p "confirm production ppp chart deploy: " confirm; \
	if [ "$$confirm" = "confirm" ]; then \
		helm upgrade --install production-ppp ./helm/platform -f ./profiles/production-ppp.yaml; \
	else \
		echo "deploy cancelled"; \
	fi

# ----------------------------------------------------------------------------------------------------------------------
# Observability stack
deploy-observability-dev:
	@helm dependency build ./helm/observability
	@helm diff upgrade observability ./helm/observability --allow-unreleased --namespace observability -f ./profiles/devcluster-observability.yaml; \
	read -p "press enter to continue..." nothing; \
	helm upgrade observability ./helm/observability --namespace observability --install --create-namespace -f ./profiles/devcluster-observability.yaml

deploy-observability-prod:
	@helm dependency build ./helm/observability
	@helm diff upgrade observability ./helm/observability --allow-unreleased --namespace observability -f ./profiles/production-observability.yaml; \
	read -p "confirm production observability deploy: " confirm; \
	if [ "$$confirm" = "confirm" ]; then \
		helm upgrade observability ./helm/observability --namespace observability --install --create-namespace -f ./profiles/production-observability.yaml; \
	else \
		echo "deploy cancelled"; \
	fi

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

# ----------------------------------------------------------------------------------------------------------------------
# Local development (minikube)
create-cluster-local:
	minikube start --driver=docker --cpus=max --memory=max
	minikube addons enable ingress
	kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
	kubectl create namespace argocd
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	kubectl wait --namespace argocd --for=condition=ready pod --selector=app.kubernetes.io/name=argocd-server --timeout=300s
	kubectl create namespace local-blue-platform
	kubectl create namespace local-green-platform
	kubectl create secret docker-registry gcr-pull-secret \
		--docker-server=europe-west1-docker.pkg.dev \
		--docker-username=oauth2accesstoken \
		--docker-password="$$(gcloud auth print-access-token)" \
		--namespace=local-blue-platform
	kubectl create secret docker-registry gcr-pull-secret \
		--docker-server=europe-west1-docker.pkg.dev \
		--docker-username=oauth2accesstoken \
		--docker-password="$$(gcloud auth print-access-token)" \
		--namespace=local-green-platform
	kubectl apply -f ./argocd/local-platform-router.yaml
	kubectl apply -f ./argocd/local-platform-appset.yaml

delete-cluster-local:
	minikube delete

tunnel-local:
	minikube tunnel

refresh-secrets-local:
	kubectl delete secret gcr-pull-secret --namespace=local-blue-platform --ignore-not-found
	kubectl delete secret gcr-pull-secret --namespace=local-green-platform --ignore-not-found
	kubectl create secret docker-registry gcr-pull-secret \
		--docker-server=europe-west1-docker.pkg.dev \
		--docker-username=oauth2accesstoken \
		--docker-password="$$(gcloud auth print-access-token)" \
		--namespace=local-blue-platform
	kubectl create secret docker-registry gcr-pull-secret \
		--docker-server=europe-west1-docker.pkg.dev \
		--docker-username=oauth2accesstoken \
		--docker-password="$$(gcloud auth print-access-token)" \
		--namespace=local-green-platform
