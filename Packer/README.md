# Packer — Custom GCP Machine Images

This directory contains a [HashiCorp Packer](https://www.packer.io/) template (`packer.json`) that builds a custom GCP Compute Engine image with Apache and a static website pre-installed.

## What Gets Built

- **Base image**: Debian 9 (Stretch)
- **Software installed**: Apache2, Git
- **Static website**: cloned from [`devopswithcloud/static-website`](https://github.com/devopswithcloud/static-website)
- **Output image name**: `packer-website-image-<timestamp>` (in the `my-web-family` image family)

## Prerequisites

- [Packer](https://developer.hashicorp.com/packer/downloads) >= 1.8
- A GCP service account JSON key (`accounts.json`) with:
  - `roles/compute.instanceAdmin.v1`
  - `roles/iam.serviceAccountUser`
- The `accounts.json` file placed in this directory

## Variables

| Variable | Description |
|----------|-------------|
| `machine_type` | GCE machine type for the build instance (e.g., `n1-standard-1`) |
| `project_id` | Your GCP project ID |

Variable values are stored in `packervars.json`.

## Usage

1. **Validate the template**:
   ```bash
   packer validate -var-file=packervars.json packer.json
   ```

2. **Build the image**:
   ```bash
   packer build -var-file=packervars.json packer.json
   ```

3. **Verify the image was created**:
   ```bash
   gcloud compute images list --no-standard-images
   ```

## Using the Custom Image

Once built, use the image when creating a VM:

```bash
gcloud compute instances create my-web-vm \
    --image-family=my-web-family \
    --image-project=YOUR_PROJECT_ID \
    --zone=us-central1-a \
    --machine-type=e2-small \
    --tags=http-server
```

## Notes

- `accounts.json` is sensitive — do not commit it to source control.
- The `packerfile.json` is an alternative Packer HCL2 format template.
- Packer creates a temporary GCE instance, provisions it, then snapshots it into a reusable image.
