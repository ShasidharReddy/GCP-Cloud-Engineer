# MemoryStore

Purpose: commands and examples to provision and use Memorystore (Redis).

Files:
- MemoryStoreCommands.md — step-by-step gcloud and redis-cli commands

Quick example:
- Create Redis instance: gcloud redis instances create my-redis --size=1 --region=us-central1 --tier=STANDARD_HA
- Connect from Compute VM (private IP): redis-cli -h REDIS_IP -p 6379

Cost and sizing:
- Start small (low-memory instance) for dev/testing; monitor metrics before scaling.
- Use AUTH and VPC firewall rules to secure access.
