#!/bin/bash
# ============================================================
# Script : s3-find-large-files.sh
# Description : Lists the top N largest files in an S3 bucket
#               (or a specific folder prefix within it).
#               Useful for identifying storage cost drivers.
# Usage  : bash s3-find-large-files.sh <bucket> [prefix] [top-n]
# Example: bash s3-find-large-files.sh my-bucket
#          bash s3-find-large-files.sh my-bucket logs/ 20
# ============================================================

set -euo pipefail

BUCKET="${1:-}"
PREFIX="${2:-}"
TOP_N="${3:-10}"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

human_size() {
  local bytes=$1
  if   (( bytes >= 1073741824 )); then printf "%.2f GB" "$(echo "$bytes / 1073741824" | bc -l)"
  elif (( bytes >= 1048576 ));    then printf "%.2f MB" "$(echo "$bytes / 1048576" | bc -l)"
  elif (( bytes >= 1024 ));       then printf "%.2f KB" "$(echo "$bytes / 1024" | bc -l)"
  else echo "${bytes} B"
  fi
}

if [[ -z "$BUCKET" ]]; then
  echo "Usage: bash $0 <bucket> [prefix] [top-n]"
  echo "Example: bash $0 my-bucket logs/ 20"
  exit 1
fi

S3_PATH="s3://$BUCKET"
[[ -n "$PREFIX" ]] && S3_PATH="$S3_PATH/$PREFIX"

echo ""
echo "======================================================"
echo "        S3 Largest Files Report"
echo "  Path   : $S3_PATH"
echo "  Top    : $TOP_N files"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "======================================================"
echo ""

echo -e "${YELLOW}Scanning... (this may take a moment for large buckets)${NC}"
echo ""

# List all objects, extract size+key, sort by size descending, take top N
RESULTS=$(aws s3api list-objects-v2 \
  --bucket "$BUCKET" \
  ${PREFIX:+--prefix "$PREFIX"} \
  --query 'Contents[*].[Size, Key]' \
  --output text | sort -rn | head -n "$TOP_N")

if [[ -z "$RESULTS" ]]; then
  echo "No objects found in $S3_PATH"
  exit 0
fi

RANK=1
printf "%-5s %-60s %12s\n" "Rank" "Object Key" "Size"
echo "----------------------------------------------------------------------"

while IFS=$'\t' read -r size key; do
  readable=$(human_size "$size")
  printf "%-5s %-60s %12s\n" "#$RANK" "${key:0:60}" "$readable"
  RANK=$((RANK + 1))
done <<< "$RESULTS"

echo "----------------------------------------------------------------------"
echo ""
echo -e "${GREEN}Tip: Consider archiving or deleting large files you no longer need.${NC}"
echo "     Use 's3-lifecycle-apply.sh' to auto-tier large old files to Glacier."
echo "======================================================"
