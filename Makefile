.PHONY: deploy-cluster-dev destroy-cluster-dev deploy-cluster-prod \
	bootstrap-argocd-dev deploy-argocd-dev-platform deploy-argocd-dev-platform-router deploy-argocd-dev-ppp \
	bootstrap-argocd-prod deploy-argocd-prod-platform deploy-argocd-prod-platform-router deploy-argocd-prod-ppp deploy-argocd-prod-ppp-router \
	invalidate-cdn-prod-platform invalidate-cdn-prod-ppp \
	deploy-observability-dev deploy-observability-prod \
	port-forward-prometheus port-forward-grafana port-forward-argocd \
	create-cluster-local delete-cluster-local tunnel-local refresh-secrets-local \
	help

help:
	@echo "Available make targets:"
	@echo
	@echo "  deploy-cluster-dev         - TF   — Deploy  the development GKE cluster"
	@echo "  deploy-cluster-prod        - TF   — Deploy  the production GKE cluster"
	@echo "  destroy-cluster-dev        - TF   — Destroy the development GKE cluster"
	@echo
	@echo "  bootstrap-argocd-dev       - ARGO — Install ArgoCD onto the dev cluster (run once per fresh cluster)"
	@echo "  deploy-argocd-dev-platform - ARGO — Apply + sync platform colours only; leaves router and traffic unchanged"
	@echo "  deploy-argocd-dev-platform-router - ARGO — Apply + sync router proxies separately (see migration runbook)"
	@echo "  deploy-argocd-dev-ppp      - ARGO — Apply + sync the ppp      blue/green ArgoCD apps on the dev cluster (ArgoCD must already be installed)"
	@echo
	@echo "  bootstrap-argocd-prod      - ARGO — Install ArgoCD onto the prod cluster (run once)"
	@echo "  deploy-argocd-prod-platform        - ARGO — Apply platform colours, show the diff, sync after typing confirm"
	@echo "  deploy-argocd-prod-platform-router - ARGO — Apply platform router, show the diff, sync after typing confirm"
	@echo "  deploy-argocd-prod-ppp             - ARGO — Apply ppp colours, show the diff, sync after typing confirm"
	@echo "  deploy-argocd-prod-ppp-router      - ARGO — Apply ppp router, show the diff, sync after typing confirm"
	@echo "  invalidate-cdn-prod-{platform,ppp} - CDN  — Clear cached /config.js (run by the four targets above after a sync)"
	@echo
	@echo "  deploy-observability-dev   - HELM — Deploy observability stack to the development cluster using Helm"
	@echo "  deploy-observability-prod  - HELM — Deploy observability stack to the production cluster using Helm"
	@echo "  port-forward-prometheus    - Port-forward to Prometheus in the currently active cluster"
	@echo "  port-forward-grafana       - Port-forward to Grafana in the currently active cluster and display the admin password"
	@echo "  port-forward-argocd        - Port-forward to ArgoCD in the currently active cluster and display the admin password"
	@echo
	@echo "  create-cluster-local       - MINK — Create a local minikube cluster with nginx ingress"
	@echo "  delete-cluster-local       - MINK — Delete the local minikube cluster"
	@echo "  tunnel-local               - MINK — Run minikube tunnel to expose ingress on platform.localhost"
	@echo "  refresh-secrets-local      - MINK — Refresh the GCR pull secret for the local minikube cluster"


# ----------------------------------------------------------------------------------------------------------------------
# Terraform
deploy-cluster-dev:
	@terraform -chdir=./terraform init -reconfigure -backend-config="prefix=terraform/devcluster" && \
	terraform -chdir=./terraform apply -var-file="../profiles/devcluster/variables.tfvars"

destroy-cluster-dev:
	@terraform -chdir=./terraform init -reconfigure -backend-config="prefix=terraform/devcluster" && \
	terraform -chdir=./terraform destroy -var-file="../profiles/devcluster/variables.tfvars"

deploy-cluster-prod:
	@terraform -chdir=./terraform init -reconfigure -upgrade -backend-config="prefix=terraform/production" && \
	terraform -chdir=./terraform apply -var-file="../profiles/production/variables.tfvars"

define CLUSTER_CONTEXT_CHECK
	@if ! kubectl config current-context | grep -q $1; then \
		echo "current cluster is not a $1 cluster, aborting deploy"; \
		exit 1; \
	fi;
endef

# ----------------------------------------------------------------------------------------------------------------------
# ArgoCD
#
# bootstrap-argocd-dev installs ArgoCD itself (run once per fresh cluster).
#
# The deploy-argocd-dev-* targets require `argocd login localhost:8080` against a
# `port-forward-argocd` tunnel first. Platform colours and router are separate stages.
# The platform router stands up its own fresh namespace/IP/certs alongside the legacy
# release; DNS cutover and legacy retirement are separate, explicit actions documented
# in the runbook.
bootstrap-argocd-dev:
	@$(call CLUSTER_CONTEXT_CHECK,dev)
	@helm dependency build ./helm/argocd
	@helm diff upgrade --allow-unreleased argocd ./helm/argocd --namespace argocd && \
	read -p "press enter to continue..." nothing && \
	helm upgrade --install argocd ./helm/argocd --namespace argocd --create-namespace
	kubectl wait --namespace argocd --for=condition=ready pod --selector=app.kubernetes.io/name=argocd-server --timeout=300s

deploy-argocd-dev-platform:
	@$(call CLUSTER_CONTEXT_CHECK,dev)
	kubectl apply -f ./argocd/devcluster-platform-appset.yaml
	kubectl wait -n argocd --for=create application/devcluster-platform-blue --timeout=120s
	kubectl wait -n argocd --for=create application/devcluster-platform-green --timeout=120s
	argocd app wait devcluster-platform-blue devcluster-platform-green --operation --timeout 900
	argocd app sync devcluster-platform-blue --prune
	argocd app sync devcluster-platform-green --prune
	argocd app wait devcluster-platform-blue devcluster-platform-green --sync --health --timeout 900

deploy-argocd-dev-platform-router:
	@$(call CLUSTER_CONTEXT_CHECK,dev)
	kubectl apply -f ./argocd/devcluster-platform-router.yaml
	argocd app sync devcluster-platform-router --prune
	argocd app wait devcluster-platform-router --sync --health --timeout 600

deploy-argocd-dev-ppp:
	@$(call CLUSTER_CONTEXT_CHECK,dev)
	kubectl apply -f ./argocd/devcluster-ppp-appset.yaml
	kubectl wait -n argocd --for=create application/devcluster-ppp-blue --timeout=120s
	kubectl wait -n argocd --for=create application/devcluster-ppp-green --timeout=120s
	argocd app wait devcluster-ppp-blue devcluster-ppp-green --operation --timeout 900
	argocd app sync devcluster-ppp-blue --prune
	argocd app sync devcluster-ppp-green --prune
	argocd app wait devcluster-ppp-blue devcluster-ppp-green --sync --health --timeout 900
	kubectl apply -f ./argocd/devcluster-ppp-router.yaml
	argocd app sync devcluster-ppp-router --prune

# Production. Every production Application is manual-sync (it tracks the same branch as
# devcluster), so these targets apply the manifests, show `argocd app diff`, and only sync
# after you type "confirm". Colours and routers are separate stages; see
# docs/production-cutover.md for the order.
bootstrap-argocd-prod:
	@$(call CLUSTER_CONTEXT_CHECK,production)
	@helm dependency build ./helm/argocd
	@helm diff upgrade --allow-unreleased argocd ./helm/argocd --namespace argocd; \
	read -p "confirm production argocd install: " confirm; \
	if [ "$$confirm" = "confirm" ]; then \
		helm upgrade --install argocd ./helm/argocd --namespace argocd --create-namespace && \
		kubectl wait --namespace argocd --for=condition=ready pod --selector=app.kubernetes.io/name=argocd-server --timeout=300s; \
	else \
		echo "install cancelled"; \
	fi

# $(1) = product. Syncs the live colour first, then the idle one.
define ARGOCD_PROD_COLOURS
	@$(call CLUSTER_CONTEXT_CHECK,production)
	kubectl apply -f ./argocd/production-$(1)-appset.yaml
	kubectl wait -n argocd --for=create application/production-$(1)-blue --timeout=120s
	kubectl wait -n argocd --for=create application/production-$(1)-green --timeout=120s
	@PROD=$$(kubectl get application -n argocd -l role=prod -o name | grep -o 'production-$(1)-[a-z]*$$'); \
	IDLE=$$(kubectl get application -n argocd -l role=staging -o name | grep -o 'production-$(1)-[a-z]*$$'); \
	echo "live: $$PROD  idle: $$IDLE"; \
	argocd app diff $$PROD --refresh; argocd app diff $$IDLE --refresh; \
	read -p "confirm production $(1) colours sync: " confirm; \
	if [ "$$confirm" = "confirm" ]; then \
		argocd app sync $$PROD --prune && argocd app wait $$PROD --sync --health --timeout 1800 && \
		argocd app sync $$IDLE --prune && argocd app wait $$IDLE --sync --health --timeout 1800 && \
		$(MAKE) --no-print-directory invalidate-cdn-prod-$(1); \
	else \
		echo "sync cancelled"; \
	fi
endef

# $(1) = product.
define ARGOCD_PROD_ROUTER
	@$(call CLUSTER_CONTEXT_CHECK,production)
	kubectl apply -f ./argocd/production-$(1)-router.yaml
	kubectl wait -n argocd --for=create application/production-$(1)-router --timeout=120s
	@argocd app diff production-$(1)-router --refresh; \
	read -p "confirm production $(1) router sync: " confirm; \
	if [ "$$confirm" = "confirm" ]; then \
		argocd app sync production-$(1)-router --prune && \
		argocd app wait production-$(1)-router --sync --health --timeout 900 && \
		$(MAKE) --no-print-directory invalidate-cdn-prod-$(1); \
	else \
		echo "sync cancelled"; \
	fi
endef

# $(1) = product, $(2) = its public hostname. The webapp backends sit behind Cloud CDN, and
# /config.js carries each lane's API URLs and GTM id, so after a webapp release or a colour
# swap the cached copy must go, for the live and the staging hostname alike.
define INVALIDATE_CDN_PROD
	@$(call CLUSTER_CONTEXT_CHECK,production)
	@URLMAP=$$(kubectl get ingress production-$(1)-ingress -n production-$(1)-router -o jsonpath='{.metadata.annotations.ingress\.kubernetes\.io/url-map}') && \
	test -n "$$URLMAP" && \
	for host in $(2) staging.$(2); do \
		gcloud compute url-maps invalidate-cdn-cache "$$URLMAP" --path "/config.js" --host "$$host" \
			--global --async --project=open-targets-prod || exit 1; \
	done
endef

deploy-argocd-prod-platform:
	$(call ARGOCD_PROD_COLOURS,platform)

deploy-argocd-prod-platform-router:
	$(call ARGOCD_PROD_ROUTER,platform)

deploy-argocd-prod-ppp:
	$(call ARGOCD_PROD_COLOURS,ppp)

deploy-argocd-prod-ppp-router:
	$(call ARGOCD_PROD_ROUTER,ppp)

invalidate-cdn-prod-platform:
	$(call INVALIDATE_CDN_PROD,platform,platform.opentargets.org)

invalidate-cdn-prod-ppp:
	$(call INVALIDATE_CDN_PROD,ppp,partner-platform.opentargets.org)

# ----------------------------------------------------------------------------------------------------------------------
# Observability stack
deploy-observability-dev:
	@$(call CLUSTER_CONTEXT_CHECK,dev)
	kubectl apply -f ./argocd/devcluster-observability.yaml
	kubectl wait -n argocd --for=create application/observability --timeout=120s
	argocd app wait observability --operation --timeout 900
	argocd app sync observability --prune
	argocd app wait observability --sync --health --timeout 900

deploy-observability-prod:
	@$(call CLUSTER_CONTEXT_CHECK,production)
	kubectl apply -f ./argocd/production-observability.yaml
	kubectl wait -n argocd --for=create application/observability --timeout=120s
	argocd app wait observability --operation --timeout 900
	argocd app sync observability --prune
	argocd app wait observability --sync --health --timeout 900

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

port-forward-argocd:
	@echo "ArgoCD admin password:"
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode; echo
	@kubectl port-forward svc/argocd-server -n argocd 8080:443

# ----------------------------------------------------------------------------------------------------------------------
# Local development (minikube)
create-cluster-local:
	minikube start --driver=docker --cpus=max --memory=max
	minikube addons enable ingress
	kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
	kubectl create namespace argocd
	kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
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
