#!/bin/bash
# ============================================================
# Script : iam-access-key-audit.sh
# Description : Audits all IAM users' access keys showing:
#               age in days, status (Active/Inactive), and
#               last used date. Flags keys older than threshold.
#               Sends SNS alert if any keys need rotation.
# Usage  : bash iam-access-key-audit.sh [max-age-days] [sns-topic-arn]
# Example: bash iam-access-key-audit.sh 90
#          bash iam-access-key-audit.sh 90 arn:aws:sns:us-east-1:123:MyTopic
# ============================================================

set -euo pipefail

MAX_AGE="${1:-90}"
SNS_TOPIC_ARN="${2:-}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

NOW=$(date +%s)

echo ""
echo "======================================================"
echo "          IAM Access Key Audit"
echo "  Rotation threshold : $MAX_AGE days"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "======================================================"
echo ""
printf "%-22s %-22s %-10s %-12s %-22s\n" \
  "User" "Key ID" "Status" "Age (days)" "Last Used"
echo "-------------------------------------------------------------------------------------"

USERS=$(aws iam list-users --query 'Users[*].UserName' --output text | tr '\t' '\n')

NEEDS_ROTATION=()
TOTAL_KEYS=0

while IFS= read -r USERNAME; do
  KEYS=$(aws iam list-access-keys \
    --user-name "$USERNAME" \
    --query 'AccessKeyMetadata[*].[AccessKeyId,Status,CreateDate]' \
    --output text 2>/dev/null || true)

  [[ -z "$KEYS" ]] && continue

  while IFS=$'\t' read -r key_id status create_date; do
    TOTAL_KEYS=$((TOTAL_KEYS + 1))

    CREATE_TS=$(date -d "$create_date" +%s)
    AGE=$(( (NOW - CREATE_TS) / 86400 ))

    LAST_USED=$(aws iam get-access-key-last-used \
      --access-key-id "$key_id" \
      --query 'AccessKeyLastUsed.LastUsedDate' \
      --output text 2>/dev/null || echo "Never")
    [[ "$LAST_USED" == "None" ]] && LAST_USED="Never"
    [[ "$LAST_USED" != "Never" ]] && LAST_USED=$(echo "$LAST_USED" | cut -c1-10)

    if (( AGE > MAX_AGE )); then
      AGE_COLOR=$RED
      NEEDS_ROTATION+=("$USERNAME | $key_id | ${AGE}d old")
    elif (( AGE > MAX_AGE * 75 / 100 )); then
      AGE_COLOR=$YELLOW
    else
      AGE_COLOR=$GREEN
    fi

    STATUS_COLOR=$GREEN
    [[ "$status" == "Inactive" ]] && STATUS_COLOR=$YELLOW

    printf "%-22s %-22s ${STATUS_COLOR}%-10s${NC} ${AGE_COLOR}%-12s${NC} %-22s\n" \
      "${USERNAME:0:22}" "${key_id:0:22}" "$status" "${AGE}d" "$LAST_USED"

  done <<< "$KEYS"
done <<< "$USERS"

echo "-------------------------------------------------------------------------------------"
echo ""
echo -e "${CYAN}Summary${NC}"
echo "  Total keys checked  : $TOTAL_KEYS"
echo -e "  Needs rotation (>${MAX_AGE}d): ${RED}${#NEEDS_ROTATION[@]}${NC}"

if [[ ${#NEEDS_ROTATION[@]} -gt 0 ]]; then
  echo ""
  echo -e "${RED}Keys requiring rotation:${NC}"
  for ITEM in "${NEEDS_ROTATION[@]}"; do
    echo "  → $ITEM"
  done

  if [[ -n "$SNS_TOPIC_ARN" ]]; then
    echo ""
    MESSAGE="IAM Access Key Rotation Required

The following keys are older than $MAX_AGE days and need rotation:

$(printf '%s\n' "${NEEDS_ROTATION[@]}")

Please rotate these keys immediately."

    aws sns publish \
      --topic-arn "$SNS_TOPIC_ARN" \
      --subject "IAM Key Rotation Alert: ${#NEEDS_ROTATION[@]} key(s) overdue" \
      --message "$MESSAGE" > /dev/null

    echo -e "${YELLOW} SNS alert sent.${NC}"
  fi
fi
echo "======================================================"
