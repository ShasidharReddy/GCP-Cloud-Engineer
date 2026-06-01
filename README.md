# Google Cloud Platform — Reference & Lab Notes

A curated collection of GCP command references, scripts, and step-by-step lab guides covering core GCP services. Organized by topic — use this as a quick reference while working on GCP projects.

---

## 📁 Directory Structure

| Directory | Description |
|-----------|-------------|
| [`V2/`](./V2/) | **Latest & recommended** — structured guides for GCE, VPC, IAM, GCS, Cloud SQL, and more |
| [`Architecture/`](./Architecture/) | 🔷 **Visual diagrams** — Mermaid flow diagrams for all major GCP services |
| [`CDN/`](./CDN/) | Cloud CDN setup scripts and performance testing steps |
| [`CloudFunctions/`](./CloudFunctions/) | Cloud Functions (Gen2) — HTTP, Pub/Sub, GCS triggers with Python, Node.js, Go |
| [`CloudSQL/`](./CloudSQL/) | Cloud SQL — MySQL/PostgreSQL with HA, replicas, backups, and connection methods |
| [`Compute/`](./Compute/) | Persistent disk operations (create, attach, resize, format) |
| [`EncryptionKeys/`](./EncryptionKeys/) | CSEK (Customer-Supplied Encryption Key) for GCS buckets |
| [`Examples/`](./Examples/) | Sample applications (Node.js) |
| [`GKE/`](./GKE/) | Google Kubernetes Engine — clusters, node pools, deployments, autoscaling |
| [`LoadBalancer/`](./LoadBalancer/) | Network LB and HTTP(S) LB setup scripts |
| [`MemoryStore/`](./MemoryStore/) | Redis on GCP (Memorystore) setup guide |
| [`Migration/`](./Migration/) | 🔷 **Cloud Migration** — On-Prem, AWS, Azure to GCP migration guides with step-by-step commands |
| [`Packer/`](./Packer/) | Packer templates for building custom GCP machine images |
| [`Terraform/`](./Terraform/) | Terraform example for VPC, subnets, and firewall on GCP |
| [`VPC/`](./VPC/) | VPC, subnets, firewall rules, NAT, VPC peering, Shared VPC scripts |
| [`Networking/`](./Networking/) | 🔷 **GCP Networking** — VPC, Firewall, Cloud NAT, Router, Interconnect, VPN, Shared VPC, DNS |
| [`IAM-Security/`](./IAM-Security/) | 🔷 **IAM & Security** — Resource hierarchy, roles, service accounts, KMS, Secret Manager, VPC Service Controls |
| [`Monitoring/`](./Monitoring/) | 🔷 **Monitoring & Observability** — Cloud Monitoring, Logging, Trace, Error Reporting, Alerting, SLOs |
| [`DataPipeline/`](./DataPipeline/) | 🔷 **Data Pipelines** — Dataflow, Pub/Sub, BigQuery, Cloud Composer, Dataproc, batch vs streaming |
| [`CostOptimization/`](./CostOptimization/) | 🔷 **Cost Optimization** — CUDs, SUDs, Spot VMs, right-sizing, billing, FinOps best practices |
| [`HybridMultiCloud/`](./HybridMultiCloud/) | 🔷 **Hybrid & Multi-Cloud** — Anthos, GKE on-prem, Service Mesh, Config Management, fleet management |
| [`Serverless/`](./Serverless/) | 🔷 **Serverless Patterns** — Cloud Run vs Functions vs App Engine, Eventarc, Workflows, API Gateway |
| [`Database/`](./Database/) | 🔷 **Database Services** — Cloud SQL, AlloyDB, Spanner, Firestore, Bigtable, Memorystore, DMS, decision guide |

---

## 📖 Top-Level Reference Files

| File | Description |
|------|-------------|
| [`GCS.md`](./GCS.md) | `gsutil` command reference for Cloud Storage buckets |
| [`allCommands.md`](./allCommands.md) | Quick-reference `gcloud` commands across IAM, VPC, GCE, GCS, Cloud SQL, App Engine, Cloud Run |
| [`cloudrun.md`](./cloudrun.md) | Cloud Run deployment and traffic management |
| [`cloud_spanner.md`](./cloud_spanner.md) | Cloud Spanner instance, database, and table operations |
| [`database_migration.md`](./database_migration.md) | Step-by-step GCP Database Migration Service (DMS) lab guide |
| [`gcloud_commands.sh`](./gcloud_commands.sh) | General `gcloud` configuration and common commands |
| [`vpn_2_accounts_infra.md`](./vpn_2_accounts_infra.md) | Cloud VPN between two GCP accounts |
| [`vpn_dynamic_ha.md`](./vpn_dynamic_ha.md) | HA VPN (dynamic routing with BGP) setup |

---

## 🚀 Quick Start

### Prerequisites

- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) installed and authenticated
- A GCP project set as the active project:
  ```bash
  gcloud auth login
  gcloud config set project YOUR_PROJECT_ID
  ```

### Recommended Reading Order

1. Start with [`V2/1-CloudComputing/cloud-computing.md`](./V2/1-CloudComputing/cloud-computing.md) for fundamentals
2. Follow [`V2/2-Infrastructure/infra.md`](./V2/2-Infrastructure/infra.md) for infrastructure overview
3. Explore [`V2/Google_Compute_Engine/`](./V2/Google_Compute_Engine/) for hands-on VM management
4. Use the topic directories (CDN, VPC, Terraform, etc.) for specific service guides

---

## 🏷️ Topics Covered

`Compute Engine` · `VPC` · `Firewall` · `IAM` · `GCS` · `Cloud SQL` · `Cloud Run` · `Cloud Spanner` · `Cloud CDN` · `Cloud Functions` · `GKE (Kubernetes)` · `MemoryStore (Redis)` · `Terraform` · `Packer` · `VPN` · `Load Balancing` · `Instance Groups` · `Database Migration Service` · `Networking` · `Security & KMS` · `Monitoring & Logging` · `Dataflow & Pub/Sub` · `BigQuery` · `Cost Optimization` · `Anthos & Hybrid Cloud` · `Serverless Workflows` · `Data Pipelines`

---

## 🔷 Visual Diagrams

This repo includes **Mermaid flow diagrams** that render directly on GitHub — no images needed. See [`Architecture/`](./Architecture/) for:

- GCP global infrastructure (regions, zones, submarine cables, edge network)
- VM lifecycle state diagram
- VPC network architecture with NAT
- HTTP(S) Load Balancer request flow
- GCS storage class lifecycle
- GKE cluster architecture
- Cloud Run auto-scaling sequence
- Cloud SQL HA failover flow
- IAM resource hierarchy
- Database Migration Service flow
- HA VPN between two projects
- GCP services decision tree
- **On-Premises → GCP migration** (VM, DB, data transfer flows)
- **AWS → GCP migration** (EC2, RDS, S3, EKS migration paths)
- **Azure → GCP migration** (VMs, Azure SQL, Blob, AKS migration paths)

### Deep-Dive Guides (with Mermaid diagrams)

- [`Networking/`](./Networking/) — VPC architecture, firewall rules, Cloud NAT, Router, Interconnect, HA VPN, Shared VPC, DNS
- [`IAM-Security/`](./IAM-Security/) — IAM hierarchy, roles & policies, service accounts, Cloud KMS, Secret Manager, VPC Service Controls
- [`Monitoring/`](./Monitoring/) — Cloud Monitoring, Logging, Trace, Error Reporting, alerting policies, SLOs/SLIs, dashboards
- [`DataPipeline/`](./DataPipeline/) — Dataflow, Pub/Sub, BigQuery, Cloud Composer, batch vs streaming, data lake architecture
- [`CostOptimization/`](./CostOptimization/) — CUDs, SUDs, Spot VMs, right-sizing, billing alerts, BigQuery cost control, FinOps
- [`HybridMultiCloud/`](./HybridMultiCloud/) — Anthos, GKE on-prem, Config Management, Service Mesh, fleet management, Distributed Cloud
- [`Serverless/`](./Serverless/) — Cloud Run vs Functions vs App Engine, Eventarc, Workflows, API Gateway, serverless patterns

---

## 📝 Notes

- Scripts in this repo use placeholder values like `YOUR_PROJECT_ID` and `<SVC_ACCOUNT_MAIL_ID>` — replace them with your actual values before running.
- The `V2/` directory contains the most up-to-date and well-documented guides.
- Scripts are for **learning and reference** purposes — review before running in production.
