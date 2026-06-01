# Cloud CDN — Setup, Testing & Scripts

This directory contains scripts to set up a full Cloud CDN environment on Google Cloud: firewall rules, instance template, managed instance group, HTTP load balancer, backend service, and a test VM.

---

## Prerequisites

```bash
gcloud services enable compute.googleapis.com
gcloud config set project YOUR_PROJECT_ID
```

You also need a GCS bucket containing the `cdn-website-script.sh` startup script. The setup scripts reference this bucket — update the bucket name in the script before running.

---

## Scripts Overview

| Script | Description |
|--------|-------------|
| [`1-cdn-setup.sh`](./1-cdn-setup.sh) | Full CDN lab setup — well-commented, creates all resources from scratch |
| [`cdn-setup-script.sh`](./cdn-setup-script.sh) | Idempotent version — skips resources that already exist |
| [`cdn-website-script.sh`](./cdn-website-script.sh) | VM startup script: installs Apache, copies static content, sets cache headers |
| [`delete-cdn-script.sh`](./delete-cdn-script.sh) | Tears down all resources created by the setup script |
| [`steps.md`](./steps.md) | Step-by-step guide with performance benchmarks |

---

## Architecture

```
Client → Cloud CDN → HTTP(S) Load Balancer → Backend Service → Managed Instance Group (Apache)
```

Resources created by the setup scripts:
1. **Firewall rules** — allow HTTP (port 80) and health check traffic
2. **Instance template** — `e2-micro`/`e2-medium` with Apache startup script
3. **Managed instance group** — regional (australia-southeast1) with health checks
4. **Health check** — TCP on port 80
5. **Backend service** — rate-based balancing (50 req/instance)
6. **URL map + HTTP proxy + forwarding rule** — global HTTP load balancer
7. **Test VM** — in `us-central1-b` for latency benchmarking

---

## Quick Start

### 1. Upload the Website Script to GCS

```bash
gsutil mb -l us-central1 gs://$DEVSHELL_PROJECT_ID-cdn-scripts
gsutil cp cdn-website-script.sh gs://$DEVSHELL_PROJECT_ID-cdn-scripts/website-script/
```

### 2. Update the Bucket Name in the Setup Script

Edit `1-cdn-setup.sh` or `cdn-setup-script.sh` and set:
```bash
BUCKET_NAME="$DEVSHELL_PROJECT_ID-cdn-scripts"
```

### 3. Run the Setup

```bash
chmod +x 1-cdn-setup.sh
./1-cdn-setup.sh
```

Wait ~5 minutes for the load balancer to initialize.

### 4. Test Without CDN

```bash
LB_IP=$(gcloud compute forwarding-rules describe http-frontend \
    --global --format="value(IPAddress)")

# Benchmark 15 requests
for i in {1..15}; do
  curl -s -w "%{time_total}\n" -o /dev/null http://$LB_IP/index.html
done
```

### 5. Enable Cloud CDN

```bash
gcloud compute backend-services update http-backend --enable-cdn --global
```

Wait 2–5 minutes, then re-run the benchmark. Cache hits should show significantly lower latency.

### 6. Verify Cache Hits

```bash
# Check response headers for cache status
curl -sI http://$LB_IP/index.html | grep -i "x-cache\|age\|cache-control"
```

---

## Expected Performance

| Phase | Typical Response Time |
|-------|-----------------------|
| Without CDN | 100–300 ms (origin fetch) |
| With CDN (cache miss) | 80–200 ms (first request) |
| With CDN (cache hit) | 10–50 ms (edge-served) |

---

## Clean Up

```bash
chmod +x delete-cdn-script.sh
./delete-cdn-script.sh
```

This removes: test instance, forwarding rule, proxy, URL map, backend service, instance group, health check, firewall rules, and instance template.

---

## How the Website Script Works

`cdn-website-script.sh`:
1. Installs Apache on the VM
2. Copies static images from a GCS bucket
3. Sets `Cache-Control: public, max-age=86400` header (24-hour cache)
4. Creates `index.html` and `page-2.html` with embedded images

The `max-age=86400` header tells Cloud CDN to cache responses for 24 hours.

---

## References

- [Cloud CDN overview](https://cloud.google.com/cdn/docs/overview)
- [Setting up Cloud CDN with a backend service](https://cloud.google.com/cdn/docs/setting-up-cdn-with-backend-service)
- [Cache control headers](https://cloud.google.com/cdn/docs/caching)
