#!/bin/bash

# Watch FCM Token Upload Logs
# This script monitors CloudWatch logs for FCM token upload events

echo "🔍 Watching FCM Token Upload Logs..."
echo "===================================="
echo ""
echo "Looking for:"
echo "  - FCM token upload attempts"
echo "  - Device token registration"
echo "  - Lambda function executions"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Start tailing the Lambda logs
LAMBDA_LOG_GROUP_NAME="${LAMBDA_LOG_GROUP_NAME:-}"
AWS_REGION="${AWS_REGION:-us-east-1}"

if [ -z "$LAMBDA_LOG_GROUP_NAME" ]; then
  echo "❌ Missing required env var: LAMBDA_LOG_GROUP_NAME" >&2
  exit 1
fi

aws logs tail "$LAMBDA_LOG_GROUP_NAME" \
  --region "$AWS_REGION" \
  --follow \
  --format short \
  --filter-pattern "FCM|device|token|handleRegisterDeviceToken" \
  --since 5m
