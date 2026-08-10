# Bring ppp onto the router chart (devcluster) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move `ppp` from a single flat `helm/platform` release onto the same blue/green-via-router
architecture `platform` already uses on this branch — an ArgoCD `ApplicationSet` driving two
per-colour `helm/platform` releases plus a shared `helm/router` release owning the GLB Ingress —
while fixing the two product-generic gaps in `helm/router` that currently make it platform-only.

**Architecture:** `helm/router` gains a local `_helpers.tpl` `subdomain` named template (copied from
`helm/platform/templates/_helpers.tpl:13-23`) and a `securityPolicy` block on both `BackendConfig`s
gated on `product == "ppp"`. New per-colour profiles (`profiles/devcluster-ppp-blue.yaml`,
`-green.yaml`) and a router profile (`profiles/devcluster-ppp-router.yaml`) are created by copying
the platform equivalents and substituting `product`/`prefix`/namespace values plus ppp's current live
config (from `profiles/devcluster-ppp.yaml`). New ArgoCD `Application`
(`argocd/devcluster-ppp-router.yaml`) and `ApplicationSet` (`argocd/devcluster-ppp-appset.yaml`)
mirror the platform ones exactly. The `Makefile`'s stale flat `deploy-chart-dev-ppp` target is
removed (it would collide with the router's resources in the same namespace) and replaced with
`deploy-argocd-dev-ppp`.

**Tech Stack:** Helm 3, `helm-diff` plugin, ArgoCD `Application`/`ApplicationSet` CRDs, GKE Ingress +
Config Connector (`ComputeAddress`, `DNSRecordSet`, `ManagedCertificate`), GCP `BackendConfig`/Cloud
Armor.

**Spec:** `docs/superpowers/specs/2026-08-18-ppp-router-migration-design.md`

## Global Constraints

- Scope is **devcluster only** — do not touch `deploy-chart-prod-ppp`, `profiles/production-ppp.yaml`,
  or add any production router/ApplicationSet files.
- No local (minikube) ppp support — do not create `local-ppp*` files or touch
  `helm/router/templates/proxies.yaml`'s non-GCP Ingress block.
- No Terraform changes — `google_compute_security_policy.ppp` already exists and is named
  `{global_prefix}-ppp` (`devcluster-ppp` in this environment).
- `helm/router`'s fix for `product == "ppp"` must not change any rendered output for
  `product == "platform"` — verify both in Task 1.
- Both new per-colour ppp profiles start with identical values (mirroring how
  `profiles/devcluster-blue.yaml`/`devcluster-green.yaml` are identical today).

---

### Task 1: Make `helm/router` product-generic — subdomain + Cloud Armor attachment

**Files:**
- Create: `helm/router/templates/_helpers.tpl`
- Modify: `helm/router/templates/gcp-infra.yaml:1-4` (subdomain computation), and the two
  `BackendConfig` `spec:` blocks (`{{ $routerNamespace }}-backendconfig-cdn` and `-no-cdn`)

**Interfaces:**
- Produces: a `subdomain` named template callable as `{{ include "subdomain" . }}` from any
  `helm/router` template, and `securityPolicy` support on both router `BackendConfig`s for
  `product: ppp`. Consumed by Task 3's `helm template` verification.

- [ ] **Step 1: Create `helm/router/templates/_helpers.tpl`**

```yaml
{{- define "subdomain" -}}
{{- $product := .Values.product -}}
{{- $domain := .Values.domain -}}
{{- if eq $product "platform" -}}
{{- printf "platform.%s" $domain -}}
{{- else if eq $product "ppp" -}}
{{- printf "partner-platform.%s" $domain -}}
{{- else -}}
{{- printf "%s.%s" $product $domain -}}
{{- end -}}
{{- end }}
```

This is an exact copy of `helm/platform/templates/_helpers.tpl:13-23`.

- [ ] **Step 2: Replace the hardcoded subdomain lines in `gcp-infra.yaml`**

Current (`helm/router/templates/gcp-infra.yaml:1-4`):
```yaml
{{- if .Values.gcp.enabled }}
{{- $routerNamespace := printf "%s-%s" .Values.envPrefix .Values.product }}
{{- $prodSubdomain := printf "platform.%s" .Values.domain }}
{{- $stagingSubdomain := printf "staging.platform.%s" .Values.domain }}
```

Replace with:
```yaml
{{- if .Values.gcp.enabled }}
{{- $routerNamespace := printf "%s-%s" .Values.envPrefix .Values.product }}
{{- $prodSubdomain := include "subdomain" . }}
{{- $stagingSubdomain := printf "staging.%s" $prodSubdomain }}
```

Every other line in the file already references `$prodSubdomain`/`$stagingSubdomain` as variables,
so no other line changes.

- [ ] **Step 3: Add `securityPolicy` to the CDN `BackendConfig`**

In `helm/router/templates/gcp-infra.yaml`, find:
```yaml
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: {{ $routerNamespace }}-backendconfig-cdn
  namespace: {{ $routerNamespace }}
spec:
  customResponseHeaders:
    headers:
      - "Strict-Transport-Security: max-age=31536000; includeSubDomains; preload"
      - "X-Content-Type-Options: nosniff"
      - "X-Frame-Options: DENY"
      - "Content-Security-Policy: base-uri 'self'; frame-ancestors 'none'"
  cdn:
    enabled: true
    cachePolicy:
      includeHost: true
      includeProtocol: true
      includeQueryString: false
    negativeCaching: true
    negativeCachingPolicy:
      - code: 404
        ttl: 120
      - code: 410
        ttl: 120
```

Add immediately after the `negativeCachingPolicy` block (still inside `spec:`):
```yaml
  {{- if eq .Values.product "ppp" }}
  securityPolicy:
    name: {{ .Values.envPrefix }}-ppp
  {{- end }}
```

- [ ] **Step 4: Add `securityPolicy` to the no-CDN `BackendConfig`**

Find:
```yaml
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: {{ $routerNamespace }}-backendconfig-no-cdn
  namespace: {{ $routerNamespace }}
spec:
  healthCheck:
    requestPath: /health
    port: 8080
    type: HTTP
  customResponseHeaders:
    headers:
      - "Strict-Transport-Security: max-age=31536000; includeSubDomains; preload"
      - "X-Content-Type-Options: nosniff"
  cdn:
    enabled: false
```

Add immediately after `cdn: enabled: false` (still inside `spec:`):
```yaml
  {{- if eq .Values.product "ppp" }}
  securityPolicy:
    name: {{ .Values.envPrefix }}-ppp
  {{- end }}
```

- [ ] **Step 5: Verify platform rendering is unchanged**

Run:
```bash
helm template devcluster-platform-router ./helm/router -f ./profiles/devcluster-router.yaml \
  | grep -E "host: |securityPolicy|name: .*-ppp"
```

Expected: hosts are `platform.opentargets.xyz`, `www.platform.opentargets.xyz`,
`api.platform.opentargets.xyz`, `ai.platform.opentargets.xyz`, `staging.platform.opentargets.xyz`
(+ `www.`/`api.`/`ai.` variants), plus the unconditional `genetics.opentargets.xyz` /
`www.genetics.opentargets.xyz` entries. **No** `securityPolicy` or `-ppp` lines appear anywhere.

- [ ] **Step 6: Verify ppp rendering picks up both fixes**

Run:
```bash
helm template devcluster-ppp-router ./helm/router -f ./profiles/devcluster-router.yaml \
  --set product=ppp \
  | grep -E "host: |securityPolicy|name: devcluster-ppp"
```

Expected: hosts are `partner-platform.opentargets.xyz` (+ `www.`/`api.`/`ai.` variants) and
`staging.partner-platform.opentargets.xyz` (+ variants) — no `genetics.` entries. Two
`securityPolicy:` blocks appear, each followed by `name: devcluster-ppp`.

- [ ] **Step 7: Commit**

```bash
git add helm/router/templates/_helpers.tpl helm/router/templates/gcp-infra.yaml
git commit -m "Make helm/router's subdomain and Cloud Armor attachment product-generic"
```

---

### Task 2: Per-colour ppp profiles

**Files:**
- Create: `profiles/devcluster-ppp-blue.yaml`
- Create: `profiles/devcluster-ppp-green.yaml`

**Interfaces:**
- Consumes: current live values from `profiles/devcluster-ppp.yaml`.
- Produces: value files consumed by Task 4's ApplicationSet (`valueFiles: /profiles/devcluster-ppp-{{ .colour }}.yaml`).

- [ ] **Step 1: Create `profiles/devcluster-ppp-blue.yaml`**

```yaml
gcpProject: open-targets-eu-dev
prefix: devcluster-blue
product: ppp
domain: opentargets.xyz
dnsZone: opentargets-xyz

googleTagManagerId: GTM-XXXXXXX

gcp:
  enabled: true
  ingress: false

release: '26.03'
webapp:
  image: europe-west1-docker.pkg.dev/open-targets-eu-dev/ot-ui-apps/ot-ui-apps:0.15.9
api:
  image: europe-west1-docker.pkg.dev/open-targets-eu-dev/platform-api/platform-api:26.03.2-rc.1
aiapi:
  image: europe-west1-docker.pkg.dev/open-targets-eu-dev/ot-ai-api/ot-ai-api:0.0.13
  secrets:
    openai: projects/open-targets-eu-dev/locations/europe-west1/secrets/openai-token
clickhouse:
  image: clickhouse/clickhouse-server:25.8.18.1
  snapshot: projects/open-targets-eu-dev/global/snapshots/ppp-2603-ch-rc2
opensearch:
  image: opensearchproject/opensearch:3.5.0
  snapshot: projects/open-targets-eu-dev/global/snapshots/ppp-2603-os-rc1

resources:
  webapp:
    minReplicas: 2
    maxReplicas: 5
    requests:
      memory: 32Mi
      cpu: 50m
    limits:
      memory: 256Mi
      cpu: 500m
  api:
    minReplicas: 2
    maxReplicas: 5
    requests:
      memory: 2Gi
      cpu: 1000m
    limits:
      memory: 4Gi
      cpu: 2000m
  aiapi:
    minReplicas: 2
    maxReplicas: 5
    requests:
      memory: 72Mi
      cpu: 50m
    limits:
      memory: 256Mi
      cpu: 500m
  clickhouse:
    replicas: 2
    requests:
      memory: 2Gi
      cpu: 500m
    limits:
      memory: 10Gi
      cpu: 2000m
  opensearch:
    replicas: 2
    heapSize: 2g
    requests:
      memory: 2Gi
      cpu: 1000m
    limits:
      memory: 4Gi
      cpu: 4000m

security:
  rateLimiterWhitelist: []
  blacklist: []
```

- [ ] **Step 2: Create `profiles/devcluster-ppp-green.yaml`**

Identical content to Step 1, with `prefix: devcluster-green` in place of `prefix: devcluster-blue`.

- [ ] **Step 3: Verify both render cleanly with no GCP ingress resources**

Run:
```bash
for colour in blue green; do
  echo "=== $colour ===" ; \
  helm template devcluster-ppp-$colour ./helm/platform -f ./profiles/devcluster-ppp-$colour.yaml \
    --set colour=$colour --set prodColour=blue --set stagingEnabled=false \
    | grep -E "^kind: |namespace: devcluster-$colour-ppp" | sort -u
done
```

Expected: for each colour, `kind:` lines include `Namespace`, `NetworkPolicy`, `Deployment`,
`StatefulSet`, `Service` (webapp/api/aiapi/clickhouse/opensearch) — but **no** `Ingress`,
`BackendConfig`, `ComputeAddress`, `DNSRecordSet`, or `ManagedCertificate` (those are skipped by
`gcp.ingress: false`). Namespace lines all read `devcluster-blue-ppp` / `devcluster-green-ppp`
respectively.

- [ ] **Step 4: Commit**

```bash
git add profiles/devcluster-ppp-blue.yaml profiles/devcluster-ppp-green.yaml
git commit -m "Add per-colour ppp profiles for the devcluster router migration"
```

---

### Task 3: PPP router profile

**Files:**
- Create: `profiles/devcluster-ppp-router.yaml`

**Interfaces:**
- Consumes: Task 1's `helm/router` fixes.
- Produces: value file consumed by Task 4's Application (`valueFiles: /profiles/devcluster-ppp-router.yaml`) and by the ApplicationSet's git-file generator (reads `prodColour`/`stagingEnabled` from this same file, matching how `devcluster-platform-appset.yaml` reads them from `profiles/devcluster-router.yaml`).

- [ ] **Step 1: Create `profiles/devcluster-ppp-router.yaml`**

```yaml
prodColour: blue
envPrefix: devcluster
product: ppp
domain: opentargets.xyz
dnsZone: opentargets-xyz
gcpProject: open-targets-eu-dev
gcp:
  enabled: true
stagingEnabled: false
```

`prodColour: blue` matches the colour Task 2 wrote as ppp's current live values into
`devcluster-ppp-blue.yaml`; `stagingEnabled: false` mirrors `profiles/devcluster-router.yaml`'s
current value for platform.

- [ ] **Step 2: Verify it renders the ppp Ingress/BackendConfig correctly**

Run:
```bash
helm template devcluster-ppp-router ./helm/router -f ./profiles/devcluster-ppp-router.yaml \
  | grep -E "^kind: |host: |name: devcluster-ppp$|securityPolicy"
```

Expected: `kind:` lines include `Namespace`, `ComputeAddress`, `DNSRecordSet` (x8, no genetics
entries), `ManagedCertificate` (x2), `BackendConfig` (x2), `FrontendConfig`, `Ingress`. Hosts are
`partner-platform.opentargets.xyz` and its `www./api./ai.` and `staging.` variants. Two
`securityPolicy:` blocks, `name: devcluster-ppp` under both.

- [ ] **Step 3: Commit**

```bash
git add profiles/devcluster-ppp-router.yaml
git commit -m "Add devcluster ppp router profile"
```

---

### Task 4: ArgoCD Application + ApplicationSet for ppp

**Files:**
- Create: `argocd/devcluster-ppp-router.yaml`
- Create: `argocd/devcluster-ppp-appset.yaml`

**Interfaces:**
- Consumes: `profiles/devcluster-ppp-router.yaml` (Task 3), `profiles/devcluster-ppp-blue.yaml` /
  `-green.yaml` (Task 2).
- Produces: ArgoCD resources consumed by Task 5's `deploy-argocd-dev-ppp` Makefile target
  (`argocd app sync devcluster-ppp-router|devcluster-ppp-blue|devcluster-ppp-green`).

- [ ] **Step 1: Create `argocd/devcluster-ppp-router.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: devcluster-ppp-router
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/opentargets/platform-deployment-nextgen.git
    targetRevision: argocd-nginx-router
    path: helm/router
    helm:
      valueFiles:
        - /profiles/devcluster-ppp-router.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: devcluster-ppp
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

This is `argocd/devcluster-platform-router.yaml` with `platform` → `ppp` throughout (name,
`valueFiles` path, destination `namespace`).

- [ ] **Step 2: Create `argocd/devcluster-ppp-appset.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: devcluster-ppp
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
    - matrix:
        generators:
          - list:
              elements:
                - colour: blue
                - colour: green
          # Reads prodColour/stagingEnabled from the router profile so both
          # colours automatically know whether they're prod or idle staging.
          - git:
              repoURL: https://github.com/opentargets/platform-deployment-nextgen.git
              revision: argocd-nginx-router
              files:
                - path: profiles/devcluster-ppp-router.yaml
  template:
    metadata:
      name: devcluster-ppp-{{ .colour }}
      labels:
        role: "{{ if eq .colour .prodColour }}prod{{ else }}staging{{ end }}"
    spec:
      project: default
      source:
        repoURL: https://github.com/opentargets/platform-deployment-nextgen.git
        targetRevision: argocd-nginx-router
        path: helm/platform
        helm:
          valueFiles:
            - /profiles/devcluster-ppp-{{ .colour }}.yaml
          parameters:
            - name: colour
              value: "{{ .colour }}"
            - name: prodColour
              value: "{{ .prodColour }}"
            - name: stagingEnabled
              value: "{{ .stagingEnabled }}"
      destination:
        server: https://kubernetes.default.svc
        namespace: devcluster-{{ .colour }}-ppp
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

This is `argocd/devcluster-platform-appset.yaml` with `platform` → `ppp` throughout (name, git-file
generator path, `valueFiles` path, destination `namespace`).

- [ ] **Step 3: Verify both are valid YAML and diff cleanly against the platform originals**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('argocd/devcluster-ppp-router.yaml'))" && echo OK
python3 -c "import yaml; yaml.safe_load(open('argocd/devcluster-ppp-appset.yaml'))" && echo OK
diff <(sed 's/platform/ppp/g' argocd/devcluster-platform-router.yaml) argocd/devcluster-ppp-router.yaml
diff <(sed 's/platform/ppp/g' argocd/devcluster-platform-appset.yaml) argocd/devcluster-ppp-appset.yaml
```

Expected: both `python3` commands print `OK`. Both `diff` commands print nothing (empty diff),
confirming the only substitution from the platform originals is the literal string `platform` → `ppp`.

- [ ] **Step 4: Commit**

```bash
git add argocd/devcluster-ppp-router.yaml argocd/devcluster-ppp-appset.yaml
git commit -m "Add ArgoCD Application + ApplicationSet for devcluster ppp router migration"
```

---

### Task 5: Makefile — replace flat ppp dev deploy with ArgoCD-based deploy

**Files:**
- Modify: `Makefile` (`.PHONY` list, `help` target, `deploy-chart-dev-ppp` removal,
  `deploy-argocd-dev-ppp` addition)

**Interfaces:**
- Consumes: `argocd/devcluster-ppp-router.yaml` and `argocd/devcluster-ppp-appset.yaml` (Task 4).

- [ ] **Step 1: Remove `deploy-chart-dev-ppp` from `.PHONY`**

Current:
```makefile
.PHONY: deploy-cluster-dev destroy-cluster-dev deploy-cluster-prod \
	bootstrap-argocd-dev deploy-argocd-dev-platform deploy-chart-dev-ppp deploy-chart-prod-platform deploy-chart-prod-ppp \
```

Replace with:
```makefile
.PHONY: deploy-cluster-dev destroy-cluster-dev deploy-cluster-prod \
	bootstrap-argocd-dev deploy-argocd-dev-platform deploy-argocd-dev-ppp deploy-chart-prod-platform deploy-chart-prod-ppp \
```

- [ ] **Step 2: Update the `help` target**

Current:
```makefile
	@echo "  deploy-argocd-dev-platform - ARGO — Bootstrap + sync the platform blue/green ArgoCD apps on the dev cluster"
	@echo "  deploy-chart-dev-ppp       - HELM — Deploy the PPP      flavor on the dev  cluster"
```

Replace with:
```makefile
	@echo "  deploy-argocd-dev-platform - ARGO — Bootstrap + sync the platform blue/green ArgoCD apps on the dev cluster"
	@echo "  deploy-argocd-dev-ppp      - ARGO — Bootstrap + sync the ppp      blue/green ArgoCD apps on the dev cluster"
```

- [ ] **Step 3: Replace the `deploy-chart-dev-ppp` target with `deploy-argocd-dev-ppp`**

Current:
```makefile
deploy-chart-dev-ppp:
	@$(call CLUSTER_CONTEXT_CHECK,dev)
	helm diff upgrade --allow-unreleased devcluster-ppp ./helm/platform -f ./profiles/devcluster-ppp.yaml; \
	read -p "press enter to continue..." nothing; \
	helm upgrade --install devcluster-ppp ./helm/platform -f ./profiles/devcluster-ppp.yaml
```

Replace with:
```makefile
deploy-argocd-dev-ppp:
	@$(call CLUSTER_CONTEXT_CHECK,dev)
	kubectl apply -f ./argocd/devcluster-ppp-router.yaml
	kubectl apply -f ./argocd/devcluster-ppp-appset.yaml
	argocd app sync devcluster-ppp-router --prune
	argocd app sync devcluster-ppp-blue --prune
	argocd app sync devcluster-ppp-green --prune
```

This is an exact copy of `deploy-argocd-dev-platform`'s body with `platform` → `ppp`.

- [ ] **Step 4: Dry-run to confirm the target parses and issues the right commands**

Run: `make -n deploy-argocd-dev-ppp`

Expected output (after the `CLUSTER_CONTEXT_CHECK` guard, which requires a `dev` kube-context and
will short-circuit here if none is active — that's fine, this step only checks the recipe parses):
```
kubectl apply -f ./argocd/devcluster-ppp-router.yaml
kubectl apply -f ./argocd/devcluster-ppp-appset.yaml
argocd app sync devcluster-ppp-router --prune
argocd app sync devcluster-ppp-blue --prune
argocd app sync devcluster-ppp-green --prune
```

- [ ] **Step 5: Confirm `deploy-chart-dev-ppp` is gone and prod targets are untouched**

Run:
```bash
grep -n "deploy-chart-dev-ppp" Makefile
grep -n "deploy-chart-prod-ppp\|deploy-chart-prod-platform" Makefile
```

Expected: the first `grep` finds nothing (exit status 1). The second `grep` still lists both
production targets, unchanged.

- [ ] **Step 6: Commit**

```bash
git add Makefile
git commit -m "Replace flat devcluster ppp deploy with ArgoCD-based blue/green + router deploy"
```

---

## Self-Review

- **Spec coverage:** Task 1 covers "Gaps in `helm/router`" (both the subdomain fix and the
  `securityPolicy` fix, with regression verification for `platform` in Step 5). Task 2 covers
  "per-colour ppp profiles". Task 3 covers "ppp router profile". Task 4 covers "ArgoCD
  Application/ApplicationSet". Task 5 covers "Makefile" changes including the explicit removal
  rationale from the spec's "Approach" step 5. The spec's "Rollout notes" (manual `helm uninstall`
  of the old flat release) and "Out of scope" items are deliberately not turned into plan tasks —
  they're operational/manual notes and exclusions, not implementation work.
- **Placeholder scan:** no TBD/TODO; every step has literal file content, literal diffs, or literal
  commands with expected output.
- **Type/name consistency:** `devcluster-ppp-router` / `devcluster-ppp-blue` / `devcluster-ppp-green`
  ArgoCD Application names are used identically across Task 4 (creation) and Task 5 (`argocd app
  sync` calls). `profiles/devcluster-ppp-router.yaml`'s `prodColour: blue` matches the colour that
  received ppp's current live values in Task 2 Step 1. `.Values.envPrefix` (Task 1) matches the
  `envPrefix: devcluster` key set in Task 3's router profile, and Terraform's `global_prefix =
  "devcluster"` (`profiles/devcluster.tfvars`), so the rendered `securityPolicy.name` (`devcluster-ppp`)
  matches the actual Terraform-managed Cloud Armor policy name.
