#!/bin/bash

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