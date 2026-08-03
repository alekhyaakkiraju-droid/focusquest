# FocusQuest

Gamified focus-timer platform for children aged 6–12, with parent dashboards and COPPA/GDPR-K compliant backend services on Google Cloud Platform.

## Repository layout

```
infrastructure/terraform/   # GCP core infrastructure (WO-001)
```

## Prerequisites

- Terraform >= 1.6
- Google Cloud SDK (`gcloud`) for apply/verify workflows
- Billing-enabled GCP organization access

## Quick start (Terraform)

```bash
cd infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your org_id, project_id, and billing_account

make validate
make test
```

Apply infrastructure (requires elevated GCP permissions):

```bash
terraform init
terraform plan
terraform apply
```

## Work orders

| WO | Scope |
|----|-------|
| WO-001 | GCP project, VPC, Cloud SQL, Redis, Pub/Sub, Storage, KMS, Cloud Armor, VPC Service Controls |
| WO-002 | CI/CD pipelines (depends on WO-001) |

## License

Proprietary — FocusQuest
