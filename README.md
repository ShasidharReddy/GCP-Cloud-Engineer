# Google Cloud Platform — Reference & Lab Notes

A curated collection of GCP command references, scripts, and step-by-step lab guides covering core GCP services. Organized by topic — use this as a quick reference while working on GCP projects.

---

## 📁 Directory Structure

| Directory | Description |
|-----------|-------------|
| [`V2/`](./V2/) | **Latest & recommended** — structured guides for GCE, VPC, IAM, GCS, Cloud SQL, and more |
| [`CDN/`](./CDN/) | Cloud CDN setup scripts and performance testing steps |
| [`Compute/`](./Compute/) | Persistent disk operations (create, attach, resize, format) |
| [`EncryptionKeys/`](./EncryptionKeys/) | CSEK (Customer-Supplied Encryption Key) for GCS buckets |
| [`Examples/`](./Examples/) | Sample applications (Node.js) |
| [`LoadBalancer/`](./LoadBalancer/) | Network LB and HTTP(S) LB setup scripts |
| [`MemoryStore/`](./MemoryStore/) | Redis on GCP (Memorystore) setup guide |
| [`Packer/`](./Packer/) | Packer templates for building custom GCP machine images |
| [`Terraform/`](./Terraform/) | Terraform example for VPC, subnets, and firewall on GCP |
| [`VPC/`](./VPC/) | VPC, subnets, firewall rules, NAT, VPC peering, Shared VPC scripts |

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

`Compute Engine` · `VPC` · `Firewall` · `IAM` · `GCS` · `Cloud SQL` · `Cloud Run` · `Cloud Spanner` · `Cloud CDN` · `MemoryStore (Redis)` · `Terraform` · `Packer` · `VPN` · `Load Balancing` · `Instance Groups` · `Database Migration Service`

---

## 📝 Notes

- Scripts in this repo use placeholder values like `YOUR_PROJECT_ID` and `<SVC_ACCOUNT_MAIL_ID>` — replace them with your actual values before running.
- The `V2/` directory contains the most up-to-date and well-documented guides.
- Scripts are for **learning and reference** purposes — review before running in production.
