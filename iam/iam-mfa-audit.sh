#!/bin/bash
# ============================================================
# Script : iam-mfa-audit.sh
# Description : Identifies all IAM users who do NOT have MFA
#               enabled. Optionally sends an SNS alert with
#               the list of non-compliant users.
# Usage  : bash iam-mfa-audit.sh [sns-topic-arn]
# Example: bash iam-mfa-audit.sh
#          bash iam-mfa-audit.sh arn:aws:sns:us-east-1:123456789:MyTopic
# ============================================================

set -euo pipefail

SNS_TOPIC_ARN="${1:-}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo "======================================================"
echo "           IAM MFA Compliance Audit"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "======================================================"
echo ""

USERS=$(aws iam list-users \
  --query 'Users[*].[UserName,CreateDate,PasswordLastUsed]' \
  --output text)

if [[ -z "$USERS" ]]; then
  echo "No IAM users found."
  exit 0
fi

NO_MFA_USERS=()
MFA_USERS=()

while IFS=$'\t' read -r username created last_login; do
  MFA_COUNT=$(aws iam list-mfa-devices \
    --user-name "$username" \
    --query 'length(MFADevices)' \
    --output text 2>/dev/null || echo "0")

  created_label=$(echo "$created" | cut -c1-10)
  login_label=$(echo "${last_login:-Never}" | cut -c1-10)

  if [[ "$MFA_COUNT" -gt 0 ]]; then
    MFA_USERS+=("$username")
    printf "  ${GREEN} MFA Enabled${NC}   %-25s  Created: %s  Last Login: %s \n" \
      "$username" "$created_label" "$login_label"
  else
    NO_MFA_USERS+=("$username")
    printf "  ${RED} NO MFA      ${NC}   %-25s  Created: %s  Last Login: %s \n" \
      "$username" "$created_label" "$login_label"
  fi

done <<< "$USERS"

echo ""
echo "======================================================"
echo -e "${CYAN}Summary${NC}"
echo "  Total users      : $(( ${#MFA_USERS[@]} + ${#NO_MFA_USERS[@]} ))"
echo -e "  MFA Enabled      : ${GREEN}${#MFA_USERS[@]}${NC}"
echo -e "  MFA NOT Enabled  : ${RED}${#NO_MFA_USERS[@]}${NC}"
echo "======================================================"

if [[ ${#NO_MFA_USERS[@]} -gt 0 ]]; then
  echo ""
  echo -e "${RED}Users without MFA:${NC}"
  for u in "${NO_MFA_USERS[@]}"; do
    echo "  → $u"
  done

  if [[ -n "$SNS_TOPIC_ARN" ]]; then
    echo ""
    MESSAGE="IAM MFA Compliance Alert

The following IAM users do NOT have MFA enabled:

$(printf '  - %s\n' "${NO_MFA_USERS[@]}")

Please enforce MFA for all users immediately.
Checked at: $(date '+%Y-%m-%d %H:%M:%S')"

    aws sns publish \
      --topic-arn "$SNS_TOPIC_ARN" \
      --subject "IAM MFA Alert: ${#NO_MFA_USERS[@]} user(s) without MFA" \
      --message "$MESSAGE" > /dev/null

    echo -e "${YELLOW} SNS alert sent.${NC}"
  fi
fi
