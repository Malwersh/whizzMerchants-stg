#!/bin/bash

echo "===================================="
echo "Backend Products API Test"
echo "===================================="
echo ""
echo "Testing endpoint: /products"
echo "Business ID: business_1763662729446_c4pdvy2jldd"
echo "Table: WhizzMerchants_Products"
echo ""

# Test 1: Check if products table exists and has data
echo "Step 1: Check DynamoDB table..."
echo "aws dynamodb scan --table-name WhizzMerchants_Products --limit 5"
echo ""

API_BASE_URL="${API_BASE_URL:-}"

if [ -z "$API_BASE_URL" ]; then
	echo "Set API_BASE_URL first (example: https://<api-id>.execute-api.<region>.amazonaws.com/<stage>)"
	exit 1
fi

# Test 2: Try different endpoint variations
BASE_URL="$API_BASE_URL"

echo "Step 2: Test API endpoints (need valid token):"
echo ""
echo "Option 1: GET /products (expects businessId from token)"
echo "curl '$BASE_URL/products' -H 'Authorization: Bearer TOKEN'"
echo ""
echo "Option 2: GET /products?businessId=XXX"
echo "curl '$BASE_URL/products?businessId=business_1763662729446_c4pdvy2jldd' -H 'Authorization: Bearer TOKEN'"
echo ""
echo "Option 3: GET /merchant/products (old endpoint)"
echo "curl '$BASE_URL/merchant/products' -H 'Authorization: Bearer TOKEN'"
echo ""

# Check backend Lambda logs
echo "Step 3: Check Lambda logs for products function"
echo "aws logs tail /aws/lambda/products-handler --follow --since 5m"
echo ""

echo "===================================="
echo "Action Required:"
echo "1. Get current token from app (check Flutter logs)"
echo "2. Run curl commands above with real token"
echo "3. Check if backend returns 502 or 403"
echo "===================================="

