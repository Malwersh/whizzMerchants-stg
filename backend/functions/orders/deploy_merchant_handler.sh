#!/bin/bash

###############################################################################
# Deploy Updated Merchant Order Handler Lambda
#
# This script deploys the merchant_order_handler.js with the integrated
# push notification system.
#
# What it does:
# 1. Creates a deployment package with all dependencies
# 2. Uploads to AWS Lambda
# 3. Verifies deployment
#
# Usage:
#   ./deploy_merchant_handler.sh
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
FUNCTION_NAME="${FUNCTION_NAME:-}"
REGION="${AWS_REGION:-us-east-1}"

if [ -z "$FUNCTION_NAME" ]; then
    echo -e "${RED}✗ Missing required env var: FUNCTION_NAME${NC}" >&2
    exit 1
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR="/tmp/merchant_handler_deploy_$$"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   DEPLOY MERCHANT ORDER HANDLER WITH PUSH NOTIFICATIONS   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"

# Step 1: Check if function exists
echo -e "${YELLOW}Step 1: Verifying Lambda function exists...${NC}"
if aws lambda get-function --function-name $FUNCTION_NAME --region $REGION > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Lambda function found: $FUNCTION_NAME${NC}\n"
else
    echo -e "${RED}✗ Lambda function not found: $FUNCTION_NAME${NC}"
    echo -e "${RED}  Please create the function first.${NC}\n"
    exit 1
fi

# Step 2: Create deployment package
echo -e "${YELLOW}Step 2: Creating deployment package...${NC}"

# Create temp directory
mkdir -p "$TEMP_DIR"
echo "   Created temp directory: $TEMP_DIR"

# Copy all Lambda files
cp "$SCRIPT_DIR/merchant_order_handler.js" "$TEMP_DIR/"
cp "$SCRIPT_DIR/push_notification_service.js" "$TEMP_DIR/"
cp "$SCRIPT_DIR/central-platform-integration.js" "$TEMP_DIR/"
echo "   Copied Lambda handler, push service, and central platform integration"

# Copy package.json if it exists
if [ -f "$SCRIPT_DIR/package.json" ]; then
    cp "$SCRIPT_DIR/package.json" "$TEMP_DIR/"
    echo "   Copied package.json"
fi

# Copy node_modules if they exist (for dependencies)
if [ -d "$SCRIPT_DIR/node_modules" ]; then
    cp -r "$SCRIPT_DIR/node_modules" "$TEMP_DIR/"
    echo "   Copied node_modules"
else
    echo "   No node_modules found (will use Lambda runtime packages)"
fi

# Create ZIP file
cd "$TEMP_DIR"
ZIP_FILE="/tmp/merchant_handler_${FUNCTION_NAME}_$(date +%Y%m%d_%H%M%S).zip"
zip -qr "$ZIP_FILE" .
echo -e "${GREEN}✓ Deployment package created: $ZIP_FILE${NC}"

# Get package size
PACKAGE_SIZE=$(du -h "$ZIP_FILE" | cut -f1)
echo "   Package size: $PACKAGE_SIZE"
echo ""

# Step 3: Upload to Lambda
echo -e "${YELLOW}Step 3: Uploading to AWS Lambda...${NC}"
aws lambda update-function-code \
    --function-name $FUNCTION_NAME \
    --zip-file "fileb://$ZIP_FILE" \
    --region $REGION \
    --output json > /tmp/lambda_update_result.json

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Lambda function updated successfully${NC}\n"
    
    # Show update details
    echo "Update details:"
    cat /tmp/lambda_update_result.json | grep -E '"FunctionName"|"CodeSize"|"LastModified"|"Version"'
    echo ""
else
    echo -e "${RED}✗ Failed to update Lambda function${NC}\n"
    exit 1
fi

# Step 4: Wait for function to be ready
echo -e "${YELLOW}Step 4: Waiting for function to be ready...${NC}"
sleep 3
echo -e "${GREEN}✓ Function should be ready${NC}\n"

# Step 5: Verify environment variables
echo -e "${YELLOW}Step 5: Verifying environment variables...${NC}"
aws lambda get-function-configuration \
    --function-name $FUNCTION_NAME \
    --region $REGION \
    --query 'Environment.Variables' \
    --output json > /tmp/lambda_env_vars.json

echo "Key environment variables:"
cat /tmp/lambda_env_vars.json | grep -E 'DEVICE_TOKENS_TABLE|ORDERS_TABLE|MERCHANT_ENDPOINTS_TABLE' || echo "   (No specific env vars found)"
echo ""

# Cleanup
echo -e "${YELLOW}Step 6: Cleaning up...${NC}"
rm -rf "$TEMP_DIR"
echo -e "${GREEN}✓ Temp files cleaned up${NC}\n"

# Summary
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  DEPLOYMENT SUCCESSFUL!                    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}\n"

echo "Next steps:"
echo "1. Test the push notification system:"
echo "   cd $SCRIPT_DIR"
echo "   node test_push_notifications.js <businessId>"
echo ""
echo "2. Check CloudWatch logs:"
echo "   https://console.aws.amazon.com/cloudwatch/home?region=$REGION#logsV2:log-groups/log-group/\$252Faws\$252Flambda\$252F$FUNCTION_NAME"
echo ""
echo "3. Place a test order from WizzUser app to verify end-to-end flow"
echo ""

# Save deployment info
echo "Deployment completed at: $(date)" > "$SCRIPT_DIR/last_deployment.txt"
echo "Package size: $PACKAGE_SIZE" >> "$SCRIPT_DIR/last_deployment.txt"
echo "ZIP file: $ZIP_FILE" >> "$SCRIPT_DIR/last_deployment.txt"

echo -e "${BLUE}Deployment info saved to: $SCRIPT_DIR/last_deployment.txt${NC}\n"
