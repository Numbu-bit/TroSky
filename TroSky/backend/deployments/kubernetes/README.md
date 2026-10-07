# Kubernetes manifests

Raw manifests organized with a `kustomize` overlay point (`kustomization.yaml`),
not a Helm chart — simpler to read end-to-end and review in a PR without
requiring Helm-template familiarity. A Helm chart wrapping these same
resources (for templated multi-environment `values.yaml` files) is a
mechanical follow-up if the team later wants one; nothing here is
Helm-incompatible.

## What's here

| File | Purpose |
|---|---|
| `namespace.yaml` | The `trosky` namespace everything else lives in. |
| `configmap.yaml` | Non-secret runtime configuration. |
| `secret.example.yaml` | **Template only** — documents every secret key the app needs; never apply as-is. Provision the real Secret via your cluster's secret manager integration. |
| `api-deployment.yaml` / `api-service.yaml` / `api-hpa.yaml` / `api-pdb.yaml` | The HTTP API: 3–12 replicas, autoscaled on CPU/memory, rolling updates with zero unavailable capacity, a PodDisruptionBudget keeping at least 2 up through voluntary disruptions. |
| `worker-deployment.yaml` / `worker-hpa.yaml` / `worker-pdb.yaml` | Celery workers (background tasks: booking-hold expiry, payment reconciliation, GPS-log purge). |
| `scheduler-deployment.yaml` | Celery beat — **exactly one replica**, `Recreate` strategy. Two beat processes would each independently fire every scheduled task; this is load-bearing, not a default left unconsidered. |
| `migration-job.yaml` | A one-shot `alembic upgrade head` Job, applied as an explicit pre-deploy pipeline step — never run implicitly by application pods on startup (N replicas racing migrations concurrently is the exact failure mode this avoids). |
| `ingress.yaml` | TLS termination + routing, written for ingress-nginx with extended timeouts for the long-lived WebSocket tracking connection. |
| `networkpolicy.yaml` | Default-deny plus explicit allows (ingress → api only, DNS, external HTTPS/Postgres/Redis, in-cluster OTel collector). |

## Applying

```bash
# Every release:
kubectl apply -f migration-job.yaml   # after editing the image tag
kubectl wait --for=condition=complete job/trosky-migrate-<tag> -n trosky --timeout=300s
kubectl apply -k .                    # after setting the image tag in kustomization.yaml
```

Set the image tag either by editing `kustomization.yaml`'s `images.newTag`
(and `migration-job.yaml`'s `REPLACE_WITH_IMAGE_TAG`) directly, or via
`kustomize edit set image ghcr.io/trosky/backend=ghcr.io/trosky/backend:<tag>`
in a CI/CD step — see `.github/workflows/backend.yml`'s `deploy-*` jobs for
where that step would plug in (those jobs currently trigger
environment-scoped deployment webhooks rather than applying manifests
directly; no cluster credentials are provisioned for this project yet).

## Assumptions

* An external, managed Postgres (PostGIS-enabled) and Redis are assumed —
  nothing here deploys a database or cache *inside* the cluster. `docker-compose.yml`
  is the local-dev equivalent that does run them in-cluster (well, in Compose).
* Object storage (S3-compatible) and the OTel collector are likewise
  assumed external/managed, or reachable at the endpoints
  `configmap.yaml`/`secret.example.yaml` reference.
* No Helm chart, no Terraform/cluster-provisioning code, and no actual
  cloud provider wiring (VPC, managed Postgres instance, DNS) is included —
  these manifests assume a cluster and its supporting infrastructure
  already exist.
