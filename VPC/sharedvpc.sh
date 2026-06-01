#!/usr/bin/env bash
# Shared VPC lab: Create host-network with dev, prod, and private subnets
# Prerequisites: 3 projects — dev-shared-project, prod-shared-project, host-shared-project

# Create the host-network VPC
gcloud compute networks create host-network --subnet-mode=custom
echo "********* Host-network created successfully *******"

# Create dev subnet
gcloud compute networks subnets create dev-subnet --range=10.0.2.0/24 \
    --network=host-network --region=us-central1
echo "********* Dev Subnet Created Successfully ********"

# Create private subnet
gcloud compute networks subnets create private-subnet --range=10.0.3.0/24 \
    --network=host-network --region=us-central1
echo "********* Private Subnet Created Successfully ********"

# Create prod subnet
gcloud compute networks subnets create prod-subnet --range=10.0.1.0/24 \
    --network=host-network --region=us-central1
echo "********* Prod Subnet Created Successfully ********"