# Compute Engine — Reference Guides

This directory contains reference documentation for Google Compute Engine disk operations.

## Files

| File | Description |
|------|-------------|
| [`disks.md`](./disks.md) | Persistent disk operations: create, attach, resize, format, mount, and fstab persistence |

## Quick Reference

```bash
# Create a VM
gcloud compute instances create my-vm \
    --zone=us-central1-a \
    --machine-type=e2-medium \
    --image-family=debian-11 \
    --image-project=debian-cloud

# Create and attach a disk
gcloud compute disks create my-disk --type=pd-ssd --size=100GB --zone=us-central1-a
gcloud compute instances attach-disk my-vm --disk=my-disk --zone=us-central1-a

# SSH into the VM
gcloud compute ssh my-vm --zone=us-central1-a
```

For detailed disk operations (formatting, mounting, fstab), see [`disks.md`](./disks.md).

For comprehensive GCE guides including startup scripts, images, snapshots, instance groups, and load balancers, see the [`V2/Google_Compute_Engine/`](../V2/Google_Compute_Engine/) directory.
