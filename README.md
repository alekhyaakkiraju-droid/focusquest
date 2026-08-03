# FocusQuest

Gamified focus-timer platform for children aged 6–12, with parent dashboards and COPPA/GDPR-K compliant backend services on Google Cloud Platform.

## Repository layout

```
services/                   # Backend microservices (Go, Cloud Run)
  auth-service/
  timer-service/
  quest-service/
  notification-service/
  compliance-service/
  analytics-service/
apps/
  flutter-app/              # Mobile app (Flutter)
  parent-dashboard/         # Parent SPA (React + Vite)
ci/                         # Shared CI policy scripts and tests
.github/workflows/          # GitHub Actions pipelines
infrastructure/terraform/   # GCP core infrastructure (WO-001)
```

## Prerequisites

- Terraform >= 1.6 and Google Cloud SDK (`gcloud`) for infrastructure
- Go >= 1.22 for backend services
- Node.js >= 20 for the parent dashboard
- Flutter stable channel for the mobile app
- Docker for local container builds

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

## CI/CD (WO-002)

Each deployable unit has a `cloudbuild.yaml` that runs policy checks, tests, security scanning, and staging deployment:

| Unit | Pipeline | Staging target |
|------|----------|----------------|
| 6 backend services | `services/*/cloudbuild.yaml` | Cloud Run (`*-staging`) |
| Flutter app | `apps/flutter-app/cloudbuild.yaml` | GCS artifact bucket (APK/AAB/IPA) |
| Parent dashboard | `apps/parent-dashboard/cloudbuild.yaml` | GCS + CDN cache invalidation |

GitHub Actions mirror the same checks on pull requests and merges to `main`:

- `.github/workflows/security-checks.yml` — npm package/sensitive file policy, npm audit, Trivy
- `.github/workflows/backend-ci.yml` — matrix build/test for all 6 Go services
- `.github/workflows/flutter-ci.yml` — analyze, test, Android builds
- `.github/workflows/dashboard-ci.yml` — test, audit, production bundle build

Run local CI policy and contract tests:

```bash
bash ci/tests/run_all_tests.sh
bash ci/tests/cloudbuild_config_test.sh
```

Run service tests locally:

```bash
# Backend
for svc in services/*; do (cd "$svc" && go test ./...); done

# Dashboard
cd apps/parent-dashboard && npm ci && npm test && npm run build

# Flutter (requires Flutter SDK)
cd apps/flutter-app && flutter pub get && flutter test
```

## Work orders

| WO | Scope | Status |
|----|-------|--------|
| WO-001 | GCP project, VPC, Cloud SQL, Redis, Pub/Sub, Storage, KMS, Cloud Armor, VPC Service Controls | Complete |
| WO-002 | CI/CD pipelines for 6 backend services, Flutter app, and React parent dashboard | In progress |
| WO-003 | Observability stack (logging, tracing, monitoring) | Planned |

## License

Proprietary — FocusQuest
