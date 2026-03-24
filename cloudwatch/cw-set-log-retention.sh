#!/bin/bash
# ============================================================
# Script : cw-set-log-retention.sh
# Description : Sets a retention policy (in days) on all
#               CloudWatch log groups, or a specific one.
#               Useful for cost control.
# Usage  : bash cw-set-log-retention.sh <days> [log-group]
#          If log-group is omitted, applies to ALL log groups.
# Example: bash cw-set-log-retention.sh 30
#          bash cw-set-log-retention.sh 90 /aws/lambda/my-function
#
# Valid retention days: 1,3,5,7,14,30,60,90,120,150,180,365,
#                       400,545,731,1096,1827,2192,2557,2922,3288,3653
# ============================================================

set -euo pipefail

RETENTION_DAYS="${1:-}"
TARGET_GROUP="${2:-}"
AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

VALID_DAYS="1 3 5 7 14 30 60 90 120 150 180 365 400 545 731 1096 1827 2192 2557 2922 3288 3653"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [[ -z "$RETENTION_DAYS" ]]; then
  echo "Usage: bash $0 <days> [log-group-name]"
  echo "Example: bash $0 30"
  echo "         bash $0 90 /aws/lambda/my-function"
  echo ""
  echo "Valid days: $VALID_DAYS"
  exit 1
fi

if ! echo "$VALID_DAYS" | grep -qw "$RETENTION_DAYS"; then
  echo -e "${RED}Invalid retention period: $RETENTION_DAYS days.${NC}"
  echo "Valid values: $VALID_DAYS"
  exit 1
fi

set_retention() {
  local group="$1"
  aws logs put-retention-policy \
    --region "$AWS_REGION" \
    --log-group-name "$group" \
    --retention-in-days "$RETENTION_DAYS"
  echo -e "${GREEN}${NC} $group → $RETENTION_DAYS days"
}

echo ""
echo "======================================================"
echo "     CloudWatch Log Retention Policy Update"
echo "  Retention : $RETENTION_DAYS days"
echo "  Region    : $AWS_REGION"
echo "======================================================"
echo ""

if [[ -n "$TARGET_GROUP" ]]; then
  echo "Applying to single log group: $TARGET_GROUP"
  echo ""
  set_retention "$TARGET_GROUP"
else
  echo -e "${YELLOW}Applying to ALL log groups in region $AWS_REGION...${NC}"
  echo ""

  UPDATED=0
  SKIPPED=0

  NEXT_TOKEN=""
  while true; do
    if [[ -n "$NEXT_TOKEN" ]]; then
      RESPONSE=$(aws logs describe-log-groups \
        --region "$AWS_REGION" \
        --next-token "$NEXT_TOKEN" \
        --output json)
    else
      RESPONSE=$(aws logs describe-log-groups \
        --region "$AWS_REGION" \
        --output json)
    fi

    GROUPS=$(echo "$RESPONSE" | jq -r '.logGroups[].logGroupName')
    NEXT_TOKEN=$(echo "$RESPONSE" | jq -r '.nextToken // empty')

    for GROUP in $GROUPS; do
      set_retention "$GROUP"
      UPDATED=$((UPDATED + 1))
    done

    [[ -z "$NEXT_TOKEN" ]] && break
  done

  echo ""
  echo "======================================================"
  echo -e "${GREEN}Done. Updated $UPDATED log group(s).${NC}"
fi

echo "======================================================"
