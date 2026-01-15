#!/bin/bash

# Quick Verification - Check Backend Resources

export AWS_REGION=us-east-1

echo "🔍 Checking Backend Resources..."
echo ""

# Check DynamoDB Table
echo "1️⃣  DynamoDB Table:"
if aws dynamodb describe-table --table-name WhizzMerchants_DeviceTokens --region us-east-1 --query 'Table.[TableName,TableStatus]' --output text 2>/dev/null; then
  echo "   ✅ Table exists and ready"
else
  echo "   ❌ Table not found"
fi
echo ""

# Check Lambda Function  
echo "2️⃣  Lambda Function:"
if aws lambda get-function --function-name whizz-merchants-register-device-token --region us-east-1 --query 'Configuration.[FunctionName,State]' --output text 2>/dev/null; then
  echo "   ✅ Function exists and ready"
else
  echo "   ❌ Function not found"
fi
echo ""

# Check IAM Role
echo "3️⃣  IAM Role:"
if aws iam get-role --role-name whizz-merchants-device-token-role --query 'Role.RoleName' --output text 2>/dev/null; then
  echo "   ✅ Role exists"
else
  echo "   ❌ Role not found"
fi
echo ""

echo "=========================================="
echo "Summary:"
echo "=========================================="

# If all exist, show next steps
if aws dynamodb describe-table --table-name WhizzMerchants_DeviceTokens --region us-east-1 &>/dev/null && \
   aws lambda get-function --function-name whizz-merchants-register-device-token --region us-east-1 &>/dev/null; then
  
  echo "✅ Backend is ready!"
  echo ""
  echo "🎯 Next Steps:"
  echo "  1. Test Lambda function:"
  echo "     cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/backend"
  echo "     ./test-backend-infrastructure.sh"
  echo ""
  echo "  2. Run Flutter app:"
  echo "     cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend"
  echo "     ./run_and_capture_token.sh"
  echo ""
else
  echo "❌ Backend setup incomplete"
  echo ""
  echo "Run deployment again:"
  echo "  cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/backend"
  echo "  ./deploy-backend-complete.sh"
fi
