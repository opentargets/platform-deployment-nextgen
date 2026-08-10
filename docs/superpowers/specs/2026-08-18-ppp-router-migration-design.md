# Bring ppp onto the router chart (devcluster)

## Problem

`platform` has been migrated to a new architecture, still mid-rebase on this branch
(`argocd-rebase-observability`, carrying over work from the unmerged `argocd-nginx-router`
branch):

- Each blue/green colour is its own Helm release, in its own namespace
  (`devcluster-blue-platform`, `devcluster-green-platform`), deployed via an ArgoCD
  `ApplicationSet` (`argocd/devcluster-platform-appset.yaml`).
- A single shared `helm/router` chart release (`argocd/devcluster-platform-router.yaml`, namespace
  `devcluster-platform`) owns the GLB-facing Ingress, BackendConfigs, ComputeAddress, DNS records
  and ManagedCertificates, and fronts nginx reverse-proxy Deployments
  (`helm/router/templates/proxies.yaml`) that forward to whichever colour is currently prod
  (`prodColour`, read from `profiles/devcluster-router.yaml` via a git-file generator).
- Each per-colour `helm/platform` release sets `gcp.ingress: false`
  (`profiles/devcluster-blue.yaml`, `profiles/devcluster-green.yaml`), which skips
  `common.ingress` (`helm/platform/templates/main.yaml:20`) entirely — that release no longer
  creates its own Ingress/BackendConfig/DNS/certs; only the router chart does.

`ppp` has not made this move. It is still deployed as a single flat release straight from
`helm/platform` (`make deploy-chart-dev-ppp` → `helm upgrade --install devcluster-ppp ./helm/platform
-f ./profiles/devcluster-ppp.yaml`), with its own Ingress/BackendConfig/DNS/certs rendered directly
by `common.ingress`, in namespace `devcluster-ppp` (`prefix-product` = `devcluster` + `ppp`).

Cloud Armor's PPP IP allowlist (`google_compute_security_policy.ppp`, `terraform/networking.tf:76`,
named `{global_prefix}-ppp` — `devcluster-ppp` in this environment) is currently attached only via
`securityPolicy: name: {{ $prefix }}-ppp` on that flat release's `BackendConfig`
(`helm/platform/templates/common.yaml:337-340,359-362`, gated `{{- if eq $product "ppp" }}`).

**Decision (confirmed 2026-08-18): mirror platform's blue/green + router split exactly for ppp,
building on the current branch state as-is** (not waiting on `argocd-nginx-router` to merge
elsewhere first).

## Gaps in `helm/router` that block this

`helm/router` was built and only ever exercised against `product: platform`. Two things in it are
not actually product-generic yet, both in `helm/router/templates/gcp-infra.yaml`:

1. **Hardcoded subdomain.** Lines 3-4:
   ```
   {{- $prodSubdomain := printf "platform.%s" .Values.domain }}
   {{- $stagingSubdomain := printf "staging.platform.%s" .Values.domain }}
   ```
   This ignores `.Values.product` entirely. `helm/platform` already solves this correctly with a
   `subdomain` named template (`helm/platform/templates/_helpers.tpl:13-23`): `platform` →
   `platform.{domain}`, `ppp` → `partner-platform.{domain}`, anything else → `{product}.{domain}`.
   `helm/router` has no `_helpers.tpl` of its own to reuse it from (separate chart, no shared
   library chart between them).

2. **No Cloud Armor attachment.** The two `BackendConfig` resources in `gcp-infra.yaml`
   (`{{ $routerNamespace }}-backendconfig-cdn` / `-no-cdn`) have no `securityPolicy` field at all —
   unlike `helm/platform/templates/common.yaml`'s equivalent, which attaches
   `{{ $prefix }}-ppp` when `product == "ppp"`. Without this fix, moving ppp onto the router chart
   would make it publicly reachable — Cloud Armor would still exist in Terraform but nothing would
   point the GLB backend at it.

Everything else in `helm/router` (`proxies.yaml`'s upstream wiring, the genetics-domain DNS records
already gated on `product == "platform"`) is already product-generic and needs no change. Fixing
these two gaps benefits `platform` too (no behaviour change for it — `platform` keeps resolving to
`platform.{domain}`, no `securityPolicy` block since it's gated to `ppp` only) and any future third
product for free.

## Approach

1. Fix the two gaps in `helm/router` (add a local `_helpers.tpl` with the same `subdomain` named
   template as `helm/platform`; add the `securityPolicy` block to both `BackendConfig`s, gated on
   `product == "ppp"`, using `.Values.envPrefix` — which is set to the same value as Terraform's
   `global_prefix` in every profile — so the name always matches the Terraform-managed policy with
   no extra parameter needed).
2. Create per-colour ppp profiles (`profiles/devcluster-ppp-blue.yaml`,
   `profiles/devcluster-ppp-green.yaml`), copying the current live values from
   `profiles/devcluster-ppp.yaml` (image tags, ClickHouse/OpenSearch snapshots, resource sizing,
   `security` block), with `prefix: devcluster-blue` / `devcluster-green`, `product: ppp`, and
   `gcp.ingress: false` — mirroring `profiles/devcluster-blue.yaml` / `devcluster-green.yaml`
   exactly. Both colours start identical, same as platform's blue/green today.
3. Create `profiles/devcluster-ppp-router.yaml`, mirroring `profiles/devcluster-router.yaml` with
   `product: ppp`.
4. Create `argocd/devcluster-ppp-router.yaml` (Application) and `argocd/devcluster-ppp-appset.yaml`
   (ApplicationSet), each a product-substituted copy of the platform equivalents.
5. Update the `Makefile`: remove `deploy-chart-dev-ppp` (it would create a second, colliding set of
   Ingress/BackendConfig/ComputeAddress/DNS resources in the same `devcluster-ppp` namespace the
   router Application now owns — exactly why `deploy-chart-dev-platform` no longer exists in the
   Makefile either), add `deploy-argocd-dev-ppp` mirroring `deploy-argocd-dev-platform`.

## Naming reference (devcluster)

| Concern | Platform (existing) | PPP (this plan) |
|---|---|---|
| Router Application | `argocd/devcluster-platform-router.yaml` → ns `devcluster-platform` | `argocd/devcluster-ppp-router.yaml` → ns `devcluster-ppp` |
| Router profile | `profiles/devcluster-router.yaml` | `profiles/devcluster-ppp-router.yaml` |
| ApplicationSet | `argocd/devcluster-platform-appset.yaml` | `argocd/devcluster-ppp-appset.yaml` |
| Per-colour profiles | `profiles/devcluster-blue.yaml` / `-green.yaml` | `profiles/devcluster-ppp-blue.yaml` / `-green.yaml` |
| Per-colour namespaces | `devcluster-blue-platform` / `devcluster-green-platform` | `devcluster-blue-ppp` / `devcluster-green-ppp` |
| Cloud Armor policy (Terraform, unchanged) | n/a | `devcluster-ppp` (`terraform/networking.tf:77`) |

## Rollout notes

If `devcluster-ppp` is already live from the old flat `helm/platform` release, that release must be
`helm uninstall`ed and that uninstall must strictly precede running `make deploy-argocd-dev-ppp` —
not just happen "before or as part of" it. Both the old release and the new router Application create
an Ingress/BackendConfig/ComputeAddress/DNS records under the same generated names in the same
`devcluster-ppp` namespace, and both new ArgoCD manifests set `syncPolicy.automated: {prune: true,
selfHeal: true}`, so ArgoCD starts reconciling the moment `kubectl apply` runs — there is no safe
window to interleave the uninstall with it (same situation the ArgoCD ops node-pool spec called out
for the old raw-manifest ArgoCD install).

This uninstall is mandatory, not just tidiness: the old release's ManagedCertificate covers 4
domains, the new router's covers 8 (adds the `staging.*` variants), and GKE's
`ManagedCertificate.spec.domains` is effectively immutable — the same-named resource can't be
adopted or updated in place, so the old one has to go first. Separately, accepted as a
devcluster-scale caveat: the old release's `ComputeAddress` has no
`cnrm.cloud.google.com/deletion-policy: abandon` annotation, so `helm uninstall` deletes it and
Config Connector releases the static IP. The router's `ComputeAddress` recreates under the same
resourceID, but GCP allocates a new IP address, which means a fresh certificate-provisioning window
(roughly 15-30 minutes) before HTTPS works again. Fine for devcluster, but worth calling out so
whoever runs this isn't surprised by a temporary outage.

## Out of scope

- Production ppp — `deploy-chart-prod-ppp` (flat `helm/platform` release) is untouched, matching
  `deploy-chart-prod-platform` staying untouched (no production ArgoCD/router setup exists yet for
  either product).
- Local (minikube) ppp support — no `local-ppp*` profiles or ArgoCD apps; `helm/router/templates/
  proxies.yaml`'s non-GCP local Ingress block (lines 107-179, also hardcoded to `platform.`) is left
  alone, matching the existing local setup being platform-only.
- Any change to the Cloud Armor Terraform resource itself, or to nginx-based IP filtering — separate
  topic (see `helm/router/templates/proxies.yaml`'s existing `rateLimiterWhitelist` mechanism and the
  unused `security.blacklist` values-schema field already present for both products).
- Decommissioning/deleting the old `devcluster-ppp` flat release's resources — noted above as a
  manual rollout step, not automated by this plan.
