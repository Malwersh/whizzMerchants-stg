#!/bin/bash

# Get token from flutter device
echo "Testing Products API..."
echo ""

API_BASE_URL="${API_BASE_URL:-}"

if [ -z "$API_BASE_URL" ]; then
	echo "Set API_BASE_URL first (example: https://<api-id>.execute-api.<region>.amazonaws.com/<stage>)"
	exit 1
fi

# Base URL
BASE_URL="$API_BASE_URL"

# You need to provide token manually
echo "Please run this in Flutter app terminal to get token:"
echo "flutter: await SecureTokenStorage.getAccessToken()"
echo ""
echo "Then run:"
echo "curl -X GET '$BASE_URL/products' \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -H 'Authorization: Bearer YOUR_TOKEN_HERE'"
echo ""
echo "Or test with business ID:"
echo "curl -X GET '$BASE_URL/products?businessId=business_1763662729446_c4pdvy2jldd' \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -H 'Authorization: Bearer YOUR_TOKEN_HERE'"

