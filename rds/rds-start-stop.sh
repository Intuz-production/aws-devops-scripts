#!/bin/bash
# ============================================================
# Script : rds-start-stop.sh
# Description : Start or stop one or all RDS instances.
#               Waits for the operation to complete and
#               confirms the final state.
# Usage  : bash rds-start-stop.sh <start|stop> [instance-id]
#          If no instance-id, applies to ALL instances.
# Example: bash rds-start-stop.sh stop my-dev-db
#          bash rds-start-stop.sh stop          ← stops ALL
# ============================================================

set -euo pipefail

ACTION="${1:-}"
TARGET_DB="${2:-}"
AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

if [[ "$ACTION" != "start" && "$ACTION" != "stop" ]]; then
  echo "Usage: bash $0 <start|stop> [instance-id]"
  echo "Example: bash $0 stop my-dev-db"
  echo "         bash $0 start                   (starts all stopped instances)"
  exit 1
fi

DESIRED_STATE="available"
WAIT_STATE="starting"
[[ "$ACTION" == "stop" ]] && DESIRED_STATE="stopped" && WAIT_STATE="stopping"

do_action() {
  local db_id="$1"
  local current_status="$2"

  if [[ "$ACTION" == "stop" && "$current_status" != "available" ]]; then
    echo -e "  ${YELLOW} Skipping $db_id (status: $current_status, not available)${NC}"
    return
  fi
  if [[ "$ACTION" == "start" && "$current_status" != "stopped" ]]; then
    echo -e "  ${YELLOW} Skipping $db_id (status: $current_status, not stopped)${NC}"
    return
  fi

  echo -e "  ${CYAN}→ ${ACTION^}ing: $db_id${NC}"

  if [[ "$ACTION" == "stop" ]]; then
    aws rds stop-db-instance \
      --region "$AWS_REGION" \
      --db-instance-identifier "$db_id" > /dev/null
  else
    aws rds start-db-instance \
      --region "$AWS_REGION" \
      --db-instance-identifier "$db_id" > /dev/null
  fi

  # Wait for completion
  echo -n "    Waiting"
  while true; do
    STATUS=$(aws rds describe-db-instances \
      --region "$AWS_REGION" \
      --db-instance-identifier "$db_id" \
      --query 'DBInstances[0].DBInstanceStatus' \
      --output text)

    if [[ "$STATUS" == "$DESIRED_STATE" ]]; then
      echo ""
      echo -e "    ${GREEN} $db_id is now: $STATUS${NC}"
      break
    fi
    echo -n "."
    sleep 15
  done
}

echo ""
echo "======================================================"
echo "          RDS Instance ${ACTION^}"
echo "  Region  : $AWS_REGION"
echo "  Action  : $ACTION"
echo "  Target  : ${TARGET_DB:-(All eligible instances)}"
echo "======================================================"
echo ""

if [[ -n "$TARGET_DB" ]]; then
  CURRENT=$(aws rds describe-db-instances \
    --region "$AWS_REGION" \
    --db-instance-identifier "$TARGET_DB" \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text)
  do_action "$TARGET_DB" "$CURRENT"
else
  INSTANCES=$(aws rds describe-db-instances \
    --region "$AWS_REGION" \
    --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus]' \
    --output text)

  if [[ -z "$INSTANCES" ]]; then
    echo "No RDS instances found."
    exit 0
  fi

  while IFS=$'\t' read -r db_id status; do
    do_action "$db_id" "$status"
  done <<< "$INSTANCES"
fi

echo ""
echo "======================================================"
echo -e "${GREEN}Done.${NC}"
echo "======================================================"
