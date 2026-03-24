#!/bin/bash

# ============================================================
# Script : get_rds_top_sql_queries.sh
# Description : Extracts the top DB load queries via RDS Performance Insights API.
# ============================================================

# Set your AWS region and RDS instance identifier
AWS_REGION="your-aws-region"
DB_INSTANCE_IDENTIFIER="your-db-instance-id"

# Get the current timestamp and calculate 15 minutes ago
END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
START_TIME=$(date -u -d "15 minutes ago" +"%Y-%m-%dT%H:%M:%SZ")

# Fetch the SQL statements
result=$(aws pi get-resource-metrics \
  --region "$AWS_REGION" \
  --service-type RDS \
  --identifier "$DB_INSTANCE_IDENTIFIER" \
  --metric-queries '[
    {
      "Metric": "db.load.avg",
      "GroupBy": {"Group": "db.sql_tokenized", "Limit": 10}
    }
  ]' \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period-in-seconds 60 \
  --output json)

# Check if the result is empty or null
if [ -z "$result" ] || [ "$result" == "null" ]; then
  echo "Error: No data returned from AWS CLI command."
  echo "Please check your AWS credentials, region, and RDS instance identifier."
  exit 1
fi

# Print raw JSON for debugging
echo "Raw JSON output:"
echo "$result"
echo

# Process the result with jq, focusing on db.sql.statement and adding error handling
echo "Processed output:"
echo "$result" | jq -r '
  if . == null then
    "Error: Null response from AWS CLI"
  elif .MetricList == null then
    "Error: MetricList is null"
  elif (.MetricList | type) != "array" then
    "Error: MetricList is not an array. Type: \(.MetricList | type)"
  elif .MetricList | length == 0 then
    "Error: MetricList is empty"
  elif .MetricList[0].GroupList == null then
    "Error: GroupList is null"
  elif (.MetricList[0].GroupList | type) != "array" then
    "Error: GroupList is not an array. Type: \(.MetricList[0].GroupList | type)"
  elif .MetricList[0].GroupList | length == 0 then
    "Error: GroupList is empty"
  else
    .MetricList[0].GroupList[] | 
    if .Dimensions."db.sql.statement" then
      "SQL: \(.Dimensions."db.sql.statement")"
    else
      "Error: No db.sql.statement found in this group"
    end
  end
'

