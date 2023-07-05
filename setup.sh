#!/bin/bash

PROJECT_ID=$1
PROJECT_NUMBER="$(gcloud projects describe $PROJECT_ID --format='get(projectNumber)')"
NETWORK=cloud-deploy-network
SUBNETWORK=cloud-deploy-subnet
REGION=europe-west1
ZONE=europe-west1-b
DEV_CLUSTER=cloud-deploy-cicd-cluster-dev
DEV_CLUSTER_CONTROL_PLANE_CIDR=172.16.0.0/28
PRD_CLUSTER=cloud-deploy-cicd-cluster-prd
PRD_CLUSTER_CONTROL_PLANE_CIDR=172.16.0.32/28
ROUTER=cicd-router
NAT=cicd-nat
DELIVERY_PIPELINE=dp-demo
RELEASE_1=release-1
RELEASE_2=release-2
DEV_TARGET=cluster-dev
PRD_TARGET=cluster-prod
APP_REPO=app-repo
ENV_REPO=env-repo
APP_IMAGE=cicd-image
DEV_APP_TRIGGER=dev-app-trigger
PRD_APP_TRIGGER=prd-app-trigger
DEV_ENV_TRIGGER=dev-env-trigger
PRD_ENV_TRIGGER=prd-env-trigger

# Create VPC
gcloud compute networks create $NETWORK \
    --subnet-mode=custom \
    --mtu=1460 \
    --bgp-routing-mode=regional

# Create subnetwork
gcloud compute networks subnets create $SUBNETWORK \
    --range=10.100.0.0/20  \
    --network=$NETWORK \
    --region=$REGION

# Create private cluster
gcloud beta container clusters create $DEV_CLUSTER \
  --zone $ZONE \
  --network $NETWORK \
  --subnetwork $SUBNETWORK \
  --enable-stackdriver-kubernetes \
  --enable-network-policy \
  --enable-private-nodes \
  --master-ipv4-cidr $DEV_CLUSTER_CONTROL_PLANE_CIDR \
  --no-enable-master-authorized-networks \
  --enable-ip-alias \
  --async

gcloud beta container clusters create $PRD_CLUSTER \
  --zone $ZONE \
  --network $NETWORK \
  --subnetwork $SUBNETWORK \
  --enable-stackdriver-kubernetes \
  --enable-network-policy \
  --enable-private-nodes \
  --master-ipv4-cidr $PRD_CLUSTER_CONTROL_PLANE_CIDR \
  --no-enable-master-authorized-networks \
  --enable-ip-alias \
  --async

# Enable nodes access to public Internet
gcloud compute routers create $ROUTER \
    --network=$NETWORK \
    --region=$REGION

gcloud compute routers nats create $NAT \
    --router $ROUTER \
    --region=$REGION \
    --auto-allocate-nat-external-ips \
    --nat-all-subnet-ip-ranges

# Create the 2 Source Repositories
gcloud source repos create $APP_REPO
gcloud source repos create $ENV_REPO

# Grant the Cloud Build service account access to the cluster
gcloud projects add-iam-policy-binding ${PROJECT_NUMBER} \
    --member=serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
    --role=roles/container.developer

gcloud projects add-iam-policy-binding ${PROJECT_NUMBER} \
    --member=serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
    --role=roles/clouddeploy.viewer

# Register the Cloud Deploy Delivery Pipeline
gcloud beta deploy apply \
    --file clouddeploy.yaml --region=$REGION

# Grant Cloud Build SA the Source Repo Writer IAM role to push to repo
cat >/tmp/$ENV_REPO-policy.yaml <<EOF
bindings:
- members:
  - serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com
  role: roles/source.writer
EOF

gcloud source repos set-iam-policy \
    $ENV_REPO /tmp/$ENV_REPO-policy.yaml


cat >/tmp/delivery-pipeline.yaml <<EOF
bindings:
- role: roles/clouddeploy.admin
  members:
  - serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com
- role: roles/clouddeploy.developer
  members:
  - serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com
- role: roles/clouddeploy.operator
  members:
  - serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com
- role: roles/clouddeploy.approver
  members:
  - serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com
EOF

gcloud deploy delivery-pipelines set-iam-policy $DELIVERY_PIPELINE /tmp/delivery-pipeline.yaml \
    --region=$REGION 

# Prepare local app repo
cd app
git init
git add . 
git commit -m "App code first commit"
git branch -m master dev
git branch prod
git remote add google \
    "https://source.developers.google.com/p/$PROJECT_ID/r/${APP_REPO}"
git push --set-upstream google dev
cd ..

# Initialize the env repository
cd env
git init
git add . 
git commit -m "Env code first commit"
git branch -m master dev
git branch prod
git remote add google \
    "https://source.developers.google.com/p/$PROJECT_ID/r/${ENV_REPO}"
git push --set-upstream google dev
cd ..


# Create Cloud Build Trigger to Push image to GCR after a Source Repository push
gcloud beta builds triggers create cloud-source-repositories \
    --name=$DEV_APP_TRIGGER \
    --repo=$APP_REPO \
    --branch-pattern="^dev$" \
    --build-config="cloudbuild.yaml" \
    --substitutions _PROJECT_ID=$PROJECT_ID,_APP_IMAGE=$APP_IMAGE,_ENV_REPO=$ENV_REPO,_ENV_NAME=dev


# Create Cloud Build Trigger for the Continuous Deployment pipeline
gcloud beta builds triggers create cloud-source-repositories \
    --name=$DEV_ENV_TRIGGER \
    --repo=$ENV_REPO \
    --branch-pattern="^dev$" \
    --build-config="cloudbuild.yaml" \
    --substitutions _REGION=$REGION,_DELIVERY_PIPELINE=$DELIVERY_PIPELINE,_ENV=dev


# Create Cloud Build Trigger to Push image to GCR after a Source Repository push
gcloud beta builds triggers create cloud-source-repositories \
    --name=$PRD_APP_TRIGGER \
    --repo=$APP_REPO \
    --branch-pattern="^prod$" \
    --build-config="cloudbuild.yaml" \
    --substitutions _PROJECT_ID=$PROJECT_ID,_APP_IMAGE=$APP_IMAGE,_ENV_REPO=$ENV_REPO,_ENV_NAME=prod


# Create Cloud Build Trigger for the Continuous Deployment pipeline
gcloud beta builds triggers create cloud-source-repositories \
    --name=$PRD_ENV_TRIGGER \
    --repo=$ENV_REPO \
    --branch-pattern="^prod$" \
    --build-config="cloudbuild.yaml" \
    --substitutions _REGION=$REGION,_DELIVERY_PIPELINE=$DELIVERY_PIPELINE,_ENV=prod
