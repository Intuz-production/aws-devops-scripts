#!/bin/bash
# ============================================================
# Script : rds-snapshot-report.sh
# Description : Lists all manual and automated RDS snapshots
#               with size, creation time, and age in days.
#               Helps identify old snapshots wasting storage.
# Usage  : bash rds-snapshot-report.sh [instance-id]
#          If no instance given, lists ALL snapshots.
# Example: bash rds-snapshot-report.sh my-db
# ============================================================

set -euo pipefail

AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
DB_INSTANCE="${1:-}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo "======================================================"
echo "           RDS Snapshot Report"
echo "  Region  : $AWS_REGION"
echo "  Instance: ${DB_INSTANCE:-(All Instances)}"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "======================================================"
echo ""

EXTRA_FILTER=""
[[ -n "$DB_INSTANCE" ]] && EXTRA_FILTER="--db-instance-identifier $DB_INSTANCE"

SNAPSHOTS=$(aws rds describe-db-snapshots \
  --region "$AWS_REGION" \
  $EXTRA_FILTER \
  --query 'DBSnapshots[*].[DBSnapshotIdentifier,DBInstanceIdentifier,SnapshotType,Status,SnapshotCreateTime,AllocatedStorage]' \
  --output text | sort -t$'\t' -k5 -r)

if [[ -z "$SNAPSHOTS" ]]; then
  echo "No snapshots found."
  exit 0
fi

printf "%-40s %-20s %-10s %-10s %-12s %8s\n" \
  "Snapshot ID" "DB Instance" "Type" "Status" "Created" "Size"
echo "------------------------------------------------------------------------------------------------"

TOTAL=0
TOTAL_STORAGE=0
OLD_COUNT=0  # snapshots older than 30 days

NOW=$(date +%s)

while IFS=$'\t' read -r snap_id db_id type status created_at storage; do
  TOTAL=$((TOTAL + 1))
  TOTAL_STORAGE=$((TOTAL_STORAGE + storage))

  # Calculate age
  CREATED_S=$(date -d "$created_at" +%s 2>/dev/null || echo "$NOW")
  AGE_DAYS=$(( (NOW - CREATED_S) / 86400 ))
  CREATED_LABEL=$(date -d "$created_at" '+%Y-%m-%d' 2>/dev/null || echo "Unknown")

  if (( AGE_DAYS > 30 )); then
    AGE_COLOR=$RED
    OLD_COUNT=$((OLD_COUNT + 1))
  elif (( AGE_DAYS > 14 )); then
    AGE_COLOR=$YELLOW
  else
    AGE_COLOR=$GREEN
  fi

  printf "%-40s %-20s %-10s %-10s " \
    "${snap_id:0:40}" "${db_id:0:20}" "$type" "$status"
  printf "${AGE_COLOR}%-12s${NC} %8s\n" \
    "$CREATED_LABEL (${AGE_DAYS}d)" "${storage}GB"

done <<< "$SNAPSHOTS"

echo "------------------------------------------------------------------------------------------------"
echo ""
echo -e "${CYAN}Summary${NC}"
echo "  Total Snapshots : $TOTAL"
echo "  Total Storage   : ${TOTAL_STORAGE} GB"
echo -e "  Older than 30d  : ${RED}$OLD_COUNT${NC}"
echo ""
[[ "$OLD_COUNT" -gt 0 ]] && \
  echo -e "${YELLOW}Tip: Review old snapshots to reduce RDS snapshot storage costs.${NC}"
echo "======================================================"
