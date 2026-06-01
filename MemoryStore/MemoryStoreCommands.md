# MemoryStore (Redis) — Setup & Application Guide

Google Cloud Memorystore provides a fully managed Redis instance. This guide covers creating a Memorystore instance and connecting a Python application from a GCE VM.

---

## Prerequisites

- A GCP project with billing enabled
- Compute Engine API enabled
- A GCE VM instance in the **same region** as the Memorystore instance (Memorystore is not accessible from the public internet)

```bash
gcloud services enable redis.googleapis.com
gcloud services enable compute.googleapis.com
```

---

## Step 1: Create a Memorystore (Redis) Instance

```bash
gcloud redis instances create my-redis \
    --size=1 \
    --region=us-central1 \
    --redis-version=redis_7_0 \
    --tier=basic
```

### Get the Redis Instance IP

```bash
gcloud redis instances describe my-redis --region=us-central1 \
    --format="value(host)"
```

Save this IP — you'll need it to connect from your VM.

---

## Step 2: Create a GCE VM (same region)

```bash
gcloud compute instances create redis-client-vm \
    --zone=us-central1-a \
    --machine-type=e2-medium \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud
```

---

## Step 3: SSH and Install Dependencies

```bash
gcloud compute ssh redis-client-vm --zone=us-central1-a
```

Inside the VM:

```bash
sudo apt-get update
sudo apt-get install -y build-essential python3-dev python3-pip \
    libncurses5-dev virtualenv redis-tools
```

---

## Step 4: Test Redis Connectivity

```bash
# Replace REDIS_IP with the IP from Step 1
redis-cli -h REDIS_IP ping
# Expected output: PONG
```

---

## Step 5: Run a Sample Python Application

```bash
# Create and activate a virtual environment
virtualenv env
source env/bin/activate

# Clone the sample app
git clone https://github.com/infinite-Joy/retwis-py.git
cd retwis-py

# Install dependencies
pip install -r requirements.txt

# Set the Redis host and run
export REDIS_HOST=REDIS_IP
python app.py
```

---

## Quick Commands Reference

| Action | Command |
|--------|---------|
| List instances | `gcloud redis instances list --region=us-central1` |
| Describe instance | `gcloud redis instances describe my-redis --region=us-central1` |
| Delete instance | `gcloud redis instances delete my-redis --region=us-central1` |
| Scale up | `gcloud redis instances update my-redis --region=us-central1 --size=5` |

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Basic tier** | Single node, no replication (dev/test) |
| **Standard tier** | Automatic failover with replica (production) |
| **VPC access** | Redis is only reachable from VMs in the same VPC/region |
| **No public IP** | Memorystore does not have a public endpoint — use VPN or VPC peering for external access |

---

## References

- [Memorystore for Redis documentation](https://cloud.google.com/memorystore/docs/redis)
- [Connecting from a GCE VM](https://cloud.google.com/memorystore/docs/redis/connect-redis-instance-gce)