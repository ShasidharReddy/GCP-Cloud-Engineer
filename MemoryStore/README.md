# Memorystore (Redis) — GCP Managed Redis

Google Cloud Memorystore provides fully managed Redis and Memcached instances for sub-millisecond data access.

<!-- workflow-diagram:start -->
## Memorystore Setup Workflow
```mermaid
flowchart LR
    Need["Need low-latency cache"] --> Choose{"Redis or Memcached?"}
    Choose -->|Redis| Tier["Select basic or HA tier"]
    Choose -->|Memcached| Tier
    subgraph Provision["Provision cache"]
        Network["Choose VPC + region"]
        Size["Set memory size"]
        Auth["Define auth / access path"]
    end
    Tier --> Network
    Network --> Size
    Size --> Auth
    Auth --> Connect["App connects from GCE / GKE / serverless"]
    Connect --> Data{"TTL and eviction right-sized?"}
    Data -->|No| Tune["Adjust keys, TTL, and client pattern"]
    Tune --> Connect
    Data -->|Yes| Observe["Monitor CPU, memory, ops/sec"]
    Observe --> Scale{"Need scale or failover change?"}
    Scale -->|Yes| Resize["Resize instance / improve HA"]
    Resize --> Observe
    Scale -->|No| Serve["Sustain cache performance"]
    classDef start fill:#E3F2FD,stroke:#1E88E5,color:#0D47A1;
    classDef cache fill:#E8F5E9,stroke:#43A047,color:#1B5E20;
    classDef ops fill:#FFF3E0,stroke:#FB8C00,color:#E65100;
    classDef finish fill:#F3E5F5,stroke:#8E24AA,color:#4A148C;
    class Need,Choose,Tier start;
    class Network,Size,Auth,Connect cache;
    class Data,Tune,Observe,Scale,Resize ops;
    class Serve finish;
```
<!-- workflow-diagram:end -->

## Files

| File | Description |
|------|-------------|
| [`MemoryStoreCommands.md`](./MemoryStoreCommands.md) | Redis CLI commands and Memorystore setup guide |

## Quick Start

```bash
# Create a Memorystore Redis instance
gcloud redis instances create my-redis \
  --size=1 \
  --region=us-central1 \
  --redis-version=redis_7_0

# Get instance details
gcloud redis instances describe my-redis --region=us-central1
```

## References

- [Memorystore for Redis Documentation](https://cloud.google.com/memorystore/docs/redis)
- [Connecting from GKE](https://cloud.google.com/memorystore/docs/redis/connect-redis-instance-gke)
