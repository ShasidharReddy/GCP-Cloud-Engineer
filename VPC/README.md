# VPC

Purpose: helper scripts for common VPC networking tasks.

Prerequisites:
- gcloud installed and authenticated
- Appropriate IAM roles (Network Admin or custom role)

Common scripts and what they do:
- vpc.sh — create a VPC and subnet with example CIDR
- nat.sh — configure Cloud NAT for private instances
- vpcPeering.sh — set up VPC peering between projects/VPCs
- sharedvpc.sh — attach service projects to a Shared VPC host
- firewall.sh — example firewall rules for common services
- gcloudCommands.sh — assorted gcloud snippets

Quick example: create a VPC (from vpc.sh)
- chmod +x VPC/vpc.sh && ./VPC/vpc.sh PROJECT_ID us-central1

Notes:
- Test peering and NAT in a sandbox project before production.
- Consult V2/4-VPC for detailed design patterns and examples.
