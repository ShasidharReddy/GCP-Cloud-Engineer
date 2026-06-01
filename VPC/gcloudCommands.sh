#!/usr/bin/env bash
# General gcloud / Cloud Shell reference commands
# Docs: https://cloud.google.com/sdk/docs/quickstarts
#       https://cloud.google.com/sdk/docs/components

# ── Cloud Shell system info ────────────────────────────────────────────────────
lscpu
free -m
lsblk
cat /etc/*release*

# Note: /opt directories in Cloud Shell are ephemeral (lost on shell restart)
mkdir /opt/batch10

# Where is Cloud Shell provisioned? https://www.google.com/about/datacenters/

# ── gcloud SDK basics ─────────────────────────────────────────────────────────
gcloud init
gcloud info
gcloud version
gcloud auth list
gcloud config list

gcloud auth login
gcloud auth revoke

gcloud projects list

# ── Project & configuration ───────────────────────────────────────────────────
# https://cloud.google.com/sdk/gcloud/reference/config/configurations/create
gcloud config list
gcloud config get-value project
gcloud config set project <PROJECT_ID>
gcloud config set compute/zone us-east1
gcloud config unset compute/zone

gcloud config configurations list
gcloud config configurations create prod --no-activate
gcloud config list --configuration dev-data

gcloud components list

# ── Working with APIs ─────────────────────────────────────────────────────────
gcloud services -h
gcloud services list -h
gcloud services list --available
gcloud services list --enabled
gcloud services enable compute.googleapis.com
gcloud services list --available | grep compute

# ── Get current project ID ────────────────────────────────────────────────────
gcloud config get-value project
