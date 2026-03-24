#!/bin/bash
# ============================================================
# Script : rds-create-snapshot.sh
# Description : Creates a manual snapshot of an RDS instance
#               with an auto-generated or custom name.
#               Waits for the snapshot to become available.
# Usage  : bash rds-create-snapshot.sh <instance-id> [snapshot-name]
# Example: bash rds-create-snapshot.sh my-prod-db
#          bash rds-create-snapshot.sh my-prod-db pre-deploy-snapshot
# ============================================================

set -euo pipefail

DB_INSTANCE="${1:-}"
SNAPSHOT_NAME="${2:-}"
AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [[ -z "$DB_INSTANCE" ]]; then
  echo "Usage: bash $0 <instance-id> [snapshot-name]"
  echo "Example: bash $0 my-prod-db pre-deploy-backup"
  exit 1
fi

# Auto-generate snapshot name if not provided
if [[ -z "$SNAPSHOT_NAME" ]]; then
  SNAPSHOT_NAME="${DB_INSTANCE}-manual-$(date +%Y%m%d-%H%M%S)"
fi

echo ""
echo "======================================================"
echo "        RDS Manual Snapshot"
echo "  Instance : $DB_INSTANCE"
echo "  Snapshot : $SNAPSHOT_NAME"
echo "  Region   : $AWS_REGION"
echo "======================================================"
echo ""

# Create snapshot
aws rds create-db-snapshot \
  --region "$AWS_REGION" \
  --db-instance-identifier "$DB_INSTANCE" \
  --db-snapshot-identifier "$SNAPSHOT_NAME" > /dev/null

echo -e "${CYAN}Snapshot creation initiated. Waiting for completion...${NC}"
echo -n "  Progress"

# Poll until available
while true; do
  STATUS=$(aws rds describe-db-snapshots \
    --region "$AWS_REGION" \
    --db-snapshot-identifier "$SNAPSHOT_NAME" \
    --query 'DBSnapshots[0].Status' \
    --output text 2>/dev/null || echo "creating")

  PROGRESS=$(aws rds describe-db-snapshots \
    --region "$AWS_REGION" \
    --db-snapshot-identifier "$SNAPSHOT_NAME" \
    --query 'DBSnapshots[0].PercentProgress' \
    --output text 2>/dev/null || echo "0")

  if [[ "$STATUS" == "available" ]]; then
    echo ""
    echo ""
    echo -e "  ${GREEN} Snapshot available!${NC}"
    break
  elif [[ "$STATUS" == "failed" ]]; then
    echo ""
    echo -e "  ${RED} Snapshot failed!${NC}"
    exit 1
  fi

  echo -n " ${PROGRESS}%"
  sleep 15
done

# Get snapshot details
SIZE=$(aws rds describe-db-snapshots \
  --region "$AWS_REGION" \
  --db-snapshot-identifier "$SNAPSHOT_NAME" \
  --query 'DBSnapshots[0].AllocatedStorage' \
  --output text)

echo ""
echo "======================================================"
echo -e "  ${GREEN}Snapshot Details${NC}"
echo "  Name     : $SNAPSHOT_NAME"
echo "  Size     : ${SIZE} GB"
echo "  Created  : $(date '+%Y-%m-%d %H:%M:%S')"
echo "======================================================"
