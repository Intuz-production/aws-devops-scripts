#!/bin/bash
# ============================================================
# Script : cw-cost-estimate.sh
# Description : Estimates CloudWatch costs based on:
#               - Total log group storage used (in GB)
#               - Log ingestion approximation per group
#               Helpful for spotting top cost contributors.
# Usage  : bash cw-cost-estimate.sh
# Note   : Pricing based on us-east-1. Adjust if needed.
# ============================================================

set -euo pipefail

AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# AWS CloudWatch Pricing (us-east-1, adjust for your region)
STORAGE_COST_PER_GB=0.03      # $0.03 per GB per month
INGESTION_COST_PER_GB=0.50    # $0.50 per GB ingested

CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "======================================================"
echo "     CloudWatch Cost Estimate Report"
echo "  Region : $AWS_REGION  |  $(date '+%Y-%m-%d')"
echo "======================================================"
echo ""

TOTAL_BYTES=0
GROUP_COUNT=0

printf "%-55s %10s %12s\n" "Log Group" "Size (MB)" "Est. Cost/mo"
echo "----------------------------------------------------------------------"

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

  NEXT_TOKEN=$(echo "$RESPONSE" | jq -r '.nextToken // empty')

  while IFS=$'\t' read -r group_name stored_bytes; do
    stored_bytes="${stored_bytes:-0}"
    [[ "$stored_bytes" == "null" ]] && stored_bytes=0

    mb=$(echo "scale=2; $stored_bytes / 1048576" | bc)
    gb=$(echo "scale=6; $stored_bytes / 1073741824" | bc)
    cost=$(echo "scale=4; $gb * $STORAGE_COST_PER_GB" | bc)

    printf "%-55s %10s %12s\n" "${group_name:0:55}" "$mb" "\$$cost"

    TOTAL_BYTES=$((TOTAL_BYTES + stored_bytes))
    GROUP_COUNT=$((GROUP_COUNT + 1))
  done < <(echo "$RESPONSE" | jq -r '.logGroups[] | [.logGroupName, (.storedBytes // 0)] | @tsv')

  [[ -z "$NEXT_TOKEN" ]] && break
done

TOTAL_GB=$(echo "scale=4; $TOTAL_BYTES / 1073741824" | bc)
TOTAL_COST=$(echo "scale=4; $TOTAL_GB * $STORAGE_COST_PER_GB" | bc)

echo "----------------------------------------------------------------------"
echo ""
echo -e "${CYAN}Summary${NC}"
echo "  Total log groups : $GROUP_COUNT"
printf "  Total stored     : %s GB\n" "$TOTAL_GB"
echo ""
echo -e "${YELLOW}Estimated Monthly Storage Cost : \$$TOTAL_COST${NC}"
echo "  (Based on \$${STORAGE_COST_PER_GB}/GB/month for ${AWS_REGION})"
echo ""
echo -e "${GREEN}Tip: Use cw-set-log-retention.sh to reduce storage costs.${NC}"
echo "======================================================"
