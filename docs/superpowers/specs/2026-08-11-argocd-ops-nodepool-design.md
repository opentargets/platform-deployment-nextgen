# ArgoCD on the ops node pool (devcluster)

## Problem

ArgoCD (server, repo-server, application-controller, redis, dex, applicationset-controller,
notifications-controller) is currently bootstrapped on both devcluster and local (minikube) by
applying the upstream raw manifest directly:

```
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

That manifest carries no `nodeSelector`/`tolerations`, so ArgoCD's pods land on whichever pool GKE
schedules them to — typically the general apps pool alongside webapp/api/aiapi workloads. We want
ArgoCD's control-plane pods to run on the dedicated `ops` node pool instead, the same pool the
observability stack (Prometheus, Grafana, Loki, Alloy) already runs on.

The `ops` pool (`terraform/main.tf:162-199`) is labeled `pool: ops` and tainted
`workload=ops:NoSchedule`. `helm/observability/values.yaml` already tolerates/targets it per
component with the same key/value pair.

Scope: **devcluster only**. Local (minikube, via `create-cluster-local`) is a single unlabeled
node with no `ops` pool to target, so its ArgoCD bootstrap is unaffected by this change.

## Approach

Replace the raw-manifest bootstrap (devcluster only) with the official `argo-cd` Helm chart
(argo/argo-helm), wrapped in a thin parent chart at `helm/argocd/` — the same chart-of-charts
pattern `helm/observability` uses for its upstream dependencies.

This chart exposes `global.nodeSelector` / `global.tolerations`, which every component
(controller, dex, redis, server, repoServer, applicationSet, notifications) inherits by default
unless overridden per-component. That gives one place to set placement instead of patching each
Deployment/StatefulSet by hand, and it brings ArgoCD's install in line with every other deploy in
this repo (`helm diff` preview before apply).

Local's bootstrap keeps using the raw manifest apply, unchanged.

## Chart layout

`helm/argocd/Chart.yaml`:
- `apiVersion: v2`, `name: argocd`, `type: application`
- One dependency: `argo-cd`, version `10.3.2`, repository `https://argoproj.github.io/argo-helm`

`helm/argocd/values.yaml`:
```yaml
argo-cd:
  global:
    nodeSelector:
      pool: ops
    tolerations:
      - key: workload
        operator: Equal
        value: ops
        effect: NoSchedule
```

This is the same toleration/nodeSelector pair already used by observability's components against
the same `ops` pool.

`Chart.lock` is committed (matches the `helm/observability` convention). `/helm/argocd/charts` is
added to `.gitignore` (matches the existing `/helm/observability/charts` entry).

**Resource-name stability:** installing with release name `argocd` against the chart's
`nameOverride: argocd` produces the same resource names as the raw manifest (`argocd-server`,
`argocd-initial-admin-secret`, etc.), via the chart's `contains $name .Release.Name` fullname
template short-circuit. This keeps `port-forward-argocd` and the existing
`kubectl wait --selector=app.kubernetes.io/name=argocd-server` step working unchanged.

## Makefile changes

`bootstrap-argocd-dev`:
- Drop `kubectl create namespace argocd` and the raw-manifest `kubectl apply -f <URL>`.
- Add `helm dependency build ./helm/argocd`.
- Add a `helm diff upgrade --allow-unreleased argocd ./helm/argocd --namespace argocd` preview,
  paused on `read -p "press enter to continue..."` — matching the confirmation pattern used by
  `deploy-observability-dev`/`deploy-chart-dev-ppp`.
- Replace the install step with
  `helm upgrade --install argocd ./helm/argocd --namespace argocd --create-namespace`.
- Keep the existing `kubectl wait --namespace argocd --for=condition=ready pod --selector=app.kubernetes.io/name=argocd-server --timeout=300s` line as-is.

`create-cluster-local`, `deploy-argocd-dev-platform`, `port-forward-argocd`: unchanged.

## Rollout notes

Devcluster is currently down, so there is no live ArgoCD install to migrate — the next
`bootstrap-argocd-dev` run installs fresh via the new Helm-based path. If this is ever run again
against a cluster that already has the old raw-manifest install, the old install needs to be torn
down first (`kubectl delete -f <raw manifest URL>`), since both would otherwise fight over the same
resource names/namespace. No such teardown is needed for this rollout.

No Terraform changes are required — the `ops` node pool already exists and is proven by the
observability stack's use of the same taint/label pair.

## Out of scope

- Local (minikube) ArgoCD placement.
- Production ArgoCD (doesn't exist yet).
- Any change to `helm/observability` or the `ops` node pool's Terraform definition.
- Migrating an already-bootstrapped devcluster ArgoCD install (not applicable — devcluster is down).
