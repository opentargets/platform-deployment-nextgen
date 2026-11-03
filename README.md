# Open Targets nextgen deployment

This the repo for managing the deployment of the Open Targets Platform and PPP to three kubernetes environments:
- local (minikube)
- dev (GKE)
- production (GKE)

There is a Makefile for most operations such as creating the kubernetes clusters. 
Deployments are managed by ArgoCD. 

## Repository layout

- `helm/` — Helm charts: `platform` (the Open Targets Platform workloads), `router` (the
  edge nginx router), `argocd`, and `observability`.
- `profiles/` — per-environment values files. `devcluster`, `production` and `local`.
- `argocd/` — ArgoCD `Application` and `ApplicationSet` resources.
- `terraform/` — GKE clusters, node pools, IAM and GCS buckets.
- `docs/` — documentation.

## Observability

The observability stack (Prometheus, Grafana, Loki, Alloy) is documented in
[docs/observability/](docs/observability/):
[reference](docs/observability/README.md),
[known gaps](docs/observability/gaps.md),
[runbook](docs/observability/runbook.md).

Release process: https://opentargets.org/technical-knowledge-base/platform/release-process/

## Copyright

Copyright 2014-2024 EMBL - European Bioinformatics Institute, Genentech, GSK,
MSD, Pfizer, Sanofi and Wellcome Sanger Institute

This software was developed as part of the Open Targets project. For more
information please see: http://www.opentargets.org

Licensed under the Apache License, Version 2.0 (the "License"); you may not use
this file except in compliance with the License. You may obtain a copy of the
License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
