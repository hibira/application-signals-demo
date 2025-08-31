#!/bin/bash

# Script to synthesize, deploy, or destroy AWS CDK stacks with stack dependencies
# Usage: ./cdk-deploy.sh <action>
# Example for deploy: ./cdk-deploy.sh deploy
# Example for destroy: ./cdk-deploy.sh destroy
# Example to only synth: ./cdk-deploy.sh synth

ACTION=$1
USE_OTLP=${2:-false}  # Default value is false

# Check for action parameter
if [[ -z "$ACTION" ]]; then
  echo "Usage: $0 <action>"
  echo "action can be 'synth', 'deploy', or 'destroy'"
  echo "use-otlp is optional and can be 'true' or 'false' (default: false)"
  exit 1
fi

# Run CDK synth once for all stacks
if [[ "$ACTION" == "synth" || "$ACTION" == "deploy" ]]; then
  npm install
  echo "Running CDK bootstrap"
  cdk bootstrap

  rm -rf cdk.out
  echo "Running CDK synth for all stacks..."
  if cdk synth --context enableSlo=True ; then
    echo "CDK synth successful!"
    if [[ "$ACTION" == "synth" ]]; then
      exit 0
    fi
  else
    echo "CDK synth failed. Exiting."
    exit 1
  fi
fi

# Deploy or destroy all stacks in the app
if [[ "$ACTION" == "deploy" ]]; then

  # update vets service config to use the otlp collector when use-otlp is true
  MANIFEST_FILE="./lib/manifests/sample-app/vets-service-deployment.yaml"
  MANIFEST_OTLP_FILE="vets-service-deployment-otlp.yaml"
  if [[ "$USE_OTLP" == "true" ]]; then
    if [[ -f "$MANIFEST_OTLP_FILE" ]]; then
      echo "Replacing $MANIFEST_FILE with $MANIFEST_OTLP_FILE..."
      cp "$MANIFEST_OTLP_FILE" "$MANIFEST_FILE"
    else
      echo "Error: $MANIFEST_OTLP_FILE not found!"
      exit 1
    fi
  else
    echo "Using default manifest file: $MANIFEST_FILE"
  fi

  echo "Starting CDK deployment for all stacks in the app"
  # Deploy the EKS cluster with the sample app first
  if cdk deploy --all --require-approval never --no-rollback; then
    echo "Deployment successful for sample app in EKS Cluster"

    # Once the sample app is deployed, it will take up to 10 minutes for SLO metrics to appear
    echo "Waiting 45 minutes for Application Signals metrics to accumulate..."
    for i in {60..1}; do
      echo "Waiting $i minutes remaining..."
      sleep 60
    done
    echo "Wait complete. Proceeding with SLO deployment..."

    if cdk deploy --context enableSlo=True --all --require-approval never --no-rollback; then
      echo "Synthetic canary and SLO was deployed successfully"
    else
      echo "SLO deployment failed. Cleaning up SLO-related stacks only..."
      cdk destroy AppSignalsSloStack --context enableSlo=True --force --verbose
      echo "SLO stacks cleaned up. You can retry deployment without waiting 45 minutes again."
      echo "To retry: cdk deploy --context enableSlo=True --all --require-approval never"
      exit 1
    fi
  else
    # echo "Deployment failed. Please run `cdk destroy --all --force --verbose`"
    echo "Deployment failed. Attempting to clean up resources by destroying all stacks..."
    cdk destroy --all --force --verbose
    exit 1
  fi
elif [[ "$ACTION" == "destroy" ]]; then
  echo "Starting CDK destroy for all stacks in the app"
  cdk destroy  --context enableSlo=True --all --force --verbose
  echo "Destroy complete for all stacks in the app"
else
  echo "Invalid action: $ACTION. Please use 'synth', 'deploy', or 'destroy'."
  exit 1
fi
