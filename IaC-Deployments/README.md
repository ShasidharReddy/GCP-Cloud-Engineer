# IaC Deployments for Google Cloud

This directory contains ten production-oriented Terraform deployment blueprints for common Google Cloud platform patterns. Each project is self-contained with a `main.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars.example`, and a workload-specific `README.md` so that teams can adopt an individual pattern or use the set as a reusable internal catalog.

The configurations favor:
- explicit API enablement with `google_project_service`
- `google` and `google-beta` providers pinned with version constraints
- labels that identify environment, deployment, and Terraform ownership
- secure defaults such as private networking, Cloud Armor, CMEK, or IAM-based access where applicable
- readable Terraform that balances production readiness with learnability

---

## Repository layout

```text
IaC-Deployments/
├── README.md
├── 01-single-vm/
├── 02-multi-region-ha/
├── 03-gke-cluster/
├── 04-vpc-shared-network/
├── 05-cloud-sql-ha/
├── 06-cloud-run-lb/
├── 07-gcs-data-lake/
├── 08-monitoring-stack/
├── 09-landing-zone-base/
└── 10-disaster-recovery/
```

---

## Prerequisites

Before applying any deployment, make sure the operator workstation or CI runner has the following installed and configured:

1. **Terraform** `>= 1.5.0`
2. **gcloud CLI** authenticated to the target organization or project
3. A **Google Cloud project** or organization/folder scope with billing enabled
4. A **Terraform service account** with the roles required by the chosen deployment
5. Optional but recommended: a dedicated **state project** for remote state and CI/CD operations

### Suggested workstation setup

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project MY_PROJECT_ID
terraform version
gcloud version
```

### Suggested Terraform service account baseline

The exact roles vary by project, but a typical automation identity includes a subset of the following:

- `roles/compute.admin`
- `roles/iam.serviceAccountAdmin`
- `roles/iam.serviceAccountUser`
- `roles/storage.admin`
- `roles/container.admin`
- `roles/cloudsql.admin`
- `roles/run.admin`
- `roles/monitoring.editor`
- `roles/logging.configWriter`
- `roles/resourcemanager.projectIamAdmin`
- `roles/serviceusage.serviceUsageAdmin`

For org-level deployments, add organization, folder, billing, and policy permissions as needed.

---

## Authentication patterns

You can authenticate Terraform in any of these production-safe ways:

### Option A: Application Default Credentials

```bash
gcloud auth application-default login
```

### Option B: Service account key file

```bash
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/tf-deployer.json"
```

### Option C: Service account impersonation

```bash
export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT="terraform-deployer@MY_PROJECT_ID.iam.gserviceaccount.com"
```

Service account impersonation is preferred for enterprise environments because it avoids long-lived key material.

---

## Recommended remote state with a GCS backend

Use a dedicated state bucket instead of local state files.

### One-time bucket bootstrap

```bash
gcloud storage buckets create gs://my-tf-state-prod   --project MY_STATE_PROJECT   --location us-central1   --uniform-bucket-level-access

gcloud storage buckets update gs://my-tf-state-prod   --versioning
```

### Example backend configuration

Create a `backend.hcl` file beside the deployment you want to run:

```hcl
bucket = "my-tf-state-prod"
prefix = "iac-deployments/01-single-vm"
```

Then initialize with:

```bash
terraform init -backend-config=backend.hcl
```

### Backend recommendations

- enable versioning on the state bucket
- restrict bucket access to the automation service account
- optionally encrypt with CMEK
- store state in a dedicated admin project
- do not commit `.tfstate` or `.terraform/` artifacts

---

## Usage workflow

The following workflow applies to every project in this directory.

### 1. Clone and switch to the working branch

```bash
git clone <repo-url>
cd GCP-Cloud-Engineer
git checkout feature/iac-terraform-deployments
```

### 2. Choose a deployment

```bash
cd IaC-Deployments/01-single-vm
```

### 3. Prepare variables

```bash
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars
```

Populate project IDs, regions, domain names, notification endpoints, and any environment-specific CIDR ranges.

### 4. Initialize Terraform

```bash
terraform init -backend-config=backend.hcl
```

If you are testing locally without remote state, use:

```bash
terraform init -backend=false
```

### 5. Review the execution plan

```bash
terraform plan -out=tfplan
```

### 6. Apply safely

```bash
terraform apply tfplan
```

### 7. Inspect outputs

```bash
terraform output
```

### 8. Destroy when no longer needed

```bash
terraform destroy
```

---

## Project catalog

| # | Project | Primary use case | Key services |
|---|---|---|---|
| 01 | `single-vm` | Small production workload, bastion, or utility server | Compute Engine, VPC, firewall, persistent disks |
| 02 | `multi-region-ha` | Highly available stateless web tier | MIG, autoscaling, global HTTPS LB, CDN, GCS replication |
| 03 | `gke-cluster` | Secure Kubernetes platform baseline | GKE, private control plane, Workload Identity, Binary Authorization |
| 04 | `vpc-shared-network` | Network hub and spoke landing zone pattern | Shared VPC, subnets, NAT, flow logs, IAM |
| 05 | `cloud-sql-ha` | Managed database platform | Cloud SQL, PSA, Secret Manager, IAM DB auth, replicas |
| 06 | `cloud-run-lb` | Serverless internet-facing app edge | Cloud Run, serverless NEG, HTTPS LB, Cloud Armor |
| 07 | `gcs-data-lake` | Analytics landing zone | GCS, KMS, BigQuery, Dataflow, VPC SC |
| 08 | `monitoring-stack` | Centralized observability and cost alerts | Monitoring, Logging, Pub/Sub, BigQuery, Budgets |
| 09 | `landing-zone-base` | Organization bootstrap | Folders, projects, org policies, Shared VPC |
| 10 | `disaster-recovery` | Regional resilience and failover | MIG, Cloud SQL replica, DNS routing, snapshots, Functions |

---

## What is common across all projects

Every project includes:

- `terraform { required_version }`
- `required_providers` with `google` and `google-beta`
- variables with descriptions and sensible defaults
- outputs for key resource identifiers
- `locals` for names, labels, and repeated structures
- `data` sources such as `google_project`, `google_compute_zones`, or similar
- API enablement via `google_project_service`
- a project README with architecture, resource inventory, usage, cost guidance, and gcloud equivalents

---

## Environment promotion guidance

For real production usage, treat these directories as templates and layer them into your delivery process:

1. keep `*.tfvars` values per environment outside Git
2. use CI/CD with policy checks and peer-reviewed plans
3. separate dev, nonprod, and prod state prefixes
4. pin provider versions and review upgrades deliberately
5. integrate `terraform plan` into pull requests
6. add `terraform validate`, security scans, and policy-as-code gates

---

## Security guidance

- Prefer private networking where possible.
- Replace placeholder domains, emails, and sample IP ranges before apply.
- Use Secret Manager or impersonation for sensitive values.
- Review IAM bindings carefully in shared environments.
- Restrict `allUsers` access unless explicitly intended.
- For org-level patterns, test in a dedicated sandbox first.

---

## Cost guidance

These projects intentionally model production building blocks and can create non-trivial cost. Before applying:

- estimate spend with the Google Cloud pricing calculator
- reduce node counts or replica counts in sandbox environments
- tear down test deployments promptly
- configure budget alerts from project `08-monitoring-stack`

A rough monthly cost estimate is included in each project README, but pricing will vary by region, machine size, traffic, storage usage, and commit discounts.

---

## Validation guidance

Run the following from the repository root after editing any deployment:

```bash
terraform fmt -recursive IaC-Deployments
```

For deeper checks, run per directory:

```bash
cd IaC-Deployments/01-single-vm
terraform init -backend=false
terraform validate
```

Repeat for the target deployment you intend to apply.

---

## Next steps

- Start with `01-single-vm` for a simple baseline.
- Use `04-vpc-shared-network` and `09-landing-zone-base` for platform foundations.
- Use `02`, `03`, `05`, `06`, and `10` for workload patterns.
- Use `07` and `08` to add data and observability capabilities.

These blueprints are designed to be copied, adapted, and standardized for enterprise delivery pipelines.
