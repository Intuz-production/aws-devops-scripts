#!/bin/bash
# ============================================================
# Script : linux-system-health-report.sh
# Description : Prints a complete server health snapshot:
#               CPU, Memory, Disk, Load, Network, Uptime,
#               Top processes, and Running services.
# Usage  : bash linux-system-health-report.sh
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

warn_if_high() {
  local val="$1"
  local threshold="$2"
  local int_val="${val%.*}"
  if (( int_val >= threshold )); then
    echo -e "${RED}${val}%${NC}"
  elif (( int_val >= threshold * 75 / 100 )); then
    echo -e "${YELLOW}${val}%${NC}"
  else
    echo -e "${GREEN}${val}%${NC}"
  fi
}

echo ""
echo -e "${BOLD}======================================================"
echo "          Linux Server Health Report"
echo "  Host  : $(hostname)"
echo "  Date  : $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "======================================================${NC}"

# --- Uptime & Load ---
echo ""
echo -e "${CYAN} Uptime & Load${NC}"
uptime_str=$(uptime -p)
load=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
cpus=$(nproc)
echo "  Uptime : $uptime_str"
echo "  Load   : $load  (CPUs: $cpus)"

# --- CPU ---
echo ""
echo -e "${CYAN} CPU Usage${NC}"
cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | tr -d '%id,')
cpu_used=$(echo "100 - $cpu_idle" | bc 2>/dev/null || echo "N/A")
echo -n "  Usage  : "
warn_if_high "$cpu_used" 80

# --- Memory ---
echo ""
echo -e "${CYAN} Memory${NC}"
read -r total used free shared buff_cache available <<< \
  $(free -m | awk 'NR==2{print $2,$3,$4,$5,$6,$7}')
mem_pct=$(echo "scale=1; $used * 100 / $total" | bc)
echo "  Total     : ${total} MB"
echo -n "  Used      : ${used} MB ("
warn_if_high "$mem_pct" 85
echo "  Available : ${available} MB"
echo "  Buff/Cache: ${buff_cache} MB"

# --- Swap ---
echo ""
echo -e "${CYAN} Swap${NC}"
swap_info=$(free -m | awk 'NR==3{print $2, $3, $4}')
read -r swap_total swap_used swap_free <<< "$swap_info"
if (( swap_total > 0 )); then
  swap_pct=$(echo "scale=1; $swap_used * 100 / $swap_total" | bc)
  echo "  Total : ${swap_total} MB"
  echo -n "  Used  : ${swap_used} MB ("
  warn_if_high "$swap_pct" 50
else
  echo "  No swap configured"
fi

# --- Disk ---
echo ""
echo -e "${CYAN} Disk Usage${NC}"
df -h --output=target,size,used,avail,pcent | grep -v tmpfs | tail -n +2 | while read -r mount size used avail pct; do
  pct_num="${pct//%/}"
  printf "  %-20s  Size:%-8s Used:%-8s Avail:%-8s " "$mount" "$size" "$used" "$avail"
  warn_if_high "$pct_num" 85
done

# --- Network ---
echo ""
echo -e "${CYAN} Network Interfaces${NC}"
ip -brief addr show | awk '{printf "  %-12s %-12s %s\n", $1, $2, $3}'

# --- Top 5 CPU Processes ---
echo ""
echo -e "${CYAN} Top 5 CPU Processes${NC}"
ps aux --sort=-%cpu | awk 'NR>1 && NR<=6 {printf "  %-8s %-6s %-6s %s\n", $1, $3"%", $4"%", $11}' | \
  awk 'BEGIN{printf "  %-8s %-6s %-6s %s\n","USER","CPU","MEM","COMMAND"} {print}'

# --- Top 5 Memory Processes ---
echo ""
echo -e "${CYAN} Top 5 Memory Processes${NC}"
ps aux --sort=-%mem | awk 'NR>1 && NR<=6 {printf "  %-8s %-6s %-6s %s\n", $1, $3"%", $4"%", $11}' | \
  awk 'BEGIN{printf "  %-8s %-6s %-6s %s\n","USER","CPU","MEM","COMMAND"} {print}'

# --- Failed Services ---
echo ""
echo -e "${CYAN} Failed Systemd Services${NC}"
FAILED=$(systemctl list-units --state=failed --no-legend 2>/dev/null | awk '{print $1}')
if [[ -z "$FAILED" ]]; then
  echo -e "  ${GREEN} No failed services${NC}"
else
  echo -e "  ${RED}Failed services:${NC}"
  echo "$FAILED" | while read -r svc; do echo "  → $svc"; done
fi

echo ""
echo "======================================================"
