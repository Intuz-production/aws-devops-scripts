#!/bin/bash
# ============================================================
# Script : s3-presign-url.sh
# Description : Generates a temporary pre-signed download URL
#               for any private S3 object. Share files
#               securely without making them public.
# Usage  : bash s3-presign-url.sh <bucket> <object-key> [expiry-seconds]
# Example: bash s3-presign-url.sh my-bucket reports/jan-report.pdf
#          bash s3-presign-url.sh my-bucket reports/jan-report.pdf 86400
# Default expiry: 3600 seconds (1 hour)
# ============================================================

set -euo pipefail

BUCKET="${1:-}"
OBJECT_KEY="${2:-}"
EXPIRY="${3:-3600}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ -z "$BUCKET" || -z "$OBJECT_KEY" ]]; then
  echo "Usage: bash $0 <bucket> <object-key> [expiry-seconds]"
  echo "Example: bash $0 my-bucket reports/jan-report.pdf 86400"
  exit 1
fi

# Verify the object exists
aws s3api head-object --bucket "$BUCKET" --key "$OBJECT_KEY" > /dev/null 2>&1 || {
  echo "Error: Object not found → s3://$BUCKET/$OBJECT_KEY"
  exit 1
}

# Human-readable expiry label
if   (( EXPIRY >= 86400 )); then EXPIRY_LABEL="$(( EXPIRY / 86400 )) day(s)"
elif (( EXPIRY >= 3600 ));  then EXPIRY_LABEL="$(( EXPIRY / 3600 )) hour(s)"
else                              EXPIRY_LABEL="$EXPIRY second(s)"
fi

URL=$(aws s3 presign "s3://$BUCKET/$OBJECT_KEY" --expires-in "$EXPIRY")

echo ""
echo "======================================================"
echo "          S3 Pre-Signed URL Generated"
echo "  Bucket  : $BUCKET"
echo "  Object  : $OBJECT_KEY"
echo "  Expires : $EXPIRY_LABEL"
echo "======================================================"
echo ""
echo -e "${GREEN}Pre-Signed URL:${NC}"
echo "$URL"
echo ""
echo "======================================================"
echo -e "${YELLOW}This URL grants temporary read access. Do not share publicly.${NC}"
echo "======================================================"
