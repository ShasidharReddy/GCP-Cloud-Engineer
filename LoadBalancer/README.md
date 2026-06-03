# Load Balancer — GCP Load Balancing Scripts

This directory contains startup scripts and static pages for setting up HTTP(S) and Network load balancers on Google Cloud.
<!-- workflow-diagram:start -->
## Load Balancing Workflow
```mermaid
flowchart LR
    Client["Client request"] --> DNS["Cloud DNS / public IP"]
    DNS --> Frontend["Forwarding rule + frontend"]
    Frontend --> Type{"HTTP(S) or TCP/UDP?"}
    subgraph TrafficPath["Traffic path"]
        URLMap["URL map / target proxy"]
        BackendSvc["Backend service"]
        Health["Health checks"]
        Backends["MIG / NEG / instances"]
    end
    Type -->|HTTP(S)| URLMap
    Type -->|TCP/UDP| BackendSvc
    URLMap --> BackendSvc
    BackendSvc --> Health
    Health --> Backends
    Backends --> Result{"Healthy backend available?"}
    Result -->|No| Drain["Fail over or drain traffic"]
    Drain --> Health
    Result -->|Yes| Edge["Optional Cloud CDN / Armor"]
    Edge --> Observe["Latency + error monitoring"]
    Observe --> Tune{"Need routing changes?"}
    Tune -->|Yes| URLMap
    Tune -->|No| Serve["Serve production traffic"]
    classDef start fill:#E3F2FD,stroke:#1E88E5,color:#0D47A1;
    classDef lb fill:#E8F5E9,stroke:#43A047,color:#1B5E20;
    classDef ops fill:#FFF3E0,stroke:#FB8C00,color:#E65100;
    classDef finish fill:#F3E5F5,stroke:#8E24AA,color:#4A148C;
    class Client,DNS,Frontend,Type start;
    class URLMap,BackendSvc,Health,Backends,Edge lb;
    class Result,Drain,Observe,Tune ops;
    class Serve finish;
```
<!-- workflow-diagram:end -->


---

## Prerequisites

```bash
gcloud services enable compute.googleapis.com
gcloud config set project YOUR_PROJECT_ID
```

---

## Directory Structure

```
LoadBalancer/
├── NetworkLB/          # Network (TCP/UDP) Load Balancer — blue/green deployment
│   ├── blue/
│   │   ├── blue.sh     # Startup script: installs Apache + blue page
│   │   └── index.html  # Blue-themed HTML page
│   └── green/
│       ├── green.sh    # Startup script: installs Apache + green page
│       └── index.html  # Green-themed HTML page
├── ver1/               # HTTP LB — Version 1 deployment
│   ├── lb-startup-v1.sh  # Startup script: Apache + PHP + "VERSION 1" page
│   └── index.php         # PHP page showing hostname and region
└── ver2/               # HTTP LB — Version 2 deployment
    ├── lb-startup-v2.sh  # Startup script: Apache + PHP + "VERSION 2" page
    └── index.php         # PHP page showing hostname and region
```

---

## Lab 1: Network Load Balancer (Blue/Green)

Demonstrates a basic Network LB with two backend pools — "blue" and "green" — to visualize traffic routing.

### Step 1: Create the Blue and Green VMs

```bash
# Blue instance
gcloud compute instances create blue-vm \
    --zone=us-central1-a \
    --machine-type=e2-small \
    --tags=http-server \
    --metadata=startup-script-url=https://raw.githubusercontent.com/devopswithcloud/GoogleCloudPlatform/master/LoadBalancer/NetworkLB/blue/blue.sh

# Green instance
gcloud compute instances create green-vm \
    --zone=us-central1-a \
    --machine-type=e2-small \
    --tags=http-server \
    --metadata=startup-script-url=https://raw.githubusercontent.com/devopswithcloud/GoogleCloudPlatform/master/LoadBalancer/NetworkLB/green/green.sh
```

### Step 2: Create a Firewall Rule

```bash
gcloud compute firewall-rules create allow-http \
    --allow=tcp:80 --target-tags=http-server --source-ranges=0.0.0.0/0
```

### Step 3: Create a Target Pool and Forwarding Rule

```bash
# Create target pool with both instances
gcloud compute target-pools create my-pool --region=us-central1
gcloud compute target-pools add-instances my-pool \
    --instances=blue-vm,green-vm --instances-zone=us-central1-a

# Create forwarding rule
gcloud compute forwarding-rules create my-nlb \
    --region=us-central1 --ports=80 --target-pool=my-pool
```

### Step 4: Test

```bash
LB_IP=$(gcloud compute forwarding-rules describe my-nlb \
    --region=us-central1 --format="value(IPAddress)")
for i in {1..10}; do curl -s http://$LB_IP; echo; done
```

You'll see alternating blue and green responses.

---

## Lab 2: HTTP(S) Load Balancer (Version Rollout)

Demonstrates versioned deployments using instance groups with `ver1` and `ver2` startup scripts.

### Step 1: Create Instance Templates

```bash
# Version 1 template
gcloud compute instance-templates create lb-template-v1 \
    --machine-type=e2-small \
    --tags=http-server \
    --metadata=startup-script-url=https://raw.githubusercontent.com/devopswithcloud/GoogleCloudPlatform/master/LoadBalancer/ver1/lb-startup-v1.sh

# Version 2 template
gcloud compute instance-templates create lb-template-v2 \
    --machine-type=e2-small \
    --tags=http-server \
    --metadata=startup-script-url=https://raw.githubusercontent.com/devopswithcloud/GoogleCloudPlatform/master/LoadBalancer/ver2/lb-startup-v2.sh
```

### Step 2: Create Managed Instance Groups

```bash
gcloud compute instance-groups managed create ig-v1 \
    --template=lb-template-v1 --size=2 --zone=us-central1-a

gcloud compute instance-groups managed create ig-v2 \
    --template=lb-template-v2 --size=2 --zone=us-central1-a

# Set named ports
gcloud compute instance-groups managed set-named-ports ig-v1 \
    --named-ports=http:80 --zone=us-central1-a
gcloud compute instance-groups managed set-named-ports ig-v2 \
    --named-ports=http:80 --zone=us-central1-a
```

### Step 3: Create HTTP Load Balancer

```bash
# Health check
gcloud compute health-checks create http my-health-check --port=80

# Backend service
gcloud compute backend-services create my-backend \
    --protocol=HTTP --health-checks=my-health-check --global

# Add v1 backend (100% traffic)
gcloud compute backend-services add-backend my-backend \
    --instance-group=ig-v1 --instance-group-zone=us-central1-a --global

# URL map → proxy → forwarding rule
gcloud compute url-maps create my-lb --default-service=my-backend
gcloud compute target-http-proxies create my-proxy --url-map=my-lb
gcloud compute forwarding-rules create my-http-rule \
    --global --target-http-proxy=my-proxy --ports=80
```

### Step 4: Canary Deploy v2

```bash
# Add v2 as a second backend
gcloud compute backend-services add-backend my-backend \
    --instance-group=ig-v2 --instance-group-zone=us-central1-a --global
```

Requests will now be split between VERSION 1 and VERSION 2 instances.

---

## How the Startup Scripts Work

The `lb-startup-*.sh` scripts:
1. Install Apache + PHP on the VM
2. Download `index.php` from this repository
3. Fetch the VM's zone from the GCE metadata server
4. Replace the `region-here` placeholder in `index.php` with the actual zone

The `index.php` page displays:
- The application version (V1 or V2)
- The server hostname
- The region/zone the instance is running in

---

## Clean Up

```bash
# Delete forwarding rule, proxy, URL map
gcloud compute forwarding-rules delete my-http-rule --global --quiet
gcloud compute target-http-proxies delete my-proxy --quiet
gcloud compute url-maps delete my-lb --quiet

# Delete backend service and health check
gcloud compute backend-services delete my-backend --global --quiet
gcloud compute health-checks delete my-health-check --quiet

# Delete instance groups and templates
gcloud compute instance-groups managed delete ig-v1 --zone=us-central1-a --quiet
gcloud compute instance-groups managed delete ig-v2 --zone=us-central1-a --quiet
gcloud compute instance-templates delete lb-template-v1 lb-template-v2 --quiet
```

---

## References

- [Cloud Load Balancing overview](https://cloud.google.com/load-balancing/docs/load-balancing-overview)
- [Network LB (TCP/UDP)](https://cloud.google.com/load-balancing/docs/network)
- [HTTP(S) LB](https://cloud.google.com/load-balancing/docs/https)
