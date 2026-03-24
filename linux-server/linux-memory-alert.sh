#!/bin/bash
# ============================================================
# Script : linux-memory-alert.sh
# Description : Monitors memory and swap usage. Sends an SNS
#               alert if usage exceeds configured thresholds.
#               Shows top 5 memory consumers.
#               Designed to run every N minutes via cron.
# Usage  : bash linux-memory-alert.sh <sns-topic-arn> [mem-%] [swap-%]
# Example: bash linux-memory-alert.sh arn:aws:sns:us-east-1:123:MyTopic 85 70
# Cron   : */5 * * * * bash /path/to/linux-memory-alert.sh arn:aws:... 85 70
# ============================================================

set -euo pipefail

SNS_TOPIC_ARN="${1:-}"
MEM_THRESHOLD="${2:-85}"
SWAP_THRESHOLD="${3:-70}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ -z "$SNS_TOPIC_ARN" ]]; then
  echo "Usage: bash $0 <sns-topic-arn> [mem-threshold-%] [swap-threshold-%]"
  echo "Example: bash $0 arn:aws:sns:us-east-1:123456789012:MyTopic 85 70"
  exit 1
fi

HOSTNAME=$(hostname)

# Memory stats
read -r MEM_TOTAL MEM_USED MEM_FREE MEM_AVAILABLE <<< \
  $(free -m | awk 'NR==2{print $2, $3, $4, $7}')
MEM_PCT=$(echo "scale=1; $MEM_USED * 100 / $MEM_TOTAL" | bc)

# Swap stats
read -r SWAP_TOTAL SWAP_USED SWAP_FREE <<< \
  $(free -m | awk 'NR==3{print $2, $3, $4}')
SWAP_PCT=0
if (( SWAP_TOTAL > 0 )); then
  SWAP_PCT=$(echo "scale=1; $SWAP_USED * 100 / $SWAP_TOTAL" | bc)
fi

# Top 5 memory consumers
TOP5=$(ps aux --sort=-%mem | awk 'NR>1 && NR<=6 {printf "  %-6s %-8s %s\n", $4"%", $1, $11}')

echo ""
echo "======================================================"
echo "       Linux Memory Alert Monitor"
echo "  Host       : $HOSTNAME"
echo "  Memory     : ${MEM_USED}MB / ${MEM_TOTAL}MB (${MEM_PCT}%)"
echo "  Swap       : ${SWAP_USED}MB / ${SWAP_TOTAL}MB (${SWAP_PCT}%)"
echo "  Thresholds : Mem=${MEM_THRESHOLD}%  Swap=${SWAP_THRESHOLD}%"
echo "======================================================"
echo ""

MEM_INT="${MEM_PCT%.*}"
SWAP_INT="${SWAP_PCT%.*}"
ALERT=false
ALERT_REASONS=""

if (( MEM_INT >= MEM_THRESHOLD )); then
  ALERT=true
  ALERT_REASONS+="Memory usage is ${MEM_PCT}% (threshold: ${MEM_THRESHOLD}%)\n"
  echo -e "${RED}  ALERT: High memory usage: ${MEM_PCT}%${NC}"
else
  echo -e "${GREEN} Memory OK: ${MEM_PCT}% (threshold: ${MEM_THRESHOLD}%)${NC}"
fi

if (( SWAP_TOTAL > 0 && SWAP_INT >= SWAP_THRESHOLD )); then
  ALERT=true
  ALERT_REASONS+="Swap usage is ${SWAP_PCT}% (threshold: ${SWAP_THRESHOLD}%)\n"
  echo -e "${RED}  ALERT: High swap usage: ${SWAP_PCT}%${NC}"
elif (( SWAP_TOTAL > 0 )); then
  echo -e "${GREEN} Swap OK: ${SWAP_PCT}% (threshold: ${SWAP_THRESHOLD}%)${NC}"
fi

if [[ "$ALERT" == true ]]; then
  MESSAGE="[Memory Alert] $HOSTNAME

$(echo -e "$ALERT_REASONS")
Memory Stats:
  Total     : ${MEM_TOTAL} MB
  Used      : ${MEM_USED} MB (${MEM_PCT}%)
  Available : ${MEM_AVAILABLE} MB

Swap Stats:
  Total  : ${SWAP_TOTAL} MB
  Used   : ${SWAP_USED} MB (${SWAP_PCT}%)

Top 5 Memory Consumers:
  MEM%   USER     COMMAND
$TOP5

Time: $(date '+%Y-%m-%d %H:%M:%S')"

  aws sns publish \
    --topic-arn "$SNS_TOPIC_ARN" \
    --subject "[Alert] High Memory on $HOSTNAME" \
    --message "$MESSAGE" > /dev/null

  echo ""
  echo -e "${YELLOW} SNS alert sent.${NC}"
fi

echo ""
echo "Top 5 Memory Consumers:"
echo "  MEM%   USER     COMMAND"
echo "$TOP5"
echo "======================================================"
