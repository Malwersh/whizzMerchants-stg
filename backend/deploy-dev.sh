#!/bin/bash

# Deploy Order Receiver Backend to Dev
# This script deploys the AWS SAM application to the dev environment

set -e

echo "🚀 Starting deployment to dev environment..."

# Set variables
REGION="us-east-1"
STACK_NAME="order-receiver-regional-dev"
S3_BUCKET="order-receiver-deployment-artifacts-${REGION}"
STAGE="dev"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install AWS CLI first."
    exit 1
fi

# Check if SAM CLI is installed
if ! command -v sam &> /dev/null; then
    echo "❌ SAM CLI not found. Please install SAM CLI first."
    exit 1
fi

# Navigate to backend directory
cd "$(dirname "$0")"

echo "📂 Current directory: $(pwd)"

# Build the SAM application
echo "🔨 Building SAM application..."
sam build

# Deploy the application
echo "🚀 Deploying to AWS..."
sam deploy --no-confirm-changeset

echo "✅ Deployment completed successfully!"
echo "🔗 Check the AWS console for the deployed resources."