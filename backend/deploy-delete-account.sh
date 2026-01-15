#!/bin/bash

# Deploy Delete Account Feature - Separate Stack
# This deploys ONLY the delete account functionality without affecting the main stack

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  WhizzMerchants Delete Account Deploy${NC}"
echo -e "${BLUE}  Separate Stack (No Main Stack Impact)${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Configuration
STAGE="${STAGE:-staging}"
STACK_NAME="${STACK_NAME:-whizz-merchants-delete-account-${STAGE}}"
TEMPLATE_FILE="template-delete-account.yaml"
REGION="us-east-1"
S3_BUCKET="${S3_BUCKET:-order-receiver-sam-artifacts-${STAGE}}"

# Step 1: Validate AWS credentials
echo -e "${YELLOW}Step 1: Validating AWS credentials...${NC}"
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "${RED}❌ AWS credentials not configured or expired${NC}"
    echo -e "${YELLOW}Please run: aws configure${NC}"
    exit 1
fi
echo -e "${GREEN}✅ AWS credentials valid${NC}\n"

# Step 2: Ensure S3 bucket exists
echo -e "${YELLOW}Step 2: Checking S3 bucket for SAM artifacts...${NC}"
if ! aws s3 ls "s3://${S3_BUCKET}" > /dev/null 2>&1; then
    echo -e "${YELLOW}Creating S3 bucket: ${S3_BUCKET}${NC}"
    aws s3 mb "s3://${S3_BUCKET}" --region "${REGION}"
fi
echo -e "${GREEN}✅ S3 bucket ready${NC}\n"

# Step 3: Build SAM application
echo -e "${YELLOW}Step 3: Building SAM application...${NC}"
sam build --template "${TEMPLATE_FILE}"
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ SAM build failed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ SAM build successful${NC}\n"

# Step 4: Deploy SAM application
echo -e "${YELLOW}Step 4: Deploying to AWS...${NC}"
sam deploy \
    --template-file .aws-sam/build/template.yaml \
    --stack-name "${STACK_NAME}" \
    --s3-bucket "${S3_BUCKET}" \
    --capabilities CAPABILITY_IAM \
    --region "${REGION}" \
    --parameter-overrides Stage="${STAGE}" \
    --no-fail-on-empty-changeset \
    --no-confirm-changeset

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Deployment failed${NC}"
    exit 1
fi

echo -e "\n${GREEN}✅ Deployment successful!${NC}\n"

# Step 5: Get API endpoint
echo -e "${YELLOW}Step 5: Retrieving API endpoint...${NC}"
API_URL=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --region "${REGION}" \
    --query 'Stacks[0].Outputs[?OutputKey==`DeleteAccountApiUrl`].OutputValue' \
    --output text 2>/dev/null)

if [ -n "$API_URL" ]; then
    echo -e "${GREEN}✅ API Endpoint: ${API_URL}${NC}"
    echo -e "\n${BLUE}Delete Account Endpoint:${NC}"
    echo -e "${GREEN}${API_URL}/businesses/{businessId}${NC}"
else
    echo -e "${YELLOW}⚠️  Could not retrieve API endpoint automatically${NC}"
    echo -e "${YELLOW}Check CloudFormation outputs manually:${NC}"
    echo -e "aws cloudformation describe-stacks --stack-name ${STACK_NAME} --region ${REGION}"
fi

# Step 6: Update frontend configuration
echo -e "\n${YELLOW}Step 6: Frontend Configuration${NC}"
echo -e "${BLUE}Update your Flutter app's API base URL to:${NC}"
echo -e "${GREEN}${API_URL}${NC}"
echo -e "\n${BLUE}Or add this endpoint to your existing API service:${NC}"
echo -e "${GREEN}DELETE ${API_URL}/businesses/{businessId}${NC}"

# Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}         Deployment Complete! ✅${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "\n${GREEN}Stack Name:${NC} ${STACK_NAME}"
echo -e "${GREEN}Region:${NC} ${REGION}"
echo -e "${GREEN}Stage:${NC} ${STAGE}"
echo -e "\n${YELLOW}Next Steps:${NC}"
echo -e "1. Update frontend API URL in Flutter app"
echo -e "2. Test with a test account (do not commit credentials)"
echo -e "3. Verify categories are NOT deleted"
echo -e "4. Check CloudWatch logs if issues occur"
echo -e "\n${YELLOW}View logs:${NC}"
echo -e "aws logs tail /aws/lambda/${STACK_NAME} --follow"
echo -e "\n${YELLOW}Check stack status:${NC}"
echo -e "aws cloudformation describe-stacks --stack-name ${STACK_NAME} --region ${REGION}"
echo -e ""
