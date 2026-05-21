# Enable the compute engine API if not already done

gcloud services enable compute.googleapis.com

# Assign project id to shell variable

export PROJECT_ID=$(gcloud config list --format 'value(core.project)')

# # Create GCS bucket and copy images to bucket - NOT USED

# gsutil mb -l australia-southeast1 gs://$PROJECT_ID-images

# gsutil -m cp -r gs://omega-vector-398906-images/* gs://$PROJECT_ID-images/


# # Make bucket objects public

# gsutil defacl ch -u AllUsers:R gs://$PROJECT_ID-images

# Create firewall rules allowing http and load balancer/health check access

if ! gcloud compute firewall-rules describe http-allow --quiet 2>/dev/null; then
  gcloud compute firewall-rules create http-allow \
    --direction=INGRESS --priority=1000 --network=default \
    --action=ALLOW --rules=tcp:80 --source-ranges=0.0.0.0/0 \
    --target-tags=http-server
else
  echo "Firewall rule http-allow already exists, skipping."
fi

if ! gcloud compute firewall-rules describe health-check-allow --quiet 2>/dev/null; then
  gcloud compute firewall-rules create health-check-allow \
    --direction=INGRESS --priority=1000 --network=default \
    --action=ALLOW --rules=tcp \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 \
    --target-tags=http-server
else
  echo "Firewall rule health-check-allow already exists, skipping."
fi

# Create CDN demo instance template

if ! gcloud compute instance-templates describe cdn-demo-template --quiet 2>/dev/null; then
  gcloud compute instance-templates create cdn-demo-template \
    --machine-type=e2-medium \
    --metadata=startup-script-url=gs://project-fe6816d0-c7fc-4c9b-bd7-cdn-example/website-script/cdn-website-script.sh \
    --tags=http-server \
    --boot-disk-device-name=cdn-demo-template
else
  echo "Instance template cdn-demo-template already exists, skipping."
fi

# Create health check and instance groups from cdn demo template

if ! gcloud compute health-checks describe health-check --quiet 2>/dev/null; then
  gcloud compute health-checks create tcp "health-check" \
    --timeout "5" --check-interval "10" \
    --unhealthy-threshold "3" --healthy-threshold "2" \
    --port "80"
else
  echo "Health check health-check already exists, skipping."
fi

if ! gcloud beta compute instance-groups managed describe australia-southeast1-group --region australia-southeast1 --quiet 2>/dev/null; then
  gcloud beta compute instance-groups managed create australia-southeast1-group \
    --base-instance-name=australia-southeast1-group \
    --template=cdn-demo-template \
    --size=1 \
    --zones=australia-southeast1-a,australia-southeast1-b,australia-southeast1-c \
    --instance-redistribution-type=PROACTIVE \
    --health-check=health-check \
    --initial-delay=300
else
  echo "Instance group australia-southeast1-group already exists, skipping."
fi

# Set up HTTP Load Balancer
# Set named ports for instance groups

gcloud compute instance-groups managed set-named-ports australia-southeast1-group \
    --named-ports http:80 \
    --region australia-southeast1

# Create backend service and add backends

if ! gcloud compute backend-services describe http-backend --global --quiet 2>/dev/null; then
  gcloud compute backend-services create http-backend \
    --protocol HTTP \
    --health-checks health-check \
    --global

  gcloud compute backend-services add-backend http-backend \
    --balancing-mode=RATE \
    --max-rate-per-instance=50 \
    --capacity-scaler=1 \
    --instance-group=australia-southeast1-group \
    --instance-group-region=australia-southeast1 \
    --global
else
  echo "Backend service http-backend already exists, skipping."
fi

# Create load balancer

if ! gcloud compute url-maps describe http-lb --quiet 2>/dev/null; then
  gcloud compute url-maps create http-lb \
    --default-service http-backend
else
  echo "URL map http-lb already exists, skipping."
fi

if ! gcloud compute target-http-proxies describe http-lb-proxy --quiet 2>/dev/null; then
  gcloud compute target-http-proxies create http-lb-proxy \
    --url-map=http-lb
else
  echo "Target HTTP proxy http-lb-proxy already exists, skipping."
fi

if ! gcloud compute forwarding-rules describe http-frontend --global --quiet 2>/dev/null; then
  gcloud compute forwarding-rules create http-frontend \
    --global \
    --target-http-proxy=http-lb-proxy \
    --ports=80
else
  echo "Forwarding rule http-frontend already exists, skipping."
fi

# Create testing instance in us-central1 region

if ! gcloud compute instances describe testing-instance --zone us-central1-b --quiet 2>/dev/null; then
  gcloud compute instances create testing-instance \
    --zone us-central1-b \
    --machine-type e2-medium
else
  echo "Instance testing-instance already exists, skipping."
fi

# Get frontend IP address and assign it to a shell variable

for FRONTEND in $(gcloud compute forwarding-rules describe http-frontend --format="get(IPAddress)" --global)
do
  gcloud compute forwarding-rules describe http-frontend --format="get(IPAddress)" --global
done

clear

echo "-------------------------------"
echo "Script complete, wait about 5 minutes for your load balancer to initialize, then access frontend address in a new tab"
echo "Your load balancer frontend IP address is $FRONTEND"
echo "If you receive an error for the website, wait a few more minutes and try again"
echo "-------------------------------"
