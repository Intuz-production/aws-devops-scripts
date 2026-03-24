#!/bin/bash
# ============================================================
# Script : cw-export-logs-to-s3.sh
# Description : Exports a CloudWatch log group to an S3 bucket
#               for a given time range. Useful for archival
#               and cost reduction.
# Usage  : bash cw-export-logs-to-s3.sh <log-group> <s3-bucket> [days_back]
# Example: bash cw-export-logs-to-s3.sh /aws/lambda/my-fn my-archive-bucket 7
# Prereq : The S3 bucket must have the correct bucket policy
#          allowing logs.amazonaws.com to write to it.
# ============================================================

set -euo pipefail

LOG_GROUP="${1:-}"
S3_BUCKET="${2:-}"
DAYS_BACK="${3:-1}"
AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [[ -z "$LOG_GROUP" || -z "$S3_BUCKET" ]]; then
  echo "Usage: bash $0 <log-group> <s3-bucket> [days_back]"
  echo "Example: bash $0 /aws/lambda/my-function my-archive-bucket 7"
  exit 1
fi

# Time range
FROM_MS=$(date -u -d "$DAYS_BACK days ago" +%s%3N)
TO_MS=$(date -u +%s%3N)

# S3 destination prefix based on log group name and date
SAFE_GROUP=$(echo "$LOG_GROUP" | sed 's|/|_|g' | sed 's|^_||')
S3_PREFIX="cloudwatch-exports/${SAFE_GROUP}/$(date +%Y/%m/%d)"

echo ""
echo "======================================================"
echo "       CloudWatch → S3 Log Export"
echo "  Log Group : $LOG_GROUP"
echo "  S3 Bucket : s3://$S3_BUCKET/$S3_PREFIX"
echo "  Time range: Last $DAYS_BACK day(s)"
echo "  Region    : $AWS_REGION"
echo "======================================================"
echo ""

TASK_ID=$(aws logs create-export-task \
  --region "$AWS_REGION" \
  --log-group-name "$LOG_GROUP" \
  --from "$FROM_MS" \
  --to "$TO_MS" \
  --destination "$S3_BUCKET" \
  --destination-prefix "$S3_PREFIX" \
  --query 'taskId' \
  --output text)

echo -e "${GREEN}Export task created. Task ID: $TASK_ID${NC}"
echo "Waiting for completion..."
echo ""

# Poll until task completes
while true; do
  STATUS=$(aws logs describe-export-tasks \
    --region "$AWS_REGION" \
    --task-id "$TASK_ID" \
    --query 'exportTasks[0].status.code' \
    --output text)

  case "$STATUS" in
    COMPLETED)
      echo -e "${GREEN} Export completed successfully!${NC}"
      echo "  Logs saved to: s3://$S3_BUCKET/$S3_PREFIX"
      break
      ;;
    FAILED)
      echo -e "${RED} Export task failed.${NC}"
      aws logs describe-export-tasks \
        --region "$AWS_REGION" \
        --task-id "$TASK_ID" \
        --query 'exportTasks[0].status.message' \
        --output text
      exit 1
      ;;
    CANCELLED)
      echo -e "${RED} Export task was cancelled.${NC}"
      exit 1
      ;;
    *)
      echo -e "${YELLOW}  Status: $STATUS ... waiting 10s${NC}"
      sleep 10
      ;;
  esac
done

echo ""
echo "======================================================"
