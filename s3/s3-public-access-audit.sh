#!/bin/bash
# ============================================================
# Script : s3-public-access-audit.sh
# Description : Audits all S3 buckets for public access.
#               Flags buckets that have public ACLs or
#               missing Block Public Access settings.
#               Helps identify security risks quickly.
# Usage  : bash s3-public-access-audit.sh [--fix]
#          Use --fix to automatically block public access
# ============================================================

set -euo pipefail

FIX_MODE="${1:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo "======================================================"
echo "         S3 Public Access Security Audit"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
if [[ "$FIX_MODE" == "--fix" ]]; then
  echo -e "  ${YELLOW}Mode: AUTO-FIX (will block public access)${NC}"
fi
echo "======================================================"
echo ""

BUCKETS=$(aws s3api list-buckets --query 'Buckets[*].Name' --output text | tr '\t' '\n')

PUBLIC_COUNT=0
SAFE_COUNT=0

while IFS= read -r BUCKET; do
  # Get block public access config
  BLOCK_CONFIG=$(aws s3api get-public-access-block \
    --bucket "$BUCKET" \
    --query 'PublicAccessBlockConfiguration' \
    --output json 2>/dev/null || echo '{}')

  BLOCK_ALL=$(echo "$BLOCK_CONFIG" | jq -r '
    if .BlockPublicAcls == true and
       .IgnorePublicAcls == true and
       .BlockPublicPolicy == true and
       .RestrictPublicBuckets == true
    then "true" else "false" end')

  # Check bucket ACL
  ACL=$(aws s3api get-bucket-acl \
    --bucket "$BUCKET" \
    --query 'Grants[?Grantee.URI==`http://acs.amazonaws.com/groups/global/AllUsers`].Permission' \
    --output text 2>/dev/null || echo "")

  if [[ "$BLOCK_ALL" == "true" && -z "$ACL" ]]; then
    echo -e "  ${GREEN} SECURE${NC}   $BUCKET"
    SAFE_COUNT=$((SAFE_COUNT + 1))
  else
    echo -e "  ${RED} PUBLIC${NC}   $BUCKET"

    [[ "$BLOCK_ALL" != "true" ]] && echo "              Block Public Access: NOT fully enabled"
    [[ -n "$ACL" ]] && echo -e "              ${RED}Public ACL: $ACL${NC}"

    PUBLIC_COUNT=$((PUBLIC_COUNT + 1))

    if [[ "$FIX_MODE" == "--fix" ]]; then
      echo -e "              ${YELLOW}→ Applying Block Public Access...${NC}"
      aws s3api put-public-access-block \
        --bucket "$BUCKET" \
        --public-access-block-configuration \
          BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
      echo -e "              ${GREEN} Fixed!${NC}"
    fi
  fi

done <<< "$BUCKETS"

echo ""
echo "======================================================"
echo -e "  ${GREEN}Secure buckets : $SAFE_COUNT${NC}"
echo -e "  ${RED}Public buckets : $PUBLIC_COUNT${NC}"
echo ""
if [[ "$PUBLIC_COUNT" -gt 0 && "$FIX_MODE" != "--fix" ]]; then
  echo -e "  ${YELLOW}Tip: Re-run with --fix to automatically block public access.${NC}"
fi
echo "======================================================"
