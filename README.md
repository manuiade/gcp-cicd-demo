# Cloud Build + Cloud Deploy Demo

## Requirements

- GCP project with linked Billing Account
- GCP user with enough privileges on the project (Owner for testing purposes)

## Setup

### Set Env variables
```
export PROJECT_ID=<PROJECT_ID>
export PROJECT_NUMBER="$(gcloud projects describe $PROJECT_ID --format='get(projectNumber)')"
export NETWORK=cloud-deploy-network
export SUBNETWORK=cloud-deploy-subnet
export REGION=europe-west1
export ZONE=europe-west1-b
export DEV_CLUSTER=cloud-deploy-cicd-cluster-dev
export DEV_CLUSTER_CONTROL_PLANE_CIDR=172.16.0.0/28
export PRD_CLUSTER=cloud-deploy-cicd-cluster-prd
export PRD_CLUSTER_CONTROL_PLANE_CIDR=172.16.0.32/28
export ROUTER=cicd-router
export NAT=cicd-nat
export DELIVERY_PIPELINE=dp-demo
export RELEASE_1=release-1
export RELEASE_2=release-2
export DEV_TARGET=cluster-dev
export PRD_TARGET=cluster-prod
export APP_REPO=app-repo
export ENV_REPO=env-repo
export APP_IMAGE=cicd-image
export DEV_APP_TRIGGER=dev-app-trigger
export PRD_APP_TRIGGER=prd-app-trigger
export DEV_ENV_TRIGGER=dev-env-trigger
export PRD_ENV_TRIGGER=prd-env-trigger

export RELEASE_1=rel-$(date +%y%m%d-%s)
export RELEASE_2=test-release-2

sed -i "s/PROJECT_ID/$PROJECT_ID/g" clouddeploy.yaml
sed -i "s/ZONE/$ZONE/g" clouddeploy.yaml
sed -i "s/DEV_CLUSTER/$DEV_CLUSTER/g" clouddeploy.yaml
sed -i "s/PRD_CLUSTER/$PRD_CLUSTER/g" clouddeploy.yaml
```

### Create resources

```
git config credential.helper gcloud.sh
./setup.sh 
```

## Test Cloud Deploy
### Create e new release by committing app code (wait for Cloud Deploy release to complete deployment to dev cluster)
```
cd app
# Change app.py message
git add .
git commit -m "Test"
git push
```


### Promote the release (with manual approving set)
```
gcloud deploy releases promote \
  --release=$RELEASE_1 \
  --delivery-pipeline=$DELIVERY_PIPELINE \
  --region $REGION
```

### Manual approve
```
gcloud deploy rollouts approve $RELEASE_1-to-$PRD_TARGET-0001 \
  --release $RELEASE_1 \
  --delivery-pipeline=$DELIVERY_PIPELINE \
  --region $REGION
```

# Roll back to previous release (manual approvation required)
```
gcloud deploy targets rollback $PRD_TARGET \
   --delivery-pipeline=$DELIVERY_PIPELINE \
   --region $REGION
   # --release=$RELEASE_1
```

## Delete
```
sed -i "s/$PROJECT_ID/PROJECT_ID/g" clouddeploy.yaml
sed -i "s/$ZONE/ZONE/g" clouddeploy.yaml
sed -i "s/$DEV_CLUSTER/DEV_CLUSTER/g" clouddeploy.yaml
sed -i "s/$PRD_CLUSTER/PRD_CLUSTER/g" clouddeploy.yaml

./delete.sh
```