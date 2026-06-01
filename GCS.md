# Google Cloud Storage (GCS) — gsutil Command Reference

## gsutil Command Structure

```bash
gsutil <command> <options>
gsutil <command> <options> <source> <target>
```

---

## Bucket Operations

### Create a Multi-Regional Bucket
```bash
gsutil mb -c MULTI_REGIONAL -l asia gs://YOUR_PROJECT_ID-multi
gsutil mb -l asia gs://$DEVSHELL_PROJECT_ID-multi-new
```

### Create a Regional Bucket
```bash
gsutil mb -c regional -l us-central1 gs://$DEVSHELL_PROJECT_ID-regional
```

### Create a Nearline Bucket (infrequent access, min 30-day storage)
```bash
gsutil mb -c nearline -l asia gs://$DEVSHELL_PROJECT_ID-nearline-multi-regional
```

### Create a Coldline Bucket (archival, min 90-day storage)
```bash
gsutil mb -c coldline -l us-central1 gs://$DEVSHELL_PROJECT_ID-coldline
```

### Create an Archive Bucket (long-term archival, min 365-day storage)
```bash
gsutil mb -c archive -l us-central1 gs://$DEVSHELL_PROJECT_ID-archive
```

### List All Buckets
```bash
gsutil ls
```

### Remove a Bucket (must be empty)
```bash
gsutil rb gs://$DEVSHELL_PROJECT_ID-multi-new
```

---

## Object Operations

### Copy a Local File to a Bucket
```bash
gsutil cp logfile0603.txt gs://YOUR_BUCKET_NAME/
```

### Copy an Object from Bucket to Local
```bash
gsutil cp gs://YOUR_BUCKET_NAME/logfile0603.txt .
```

### Copy Objects Between Buckets
```bash
gsutil cp gs://SOURCE_BUCKET/logfile0603.txt gs://DEST_BUCKET/
```

### List Objects in a Bucket
```bash
gsutil ls gs://YOUR_BUCKET_NAME/
```

### Delete an Object
```bash
gsutil rm gs://YOUR_BUCKET_NAME/logfile0603.txt
```

### Synchronize a Local Directory to a Bucket
```bash
gsutil rsync -r ./local-folder gs://YOUR_BUCKET_NAME/
```

---

## IAM & Service Account for GCS Access

### Create a Service Account
```bash
gcloud iam service-accounts create instancestorage \
    --display-name="Instance to Storage"
```

### Create a Key for the Service Account
```bash
gcloud iam service-accounts keys create key.json \
    --iam-account=instancestorage@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

### Grant Storage Viewer Role to the Service Account
```bash
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member=serviceAccount:instancestorage@YOUR_PROJECT_ID.iam.gserviceaccount.com \
    --role=roles/storage.objectViewer
```

### Activate the Service Account
```bash
gcloud auth activate-service-account \
    instancestorage@YOUR_PROJECT_ID.iam.gserviceaccount.com \
    --key-file=key.json
```

### Verify Access
```bash
gsutil ls
gsutil ls gs://YOUR_BUCKET_NAME/
```

---

## Storage Classes Reference

| Class | Use Case | Min Storage Duration | Retrieval Cost |
|-------|----------|---------------------|----------------|
| Standard | Frequently accessed data | None | None |
| Nearline | Access < once/month | 30 days | Yes |
| Coldline | Access < once/quarter | 90 days | Yes |
| Archive | Rarely accessed (<once/year) | 365 days | Yes | 
