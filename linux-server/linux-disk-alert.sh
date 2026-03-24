#!/bin/bash
# ============================================================
# Script : linux-disk-alert.sh
# Description : Checks disk usage on all mount points.
#               Sends SNS alert if any partition exceeds the
#               configured threshold.
#               Safe to run every 5-15 minutes via cron.
# Usage  : bash linux-disk-alert.sh <sns-topic-arn> [threshold-%]
# Example: bash linux-disk-alert.sh arn:aws:sns:us-east-1:123:MyTopic 85
# Cron   : */15 * * * * bash /path/to/linux-disk-alert.sh arn:aws:... 85
# ============================================================

set -euo pipefail

SNS_TOPIC_ARN="${1:-}"
THRESHOLD="${2:-85}"
HOSTNAME=$(hostname)

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ -z "$SNS_TOPIC_ARN" ]]; then
  echo "Usage: bash $0 <sns-topic-arn> [threshold-%]"
  echo "Example: bash $0 arn:aws:sns:us-east-1:123456789012:MyTopic 85"
  exit 1
fi

echo ""
echo "======================================================"
echo "         Linux Disk Usage Alert Monitor"
echo "  Host      : $HOSTNAME"
echo "  Threshold : ${THRESHOLD}%"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "======================================================"
echo ""

ALERT_PARTITIONS=()
ALERT_DETAILS=""

# Check all real mount points
while IFS= read -r line; do
  MOUNT=$(echo "$line" | awk '{print $6}')
  SIZE=$(echo "$line"  | awk '{print $2}')
  USED=$(echo "$line"  | awk '{print $3}')
  AVAIL=$(echo "$line" | awk '{print $4}')
  PCT=$(echo "$line"   | awk '{print $5}' | tr -d '%')

  if (( PCT >= THRESHOLD )); then
    echo -e "  ${RED} ALERT ${PCT}%${NC}  $MOUNT  (Used: $USED / $SIZE, Avail: $AVAIL)"
    ALERT_PARTITIONS+=("$MOUNT")
    ALERT_DETAILS+="  $MOUNT: ${PCT}% used (Used: $USED / $SIZE, Free: $AVAIL)\n"
  elif (( PCT >= THRESHOLD * 85 / 100 )); then
    echo -e "  ${YELLOW} WARNING ${PCT}%${NC}  $MOUNT  (Used: $USED / $SIZE, Avail: $AVAIL)"
  else
    echo -e "  ${GREEN} OK ${PCT}%${NC}          $MOUNT  (Used: $USED / $SIZE, Avail: $AVAIL)"
  fi

done < <(df -h --output=target,size,used,avail,pcent | grep -v tmpfs | grep -v "Use%" | grep -v "^udev")

if [[ ${#ALERT_PARTITIONS[@]} -gt 0 ]]; then
  echo ""
  echo -e "${RED}Sending SNS alert for ${#ALERT_PARTITIONS[@]} partition(s)...${NC}"

  MESSAGE="[Disk Alert] $HOSTNAME — Disk Usage Exceeded ${THRESHOLD}%

The following partitions have exceeded the ${THRESHOLD}% threshold:

$(echo -e "$ALERT_DETAILS")
Time: $(date '+%Y-%m-%d %H:%M:%S')

Full disk report:
$(df -h --output=target,size,used,avail,pcent | grep -v tmpfs)"

  aws sns publish \
    --topic-arn "$SNS_TOPIC_ARN" \
    --subject "[Disk Alert] $HOSTNAME — ${#ALERT_PARTITIONS[@]} partition(s) above ${THRESHOLD}%" \
    --message "$MESSAGE" > /dev/null

  echo -e "${YELLOW} SNS alert sent.${NC}"
else
  echo ""
  echo -e "${GREEN} All partitions within limits.${NC}"
fi

echo "======================================================"
