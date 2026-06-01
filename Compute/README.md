# Compute

Purpose: examples and scripts for Google Compute Engine (GCE) resources.

Prerequisites:
- gcloud CLI authenticated (gcloud auth login & gcloud config set project PROJECT_ID)
- Billing enabled on the project

Quick commands:
- Create a disk: gcloud compute disks create my-disk --size=10GB --zone=us-central1-a
- List instances: gcloud compute instances list
- Attach disk: gcloud compute instances attach-disk INSTANCE --disk=my-disk --zone=ZONE

Files:
- disks.md — full examples for disk creation, snapshots, and resizing.

Notes:
- Use labels and IAM roles to manage access and cost tracking.
- Prefer V2/Google_Compute_Engine/ for pushed, tested walkthroughs.
