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

gcloud config set project $PROJECT_ID

gcloud beta builds triggers delete $PRD_ENV_TRIGGER --quiet

gcloud beta builds triggers delete $PRD_APP_TRIGGER --quiet

gcloud beta builds triggers delete $DEV_ENV_TRIGGER --quiet

gcloud beta builds triggers delete $DEV_APP_TRIGGER --quiet

gcloud beta deploy delivery-pipelines delete $DELIVERY_PIPELINE \
    --force \
    --region=$REGION \
    --project=$PROJECT_ID \
    --quiet

gcloud source repos delete $ENV_REPO --quiet

gcloud source repos delete $APP_REPO --quiet

cd app
rm -rf .git
cd ..
cd env
rm -rf .git
cd ..

gcloud projects remove-iam-policy-binding ${PROJECT_NUMBER} \
    --member=serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
    --role=roles/container.developer

gcloud projects remove-iam-policy-binding ${PROJECT_NUMBER} \
    --member=serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
    --role=roles/clouddeploy.viewer


gcloud container clusters delete $PRD_CLUSTER --zone $ZONE --quiet

gcloud container clusters delete $DEV_CLUSTER --zone $ZONE --quiet

gcloud compute routers nats delete $NAT \
    --router $ROUTER \
    --region=$REGION \
    --quiet

gcloud compute routers delete $ROUTER --region $REGION --quiet

gcloud compute networks subnets delete $SUBNETWORK --region $REGION --quiet

gcloud compute networks delete $NETWORK --quiet