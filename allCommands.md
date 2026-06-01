# gcloud Commands — Quick Reference

## IAM
```bash
# Create a service account
gcloud iam service-accounts create instancestorage --display-name="Instance to Storage"

# Create a key for the service account
gcloud iam service-accounts keys create key.json --iam-account=<SVC_ACCOUNT_MAIL_ID>

# Add storage viewer role to the service account
gcloud projects add-iam-policy-binding <PROJECT_ID> \
    --member=serviceAccount:<SVC_ACCOUNT_MAIL_ID> \
    --role=roles/storage.objectViewer

# Set active service account
gcloud config set account <SVC_ACCOUNT_MAIL_ID>

# Authenticate service account with the key
gcloud auth activate-service-account <SVC_ACCOUNT_MAIL_ID> --key-file=key.json

# List all service accounts in project
gcloud iam service-accounts list

# Disable / Delete a service account
gcloud iam service-accounts disable <SVC_ACCOUNT_MAIL_ID>
gcloud iam service-accounts delete <SVC_ACCOUNT_MAIL_ID>
```

## Service Account

```bash
# Create a service account
gcloud iam service-accounts create my-svc-account --display-name="My Service Account"

# Assign a role to the service account
gcloud projects add-iam-policy-binding <PROJECT_ID> \
    --member=serviceAccount:my-svc-account@<PROJECT_ID>.iam.gserviceaccount.com \
    --role=roles/compute.instanceAdmin.v1

# Download a JSON key
gcloud iam service-accounts keys create ~/key.json \
    --iam-account=my-svc-account@<PROJECT_ID>.iam.gserviceaccount.com

# Impersonate a service account
gcloud config set auth/impersonate_service_account my-svc-account@<PROJECT_ID>.iam.gserviceaccount.com
```

## VPC

```bash
# Create a custom-mode VPC
gcloud compute networks create custom-network --subnet-mode=custom

# Create subnets
gcloud compute networks subnets create subnet-a \
    --network=custom-network --region=us-central1 --range=10.2.1.0/24
gcloud compute networks subnets create subnet-b \
    --network=custom-network --region=us-central1 --range=10.2.2.0/24

# List networks and subnets
gcloud compute networks list
gcloud compute networks subnets list --network=custom-network

# Delete a subnet and network
gcloud compute networks subnets delete subnet-a --region=us-central1
gcloud compute networks delete custom-network

# Create a firewall rule (allow SSH from anywhere)
gcloud compute firewall-rules create allow-ssh \
    --network=custom-network --allow=tcp:22 --source-ranges=0.0.0.0/0

# Create a firewall rule targeting a specific tag
gcloud compute firewall-rules create allow-http \
    --network=custom-network --allow=tcp:80 --target-tags=http-server

# List firewall rules
gcloud compute firewall-rules list

# Delete a firewall rule
gcloud compute firewall-rules delete allow-ssh
```

## GCE

```bash
# Create a VM instance
gcloud compute instances create my-vm \
    --zone=us-central1-a \
    --machine-type=e2-medium \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --tags=http-server

# List instances
gcloud compute instances list

# Start / Stop / Delete an instance
gcloud compute instances start my-vm --zone=us-central1-a
gcloud compute instances stop my-vm --zone=us-central1-a
gcloud compute instances delete my-vm --zone=us-central1-a

# SSH into an instance
gcloud compute ssh my-vm --zone=us-central1-a

# Describe instance details
gcloud compute instances describe my-vm --zone=us-central1-a
```

## Disk

```bash
# Create a persistent disk
gcloud compute disks create my-disk \
    --type=pd-standard --size=100GB --zone=us-central1-a

# Attach a disk to an instance
gcloud compute instances attach-disk my-vm \
    --disk=my-disk --zone=us-central1-a

# Resize a disk
gcloud compute disks resize my-disk --size=200GB --zone=us-central1-a

# List disks
gcloud compute disks list

# Delete a disk
gcloud compute disks delete my-disk --zone=us-central1-a
```

## Image

```bash
# List public images (e.g. Debian)
gcloud compute images list --filter="family:debian-11" --no-standard-images=false

# Create a custom image from a disk
gcloud compute images create my-custom-image \
    --source-disk=my-disk --source-disk-zone=us-central1-a

# Create an image from a snapshot
gcloud compute images create my-image-from-snapshot \
    --source-snapshot=my-snapshot

# List custom images
gcloud compute images list --no-standard-images

# Delete an image
gcloud compute images delete my-custom-image

# Deprecate an image
gcloud compute images deprecate my-custom-image --state=DEPRECATED
```

## Bucket (GCS)

```bash
# Create a regional bucket
gsutil mb -c regional -l us-central1 gs://<PROJECT_ID>-my-bucket

# List buckets
gsutil ls

# Copy file to bucket
gsutil cp myfile.txt gs://<PROJECT_ID>-my-bucket/

# List objects in a bucket
gsutil ls gs://<PROJECT_ID>-my-bucket/

# Delete an object
gsutil rm gs://<PROJECT_ID>-my-bucket/myfile.txt

# Delete a bucket (must be empty)
gsutil rb gs://<PROJECT_ID>-my-bucket

# Set bucket-level IAM
gsutil iam ch serviceAccount:<SVC_ACCOUNT>:roles/storage.objectViewer \
    gs://<PROJECT_ID>-my-bucket
```

## Cloud SQL

```bash
# Create a MySQL Cloud SQL instance
gcloud sql instances create my-sql-instance \
    --database-version=MYSQL_8_0 \
    --tier=db-f1-micro \
    --region=us-central1

# Set the root password
gcloud sql users set-password root --host=% \
    --instance=my-sql-instance --password=MySecurePass123

# Create a database
gcloud sql databases create mydb --instance=my-sql-instance

# Create a user
gcloud sql users create myuser --host=% \
    --instance=my-sql-instance --password=UserPass123

# Connect to the instance (Cloud SQL Proxy or gcloud)
gcloud sql connect my-sql-instance --user=root

# List instances
gcloud sql instances list

# Delete an instance
gcloud sql instances delete my-sql-instance
```

## App Engine

```bash
# Initialize App Engine in a region
gcloud app create --region=us-central

# Deploy an application
gcloud app deploy

# View the deployed app
gcloud app browse

# List versions of a service
gcloud app versions list

# Split traffic between versions
gcloud app services set-traffic default \
    --splits v1=0.8,v2=0.2 --split-by=random

# Stop a version
gcloud app versions stop v1

# Delete a version
gcloud app versions delete v1

# View app logs
gcloud app logs tail -s default
```

## Cloud Run

### Deploy a New Service
```bash
gcloud run deploy my-service \
    --image us-central1-docker.pkg.dev/<PROJECT_ID>/my-repo/my-image:v1 \
    --region us-central1 \
    --allow-unauthenticated
```

### Deploy a New Revision Without Sending Traffic
```bash
gcloud run deploy my-service \
    --region us-central1 \
    --image us-central1-docker.pkg.dev/<PROJECT_ID>/my-repo/my-image:v2 \
    --allow-unauthenticated \
    --no-traffic
```

### Split Traffic Between Revisions
```bash
gcloud run services update-traffic my-service \
    --region us-central1 \
    --to-revisions my-service-00001-abc=50,my-service-00002-def=50
```

### Route 100% Traffic to Latest
```bash
gcloud run services update-traffic my-service \
    --region us-central1 \
    --to-latest
```

### List Services
```bash
gcloud run services list --region us-central1
```

### Delete a Service
```bash
gcloud run services delete my-service --region us-central1
```