# Terraform — Google Cloud Platform

This directory contains a Terraform example that provisions a basic GCP network infrastructure: a custom VPC, a subnet, and a firewall rule.

## Resources Created

| Resource | Name | Description |
|----------|------|-------------|
| `google_compute_network` | `terraform-vpc-other` | Auto-mode VPC |
| `google_compute_network` | `terraform-custom-network` | Custom-mode VPC (manual subnets) |
| `google_compute_subnetwork` | `subnet-a` | Subnet in `us-central1` (10.5.0.0/16) |
| `google_compute_firewall` | `terraform-firewall-rules` | Firewall rules for the custom VPC |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.0
- A GCP service account JSON key (`accounts.json`) with at least `Compute Network Admin` role
- A GCP project

## Setup

1. **Place your service account key** in this directory as `accounts.json`.

2. **Create a `terraform.tfvars` file** with your values:
   ```hcl
   project = "your-gcp-project-id"
   region  = "us-central1"
   ```

3. **Initialize Terraform**:
   ```bash
   terraform init
   ```

4. **Review the plan**:
   ```bash
   terraform plan
   ```

5. **Apply**:
   ```bash
   terraform apply
   ```

## Clean Up

```bash
terraform destroy
```

## Notes

- `accounts.json` is in `.gitignore` — never commit credentials to source control.
- The `variables.tf` file (not shown here) should define `project` and `region` variables.
- To use Application Default Credentials instead of a key file, remove the `credentials` line from the provider block and run `gcloud auth application-default login`.
