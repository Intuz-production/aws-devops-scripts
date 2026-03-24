#!/bin/bash
# ============================================================
# Script : iam-inactive-user-cleanup.sh
# Description : Finds IAM users who have never logged in OR
#               haven't logged in for N days. Lists them and
#               optionally disables their console access and
#               deactivates access keys.
# Usage  : bash iam-inactive-user-cleanup.sh [days] [--disable]
# Example: bash iam-inactive-user-cleanup.sh 90
#          bash iam-inactive-user-cleanup.sh 90 --disable
# ============================================================

set -euo pipefail

INACTIVE_DAYS="${1:-90}"
ACTION="${2:-}"
NOW=$(date +%s)

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

DISABLE_MODE=false
[[ "$ACTION" == "--disable" ]] && DISABLE_MODE=true

echo ""
echo "======================================================"
echo "         IAM Inactive User Cleanup"
echo "  Inactive threshold : $INACTIVE_DAYS days"
echo -e "  Mode               : $([ "$DISABLE_MODE" = true ] && echo "${RED}DISABLE MODE${NC}" || echo "${YELLOW}REPORT ONLY${NC}")"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "======================================================"
echo ""

USERS=$(aws iam list-users \
  --query 'Users[*].[UserName,CreateDate,PasswordLastUsed]' \
  --output text)

INACTIVE_USERS=()

while IFS=$'\t' read -r username created last_login; do
  last_login="${last_login:-None}"

  # Calculate inactivity
  if [[ "$last_login" == "None" ]]; then
    CREATE_TS=$(date -d "$created" +%s)
    DAYS_INACTIVE=$(( (NOW - CREATE_TS) / 86400 ))
    REASON="Never logged in (created ${DAYS_INACTIVE}d ago)"
  else
    LAST_TS=$(date -d "$last_login" +%s)
    DAYS_INACTIVE=$(( (NOW - LAST_TS) / 86400 ))
    REASON="Last login ${DAYS_INACTIVE}d ago"
  fi

  if (( DAYS_INACTIVE > INACTIVE_DAYS )); then
    INACTIVE_USERS+=("$username")
    echo -e "  ${RED}INACTIVE${NC}  $username"
    echo "            $REASON"

    if [[ "$DISABLE_MODE" == true ]]; then
      # Delete login profile (console access)
      aws iam delete-login-profile --user-name "$username" 2>/dev/null && \
        echo -e "            ${YELLOW}→ Console access removed${NC}" || true

      # Deactivate all access keys
      KEYS=$(aws iam list-access-keys \
        --user-name "$username" \
        --query 'AccessKeyMetadata[?Status==`Active`].AccessKeyId' \
        --output text 2>/dev/null || true)

      for KEY_ID in $KEYS; do
        aws iam update-access-key \
          --user-name "$username" \
          --access-key-id "$KEY_ID" \
          --status Inactive
        echo -e "            ${YELLOW}→ Access key $KEY_ID deactivated${NC}"
      done
    fi
    echo ""
  fi
done <<< "$USERS"

echo "======================================================"
echo -e "${CYAN}Summary${NC}"
echo "  Inactive users found : ${#INACTIVE_USERS[@]}"

if [[ ${#INACTIVE_USERS[@]} -eq 0 ]]; then
  echo -e "  ${GREEN}All users are active within $INACTIVE_DAYS days.${NC}"
elif [[ "$DISABLE_MODE" == false ]]; then
  echo ""
  echo -e "  ${YELLOW}Run with --disable to remove console access & deactivate keys.${NC}"
  echo "  Example: bash $0 $INACTIVE_DAYS --disable"
fi
echo "======================================================"
