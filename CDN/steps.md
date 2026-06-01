# Cloud CDN — Setup & Performance Testing

## Step 1: Deploy Your Environment

```bash
./cdn-setup-script.sh
```

> This script creates the GCS bucket, uploads static content, configures the load balancer, and sets up the backend service.

---

## Step 2: Get the Load Balancer IP

After the script completes, retrieve the external IP of the HTTP load balancer:

```bash
gcloud compute forwarding-rules list --global
# OR
gcloud compute addresses list
```

Set it as a variable for use in the commands below:

```bash
LB_IP=$(gcloud compute forwarding-rules describe http-lb-forwarding-rule \
    --global --format="value(IPAddress)")
echo "Load Balancer IP: $LB_IP"
```

---

## Step 3: Test Performance WITHOUT Cloud CDN

SSH into the `testing-instance` and run a latency benchmark:

```bash
# Test connection to index.html (15 requests)
for i in {1..15}; do
  curl -s -w "%{time_total}\n" -o /dev/null http://$LB_IP/index.html
done

# Test connection to page-2.html (15 requests)
for i in {1..15}; do
  curl -s -w "%{time_total}\n" -o /dev/null http://$LB_IP/page-2.html
done
```

Note the average response times — these represent **uncached** (origin) latency.

---

## Step 4: Enable Cloud CDN

Enable CDN on the backend service:

```bash
gcloud compute backend-services update http-lb-backend \
    --enable-cdn \
    --global
```

Wait **2–5 minutes** for CDN to propagate, then re-run the benchmark.

---

## Step 5: Test Performance WITH Cloud CDN

```bash
# Test connection to index.html (15 requests)
for i in {1..15}; do
  curl -s -w "%{time_total}\n" -o /dev/null http://$LB_IP/index.html
done

# Test connection to page-2.html (15 requests)
for i in {1..15}; do
  curl -s -w "%{time_total}\n" -o /dev/null http://$LB_IP/page-2.html
done
```

You should see significantly lower response times — cache hits are served from the CDN edge node closest to the client.

---

## Step 6: Clean Up

```bash
./delete-cdn-script.sh
```

---

## What to Expect

| Phase | Typical Response Time |
|-------|-----------------------|
| Without CDN | 100–300 ms (origin fetch) |
| With CDN (cache miss) | 80–200 ms (first request) |
| With CDN (cache hit) | 10–50 ms (subsequent requests) |