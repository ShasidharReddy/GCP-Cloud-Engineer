# GCP Architecture & Flow Diagrams

Visual reference diagrams for Google Cloud Platform services. All diagrams use [Mermaid](https://mermaid.js.org/) syntax and render natively on GitHub.

---

## 🌐 GCP Global Infrastructure

```mermaid
graph TB
    subgraph "Google Cloud Platform"
        subgraph "Region: us-central1"
            Z1["Zone: us-central1-a"]
            Z2["Zone: us-central1-b"]
            Z3["Zone: us-central1-c"]
        end
        subgraph "Region: us-east1"
            Z4["Zone: us-east1-b"]
            Z5["Zone: us-east1-c"]
        end
        subgraph "Region: asia-south1"
            Z6["Zone: asia-south1-a"]
            Z7["Zone: asia-south1-b"]
        end
    end

    style Z1 fill:#4285F4,color:#fff
    style Z2 fill:#4285F4,color:#fff
    style Z3 fill:#4285F4,color:#fff
    style Z4 fill:#34A853,color:#fff
    style Z5 fill:#34A853,color:#fff
    style Z6 fill:#FBBC04,color:#000
    style Z7 fill:#FBBC04,color:#000
```

---

## 🖥️ Compute Engine — VM Lifecycle

```mermaid
stateDiagram-v2
    [*] --> PROVISIONING: gcloud compute instances create
    PROVISIONING --> STAGING: Resources allocated
    STAGING --> RUNNING: VM boots
    RUNNING --> SUSPENDED: gcloud compute instances suspend
    SUSPENDED --> RUNNING: gcloud compute instances resume
    RUNNING --> STOPPED: gcloud compute instances stop
    STOPPED --> RUNNING: gcloud compute instances start
    RUNNING --> TERMINATED: gcloud compute instances delete
    STOPPED --> TERMINATED: gcloud compute instances delete
    TERMINATED --> [*]
```

---

## 🌐 VPC Network Architecture

```mermaid
graph TB
    Internet((Internet))
    
    subgraph "VPC: my-custom-network"
        subgraph "Region: us-central1"
            subgraph "Subnet-A: 10.0.1.0/24"
                VM1["instance-1a<br/>10.0.1.2<br/>External IP"]
                VM2["instance-1b<br/>10.0.1.3<br/>No External IP"]
            end
            subgraph "Subnet-B: 10.0.2.0/24"
                VM3["instance-2<br/>10.0.2.2<br/>External IP"]
            end
            NAT["Cloud NAT"]
        end
        FW["Firewall Rules"]
    end
    
    Internet -->|"Allow TCP:22<br/>(SSH)"| FW
    FW --> VM1
    FW --> VM3
    VM2 -->|"Outbound via"| NAT
    NAT --> Internet

    style Internet fill:#EA4335,color:#fff
    style NAT fill:#4285F4,color:#fff
    style FW fill:#FBBC04,color:#000
```

---

## ⚖️ HTTP(S) Load Balancer Flow

```mermaid
graph LR
    Client((Client)) --> GFE["Global Frontend<br/>(Forwarding Rule)"]
    GFE --> Proxy["HTTP(S) Proxy"]
    Proxy --> URLMap["URL Map"]
    URLMap -->|"/*"| BS["Backend Service"]
    BS --> HC{"Health Check<br/>TCP:80"}
    BS --> IG1["Instance Group<br/>us-central1<br/>(v1)"]
    BS --> IG2["Instance Group<br/>us-east1<br/>(v2)"]
    HC -.->|"monitor"| IG1
    HC -.->|"monitor"| IG2
    
    subgraph CDN["Cloud CDN"]
        Cache["Edge Cache"]
    end
    
    GFE -.->|"cache hit"| Cache
    Cache -.->|"serve cached"| Client

    style Client fill:#EA4335,color:#fff
    style CDN fill:#34A853,color:#fff
    style Cache fill:#34A853,color:#fff
    style GFE fill:#4285F4,color:#fff
```

---

## 🪣 Cloud Storage — Storage Classes Flow

```mermaid
graph LR
    Upload["Upload Object"] --> Standard["Standard<br/>Frequent Access<br/>No min duration"]
    Standard -->|"Lifecycle Rule<br/>after 30 days"| Nearline["Nearline<br/>< 1x/month<br/>30-day min"]
    Nearline -->|"Lifecycle Rule<br/>after 90 days"| Coldline["Coldline<br/>< 1x/quarter<br/>90-day min"]
    Coldline -->|"Lifecycle Rule<br/>after 365 days"| Archive["Archive<br/>< 1x/year<br/>365-day min"]
    Archive -->|"Lifecycle Rule"| Delete["Delete"]

    style Standard fill:#4285F4,color:#fff
    style Nearline fill:#34A853,color:#fff
    style Coldline fill:#FBBC04,color:#000
    style Archive fill:#EA4335,color:#fff
    style Delete fill:#999,color:#fff
```

---

## 🐳 GKE Cluster Architecture

```mermaid
graph TB
    subgraph "GKE Cluster"
        CP["Control Plane<br/>(Managed by Google)"]
        
        subgraph "Node Pool: default"
            N1["Node 1"]
            N2["Node 2"]
            N3["Node 3"]
        end
        
        subgraph "Workloads"
            P1["Pod: frontend<br/>nginx:latest"]
            P2["Pod: backend<br/>app:v2"]
            P3["Pod: backend<br/>app:v2"]
            P4["Pod: worker<br/>worker:v1"]
        end
    end
    
    CP -->|"schedules"| N1
    CP -->|"schedules"| N2
    CP -->|"schedules"| N3
    N1 --> P1
    N1 --> P2
    N2 --> P3
    N3 --> P4
    
    LB["Load Balancer<br/>(Service type: LoadBalancer)"]
    LB --> P1
    
    Ingress["Ingress Controller"]
    Ingress -->|"/api/*"| P2
    Ingress -->|"/api/*"| P3
    Ingress -->|"/"| P1
    
    Client((Client)) --> Ingress

    style CP fill:#4285F4,color:#fff
    style Client fill:#EA4335,color:#fff
    style LB fill:#34A853,color:#fff
```

---

## 🚀 Cloud Run Request Flow

```mermaid
sequenceDiagram
    participant Client
    participant LB as Load Balancer
    participant CR as Cloud Run
    participant C1 as Container 1
    participant C2 as Container 2
    
    Note over CR: min-instances=0 (scale to zero)
    Client->>LB: HTTPS Request
    LB->>CR: Route to service
    
    alt No running containers (cold start)
        CR->>C1: Start new container (~1-2s)
        C1-->>CR: Ready
        CR->>C1: Forward request
    else Container available
        CR->>C1: Forward request (warm)
    end
    
    C1-->>Client: Response
    
    Note over Client: High traffic burst
    Client->>LB: 100 concurrent requests
    LB->>CR: Route requests
    CR->>C2: Auto-scale: start container 2
    CR->>C1: 50 requests (concurrency=80)
    CR->>C2: 50 requests
    
    Note over CR: After idle period
    CR->>C1: Scale down
    CR->>C2: Scale down
    Note over CR: Back to 0 instances
```

---

## 🗄️ Cloud SQL — HA Architecture

```mermaid
graph TB
    App["Application"] --> Proxy["Cloud SQL Proxy<br/>(sidecar or standalone)"]
    Proxy -->|"Encrypted"| Primary["Primary Instance<br/>us-central1-a"]
    Primary -->|"Synchronous<br/>Replication"| Standby["Standby Instance<br/>us-central1-b"]
    Primary -->|"Async<br/>Read Replica"| Replica["Read Replica<br/>us-east1-b"]
    
    App2["Analytics App"] --> Replica
    
    Primary -->|"Automated Backup<br/>Daily + On-demand"| Backup["Backups<br/>(7-day retention)"]
    
    subgraph "Failover (automatic)"
        Primary -.->|"If primary fails"| Standby
        Standby -.->|"Promotes to primary"| Primary
    end

    style Primary fill:#4285F4,color:#fff
    style Standby fill:#34A853,color:#fff
    style Replica fill:#FBBC04,color:#000
    style Proxy fill:#EA4335,color:#fff
```

---

## 🔐 IAM — Resource Hierarchy

```mermaid
graph TD
    Org["Organization<br/>example.com"] --> F1["Folder: Engineering"]
    Org --> F2["Folder: Finance"]
    F1 --> P1["Project: dev-app"]
    F1 --> P2["Project: prod-app"]
    F2 --> P3["Project: billing-reports"]
    
    P1 --> R1["GCE VMs"]
    P1 --> R2["GCS Buckets"]
    P2 --> R3["GKE Clusters"]
    P2 --> R4["Cloud SQL"]
    
    IAM1["IAM Policy<br/>roles/owner"] -.->|"Inherited by all children"| Org
    IAM2["IAM Policy<br/>roles/editor"] -.->|"Inherited by projects"| F1
    IAM3["IAM Policy<br/>roles/viewer"] -.->|"Project-level only"| P1

    style Org fill:#EA4335,color:#fff
    style F1 fill:#FBBC04,color:#000
    style F2 fill:#FBBC04,color:#000
    style P1 fill:#4285F4,color:#fff
    style P2 fill:#4285F4,color:#fff
    style P3 fill:#4285F4,color:#fff
```

---

## 🔄 Database Migration Service (DMS) Flow

```mermaid
sequenceDiagram
    participant Source as Source MySQL<br/>(GCE VM)
    participant DMS as Database Migration<br/>Service
    participant Target as Cloud SQL<br/>(Destination)
    
    Note over Source: Step 1: Prepare source
    Source->>Source: Enable binary logging
    Source->>Source: Create replication user
    
    Note over DMS: Step 2: Create migration job
    DMS->>Source: Connect & validate
    DMS->>Target: Create destination instance
    
    Note over DMS: Step 3: Full dump
    DMS->>Source: Read all tables
    DMS->>Target: Write initial data
    
    Note over DMS: Step 4: CDC (Change Data Capture)
    loop Continuous replication
        Source->>DMS: Binary log events
        DMS->>Target: Apply changes
    end
    
    Note over Target: Step 5: Promote
    DMS->>Target: Stop replication
    DMS->>Target: Promote to primary
    Note over Target: Cloud SQL is now primary!
```

---

## 🌍 VPN — HA VPN Between Two Projects

```mermaid
graph LR
    subgraph "Project A"
        VPC_A["VPC: network-1<br/>10.0.1.0/24"]
        GW_A["HA VPN Gateway"]
        Router_A["Cloud Router<br/>(BGP ASN: 65001)"]
        VM_A["VM: instance-1"]
    end
    
    subgraph "Project B"
        VPC_B["VPC: network-2<br/>10.1.3.0/24"]
        GW_B["HA VPN Gateway"]
        Router_B["Cloud Router<br/>(BGP ASN: 65002)"]
        VM_B["VM: instance-2"]
    end
    
    VM_A --> VPC_A
    VPC_A --> Router_A
    Router_A --> GW_A
    GW_A <-->|"IPsec Tunnel 0<br/>Interface 0"| GW_B
    GW_A <-->|"IPsec Tunnel 1<br/>Interface 1"| GW_B
    GW_B --> Router_B
    Router_B --> VPC_B
    VPC_B --> VM_B
    
    Router_A <-.->|"BGP Sessions<br/>Dynamic Routing"| Router_B

    style GW_A fill:#4285F4,color:#fff
    style GW_B fill:#34A853,color:#fff
```

---

## 📋 GCP Services Decision Tree

```mermaid
graph TD
    Start{{"I need to run<br/>an application"}}
    
    Start -->|"Containers"| Q1{"Need full<br/>orchestration?"}
    Start -->|"VMs"| GCE["Compute Engine"]
    Start -->|"Serverless"| Q2{"Event-driven<br/>or HTTP?"}
    Start -->|"Static website"| GCS["Cloud Storage<br/>+ Cloud CDN"]
    
    Q1 -->|"Yes"| GKE["GKE<br/>(Kubernetes)"]
    Q1 -->|"No, just run<br/>a container"| CR["Cloud Run"]
    
    Q2 -->|"HTTP service"| CR
    Q2 -->|"Event/trigger"| CF["Cloud Functions"]
    Q2 -->|"PaaS (deploy code)"| GAE["App Engine"]
    
    Start -->|"I need a<br/>database"| Q3{"What type?"}
    Q3 -->|"Relational"| Q4{"Global scale?"}
    Q3 -->|"NoSQL/Document"| Firestore["Firestore"]
    Q3 -->|"Key-Value cache"| Redis["Memorystore<br/>(Redis)"]
    Q3 -->|"Wide-column"| BigTable["Cloud Bigtable"]
    Q3 -->|"Analytics"| BQ["BigQuery"]
    
    Q4 -->|"Yes"| Spanner["Cloud Spanner"]
    Q4 -->|"No"| CloudSQL["Cloud SQL"]

    style Start fill:#EA4335,color:#fff
    style GKE fill:#4285F4,color:#fff
    style CR fill:#4285F4,color:#fff
    style CF fill:#4285F4,color:#fff
    style GCE fill:#4285F4,color:#fff
    style Spanner fill:#34A853,color:#fff
    style CloudSQL fill:#34A853,color:#fff
```
