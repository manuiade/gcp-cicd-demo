# Cloud Build + Cloud Deploy Demo

## Requirements

- GCP project with linked Billing Account
- GCP user with enough privileges on the project (Owner for testing purposes)

## Setup
```
git config credential.helper gcloud.sh
./setup.sh <PROJECT_ID>
```

## Test Cloud Deploy

### Set Env variables
```
REGION=europe-west1
ZONE=europe-west1-b
DELIVERY_PIPELINE=dp-demo
RELEASE_1=rel-$(date +%y%m%d-%s)
RELEASE_2=test-release-2
DEV_TARGET=cluster-dev
PRD_TARGET=cluster-prod
```

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
./delete.sh <PROJECT_ID>
```