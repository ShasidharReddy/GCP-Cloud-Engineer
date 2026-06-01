# Compute Engine — Persistent Disks

Persistent disks are durable, high-performance block storage for GCE VM instances. They exist independently from VMs and can be attached, detached, resized, and snapshotted.

> **Docs**: [Adding a persistent disk](https://cloud.google.com/compute/docs/disks/add-persistent-disk)

---

## Prerequisites

```bash
gcloud services enable compute.googleapis.com
gcloud config set project YOUR_PROJECT_ID
```

---

## Disk Types

| Type | API Name | Use Case |
|------|----------|----------|
| Standard | `pd-standard` | Cost-effective, sequential I/O |
| Balanced | `pd-balanced` | General-purpose (SSD-backed) |
| SSD | `pd-ssd` | High IOPS / low latency |
| Extreme | `pd-extreme` | Mission-critical databases |

---

## Create a Disk

```bash
gcloud compute disks create my-disk \
    --type=pd-ssd \
    --size=100GB \
    --zone=us-central1-a
```

## Resize a Disk

```bash
gcloud compute disks resize my-disk \
    --size=200GB \
    --zone=us-central1-a
```

> Disks can only be enlarged, never shrunk.

## Attach a Disk to a VM

```bash
gcloud compute instances attach-disk my-instance \
    --disk=my-disk \
    --zone=us-central1-a
```

## Detach a Disk

```bash
gcloud compute instances detach-disk my-instance \
    --disk=my-disk \
    --zone=us-central1-a
```

## List Disks

```bash
gcloud compute disks list
```

## Delete a Disk

```bash
gcloud compute disks delete my-disk --zone=us-central1-a
```

---

## Format and Mount a New Disk (inside the VM)

After attaching a new disk, SSH into the VM and run:

```bash
# List block devices to find the new disk (e.g., /dev/sdb)
sudo lsblk

# Format the disk with ext4
sudo mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb

# Create a mount point and mount
sudo mkdir -p /mnt/data
sudo mount -o discard,defaults /dev/sdb /mnt/data
```

> **Note**: The device name (`/dev/sdb`, `/dev/sdc`, etc.) depends on how many disks are attached. Always verify with `lsblk`.

---

## Persist the Mount Across Reboots (fstab)

```bash
# Get the UUID of the disk
sudo blkid /dev/sdb
# Output: /dev/sdb: UUID="5992e512-..." TYPE="ext4"

# Add to /etc/fstab (use the UUID from above)
echo 'UUID=5992e512-9d76-4bdf-b592-d5bd96b0ae73 /mnt/data ext4 defaults 0 1' | sudo tee -a /etc/fstab

# Verify fstab is correct (dry run)
sudo mount -a
```

---

## Resize an Existing Boot Disk (inside the VM)

If you enlarged the disk via `gcloud compute disks resize`, the OS partition needs to expand:

```bash
sudo apt install cloud-guest-utils -y

# Grow the partition (partition 1 on /dev/sda)
sudo growpart /dev/sda 1

# Resize the filesystem
sudo resize2fs /dev/sda1
```

> For XFS filesystems, use `sudo xfs_growfs /mnt/data` instead of `resize2fs`.

---

## References

- [Persistent disk overview](https://cloud.google.com/compute/docs/disks)
- [Adding a persistent disk](https://cloud.google.com/compute/docs/disks/add-persistent-disk)
- [Resizing a disk](https://cloud.google.com/compute/docs/disks/resize-persistent-disk)