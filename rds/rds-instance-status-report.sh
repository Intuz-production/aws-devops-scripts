#!/bin/bash
# ============================================================
# Script : rds-instance-status-report.sh
# Description : Lists all RDS instances with their status,
#               engine, instance class, storage, and
#               Multi-AZ configuration in a clean table.
# Usage  : bash rds-instance-status-report.sh
# ============================================================

set -euo pipefail

AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo "======================================================"
echo "          RDS Instance Status Report"
echo "  Region: $AWS_REGION  |  $(date '+%Y-%m-%d %H:%M:%S')"
echo "======================================================"
echo ""
printf "%-30s %-12s %-15s %-14s %-8s %-8s\n" \
  "Instance ID" "Status" "Engine" "Class" "Storage" "Multi-AZ"
echo "--------------------------------------------------------------------------------"

INSTANCES=$(aws rds describe-db-instances \
  --region "$AWS_REGION" \
  --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Engine,EngineVersion,DBInstanceClass,AllocatedStorage,MultiAZ]' \
  --output text)

if [[ -z "$INSTANCES" ]]; then
  echo "No RDS instances found in region $AWS_REGION."
  exit 0
fi

TOTAL=0
AVAILABLE=0
STOPPED=0

while IFS=$'\t' read -r id status engine version class storage multiaz; do
  TOTAL=$((TOTAL + 1))

  case "$status" in
    available)  COLOR=$GREEN ;;
    stopped)    COLOR=$RED   ;;
    *)          COLOR=$YELLOW ;;
  esac

  multiaz_label="No"
  [[ "$multiaz" == "True" ]] && multiaz_label="Yes"

  [[ "$status" == "available" ]] && AVAILABLE=$((AVAILABLE + 1))
  [[ "$status" == "stopped" ]]   && STOPPED=$((STOPPED + 1))

  printf "%-30s " "${id:0:30}"
  printf "${COLOR}%-12s${NC} " "$status"
  printf "%-15s %-14s %-8s %-8s\n" \
    "${engine} ${version}" "${class:3}" "${storage}GB" "$multiaz_label"

done <<< "$INSTANCES"

echo "--------------------------------------------------------------------------------"
echo ""
echo -e "${CYAN}Summary${NC}"
echo "  Total    : $TOTAL"
echo -e "  Available: ${GREEN}$AVAILABLE${NC}"
echo -e "  Stopped  : ${RED}$STOPPED${NC}"
echo "======================================================"
