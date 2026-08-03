# FocusQuest GCP Core Infrastructure (WO-001)

Terraform modules provisioning dual-region GCP infrastructure for FocusQuest.

## Regions

- `us-central1` — US child PII residency
- `europe-west1` — EU child PII residency

## Modules

| Module | Purpose |
|--------|---------|
| `kms` | Cloud KMS keyrings with 90-day rotation for Cloud SQL CMEK |
| `vpc` | VPC, subnets, private service access |
| `cloudsql` | PostgreSQL 15 HA instances (no public IP, CMEK) |
| `redis` | Memorystore Redis Standard HA with TLS |
| `pubsub` | Inter-service event topics |
| `storage` | Avatar asset buckets (uniform access, CORS, CMEK) |
| `iam` | Per-service least-privilege service accounts |
| `load_balancer` | External HTTP load balancer for API gateway |
| `cloud_armor` | OWASP preconfigured WAF rules |
| `vpc_service_controls` | Access policy and service perimeter |

## Required Pub/Sub topics

- `session-completed`
- `quest-progress`
- `xp-awarded`
- `notification-send`
- `consent-recorded`
- `data-deletion-requested`

## Verification after apply

```bash
gcloud sql instances list
gcloud redis instances list --region=us-central1
gcloud redis instances list --region=europe-west1
gcloud pubsub topics list
gsutil ls
gcloud sql instances describe <instance> --format='value(diskEncryptionConfiguration.kmsKeyName)'
gcloud compute security-policies describe focusquest-staging-owasp-waf
```

## Testing

```bash
make validate   # fmt + init + validate
make test       # configuration contract tests
```
