#!/bin/bash

# ============================================================
# Script : cw-loggroup-cleanup.sh
# Description : Prunes empty or heavily unutilized CloudWatch Log Groups to keep the console clean.
# ============================================================
# Delete log groups with no activity in X days

DAYS=30

aws logs describe-log-groups --query 'logGroups[*].logGroupName' --output text | tr '\t' '\n' | while read logGroup; do
  lastEvent=$(aws logs describe-log-streams \
    --log-group-name "$logGroup" \
    --order-by LastEventTime --descending \
    --max-items 1 \
    --query 'logStreams[0].lastEventTimestamp' \
    --output text)

  if [[ "$lastEvent" == "None" ]]; then
    echo "Skipping empty log group: $logGroup"
    continue
  fi

  now=$(date +%s%3N)
  diff=$(( (now - lastEvent) / 1000 / 60 / 60 / 24 ))

  if (( diff > DAYS )); then
    echo "Deleting $logGroup (inactive $diff days)"
    aws logs delete-log-group --log-group-name "$logGroup"
  fi
done