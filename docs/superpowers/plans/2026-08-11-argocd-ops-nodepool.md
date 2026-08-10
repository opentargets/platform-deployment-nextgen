# ArgoCD on the ops node pool (devcluster) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Schedule ArgoCD's devcluster control-plane pods (server, repo-server, application-controller, redis, dex, applicationset-controller, notifications-controller) onto the dedicated `ops` GKE node pool, the same pool the observability stack already runs on.

**Architecture:** Replace the devcluster ArgoCD bootstrap (currently a raw-manifest `kubectl apply` against the upstream install URL) with a thin Helm parent chart at `helm/argocd/` that wraps the official `argo-cd` chart (argo/argo-helm) as a dependency, matching the chart-of-charts pattern `helm/observability` already uses. The wrapper's `values.yaml` sets `global.nodeSelector`/`global.tolerations`, which every ArgoCD component inherits. Local (minikube) bootstrap is untouched — it has no `ops`-labeled node.

**Tech Stack:** Helm 3, `helm-diff` plugin, the `argo-cd` chart from `https://argoproj.github.io/argo-helm` (pinned `10.3.2`), GKE (`ops` node pool defined in `terraform/main.tf:162-199`).

## Global Constraints

- Scope is **devcluster only** — do not modify `create-cluster-local`'s ArgoCD bootstrap.
- Pin the `argo-cd` dependency to version `10.3.2` (chart repo `https://argoproj.github.io/argo-helm`).
- `global.nodeSelector` must be `pool: ops`; `global.tolerations` must be exactly `key: workload, operator: Equal, value: ops, effect: NoSchedule` — this is the identical pair `helm/observability/values.yaml` already uses against the same node pool.
- The Helm release name for ArgoCD must be `argocd` (not e.g. `argo-cd`), so the chart's `nameOverride: argocd` fullname short-circuit keeps resource names (`argocd-server`, `argocd-initial-admin-secret`, etc.) identical to the old raw-manifest install — `port-forward-argocd` and the `kubectl wait --selector=app.kubernetes.io/name=argocd-server` line in the Makefile depend on this.
- Commit `Chart.lock`; gitignore the fetched `charts/` directory, matching the existing `/helm/observability/charts` entry.
- No Terraform changes — the `ops` pool already exists.

---

### Task 1: `helm/argocd` chart — dependency, values, verified render

**Files:**
- Modify: `.gitignore`
- Create: `helm/argocd/Chart.yaml`
- Create: `helm/argocd/values.yaml`
- Create (generated): `helm/argocd/Chart.lock`, `helm/argocd/charts/` (gitignored)

**Interfaces:**
- Produces: a Helm chart installable as `helm upgrade --install argocd ./helm/argocd --namespace argocd --create-namespace`, which Task 2's Makefile target consumes.

- [ ] **Step 1: Add the generated dependency archive dir to `.gitignore`**

Open `.gitignore` and add a new line after the existing `/helm/observability/charts` entry:

```
/helm/observability/charts
/helm/argocd/charts
```

- [ ] **Step 2: Create `helm/argocd/Chart.yaml`**

```yaml
apiVersion: v2
name: argocd
description: Helm chart wrapping ArgoCD, pinned to the devcluster ops node pool.
type: application
version: "0.1.0"
dependencies:
  - name: argo-cd
    version: 10.3.2
    repository: https://argoproj.github.io/argo-helm
```

- [ ] **Step 3: Create `helm/argocd/values.yaml`**

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

- [ ] **Step 4: Fetch the dependency and generate `Chart.lock`**

Run: `helm dependency build ./helm/argocd`

Expected: command succeeds, prints `Saving 1 charts` / `Deleting outdated charts`, and creates both `helm/argocd/Chart.lock` and `helm/argocd/charts/argo-cd-10.3.2.tgz`.

- [ ] **Step 5: Verify `Chart.lock` pins the expected version**

Run: `grep -A2 "name: argo-cd" helm/argocd/Chart.lock`

Expected output includes:
```
- name: argo-cd
  repository: https://argoproj.github.io/argo-helm
  version: 10.3.2
```

- [ ] **Step 6: Verify the ops nodeSelector/tolerations render on every ArgoCD component**

Run:
```bash
helm template argocd ./helm/argocd --namespace argocd \
  | grep -B5 "pool: ops" \
  | grep "^# Source:"
```

Expected: this lists a `# Source:` line for each of the following templates (one per ArgoCD component) — confirming `nodeSelector: {pool: ops}` was rendered into each:
- `argo-cd/templates/argocd-server/deployment.yaml`
- `argo-cd/templates/argocd-repo-server/deployment.yaml`
- `argo-cd/templates/argocd-application-controller/statefulset.yaml`
- `argo-cd/templates/argocd-redis/deployment.yaml`
- `argo-cd/templates/dex/deployment.yaml`
- `argo-cd/templates/argocd-applicationset/deployment.yaml`
- `argo-cd/templates/argocd-notifications/deployment.yaml`

If any are missing, check `helm show values argo-cd/argo-cd --version 10.3.2` for that component's `nodeSelector` default — it must read `{}` with a comment `defaults to global.nodeSelector` for the global value to apply.

- [ ] **Step 7: Verify the toleration renders alongside it**

Run:
```bash
helm template argocd ./helm/argocd --namespace argocd | grep -A4 "tolerations:" | grep "value: ops"
```

Expected: at least 7 matches (one per component listed in Step 6).

- [ ] **Step 8: Commit**

```bash
git add .gitignore helm/argocd/Chart.yaml helm/argocd/values.yaml helm/argocd/Chart.lock
git commit -m "Add helm/argocd chart wrapping ArgoCD, pinned to the ops node pool"
```

Note: `helm/argocd/charts/` is gitignored (Step 1) and must NOT be added.

---

### Task 2: Switch `bootstrap-argocd-dev` to the Helm-based install

**Files:**
- Modify: `Makefile:60-64` (the `bootstrap-argocd-dev` target)

**Interfaces:**
- Consumes: `helm/argocd` chart from Task 1 (release name `argocd`, namespace `argocd`).

- [ ] **Step 1: Replace the `bootstrap-argocd-dev` recipe**

Current (`Makefile:60-64`):
```makefile
bootstrap-argocd-dev:
	@$(call CLUSTER_CONTEXT_CHECK,dev)
	kubectl create namespace argocd
	kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	kubectl wait --namespace argocd --for=condition=ready pod --selector=app.kubernetes.io/name=argocd-server --timeout=300s
```

Replace with:
```makefile
bootstrap-argocd-dev:
	@$(call CLUSTER_CONTEXT_CHECK,dev)
	@helm dependency build ./helm/argocd
	@helm diff upgrade --allow-unreleased argocd ./helm/argocd --namespace argocd; \
	read -p "press enter to continue..." nothing; \
	helm upgrade --install argocd ./helm/argocd --namespace argocd --create-namespace
	kubectl wait --namespace argocd --for=condition=ready pod --selector=app.kubernetes.io/name=argocd-server --timeout=300s
```

This mirrors the diff-then-confirm pattern already used by `deploy-observability-dev` (`Makefile:106-110`).

- [ ] **Step 2: Dry-run the target to check it parses and issues the right commands**

Run: `make -n bootstrap-argocd-dev`

Expected: `make` prints (without executing) something equivalent to:
```
helm dependency build ./helm/argocd
helm diff upgrade --allow-unreleased argocd ./helm/argocd --namespace argocd
read -p "press enter to continue..." nothing
helm upgrade --install argocd ./helm/argocd --namespace argocd --create-namespace
kubectl wait --namespace argocd --for=condition=ready pod --selector=app.kubernetes.io/name=argocd-server --timeout=300s
```
No raw-manifest URL and no `kubectl create namespace` should appear. `make -n` does not touch any cluster (no context-check side effects), so this is safe to run without a live devcluster.

- [ ] **Step 3: Confirm `create-cluster-local` is untouched**

Run: `git diff Makefile`

Expected: the diff only touches the `bootstrap-argocd-dev` target — `create-cluster-local` (which still does `kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml`), `deploy-argocd-dev-platform`, and `port-forward-argocd` are unchanged.

- [ ] **Step 4: Commit**

```bash
git add Makefile
git commit -m "Bootstrap devcluster ArgoCD via helm/argocd instead of the raw upstream manifest"
```

---

## Self-Review

- **Spec coverage:** Chart + dependency pin (Task 1, Steps 2-5) — covers "Chart layout" section of the spec. `global.nodeSelector`/`global.tolerations` render verification (Task 1, Steps 6-7) — covers the spec's core requirement. Makefile bootstrap replacement (Task 2) — covers "Makefile changes". Local untouched (Task 2, Step 3) — covers "Scope: devcluster only". Resource-name stability is called out as a Global Constraint and satisfied by using release name `argocd` in both tasks. No Terraform changes are made anywhere in this plan, matching the spec's "Out of scope" list.
- **Placeholder scan:** no TBD/TODO; every step has literal file content or literal commands with expected output.
- **Type/name consistency:** release name `argocd`, namespace `argocd`, and chart path `./helm/argocd` are used identically across Task 1 Step 4/6/7 and Task 2 Steps 1/2. Dependency name `argo-cd` (key in `values.yaml`, `name:` in `Chart.yaml`) is consistent throughout.
