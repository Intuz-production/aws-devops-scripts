#!/bin/bash
# ============================================================
# Script : s3-enable-versioning.sh
# Description : Enables versioning on one or all S3 buckets.
#               Also shows current versioning status for each.
# Usage  : bash s3-enable-versioning.sh [bucket-name]
#          If no bucket given, applies to ALL buckets.
# Example: bash s3-enable-versioning.sh my-important-bucket
#          bash s3-enable-versioning.sh
# ============================================================

set -euo pipefail

TARGET_BUCKET="${1:-}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

enable_versioning() {
  local bucket="$1"

  STATUS=$(aws s3api get-bucket-versioning \
    --bucket "$bucket" \
    --query 'Status' \
    --output text 2>/dev/null || echo "Unknown")

  if [[ "$STATUS" == "Enabled" ]]; then
    echo -e "  ${GREEN} Already enabled${NC}  →  $bucket"
    return
  fi

  aws s3api put-bucket-versioning \
    --bucket "$bucket" \
    --versioning-configuration Status=Enabled

  echo -e "  ${CYAN} Enabled versioning${NC} →  $bucket  (was: ${STATUS:-Disabled})"
}

echo ""
echo "======================================================"
echo "         S3 Bucket Versioning Setup"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "======================================================"
echo ""

if [[ -n "$TARGET_BUCKET" ]]; then
  echo "Enabling versioning on: $TARGET_BUCKET"
  echo ""
  enable_versioning "$TARGET_BUCKET"
else
  echo -e "${YELLOW}Applying to ALL buckets...${NC}"
  echo ""

  BUCKETS=$(aws s3api list-buckets --query 'Buckets[*].Name' --output text | tr '\t' '\n')

  while IFS= read -r BUCKET; do
    enable_versioning "$BUCKET"
  done <<< "$BUCKETS"
fi

echo ""
echo "======================================================"
echo -e "${GREEN}Done.${NC}"
echo "======================================================"
