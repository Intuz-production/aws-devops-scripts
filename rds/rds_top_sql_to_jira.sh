#!/bin/bash

# ============================================================
# Script : rds_top_sql_to_jira.sh
# Description : Identifies high-load queries from RDS and posts the metrics automatically to Jira.
# ============================================================

# Set your AWS region, RDS instance identifier, Jira details, and S3 bucket
AWS_REGION=""
DB_INSTANCE_IDENTIFIER="your-db-instance-id"
JIRA_BASE_URL="https://your-domain.atlassian.net/" 
JIRA_ISSUE_KEY="PROJECT-123"
JIRA_USERNAME="your-email@domain.com"
JIRA_API_TOKEN="your-jira-api-token"
S3_BUCKET_NAME="your-s3-bucket-name"
S3_FILE_KEY="rds_metrics_$(date +'%Y%m%d%H%M%S').json"
JSON_OUTPUT_FILE="output.json"

# Get the current timestamp and calculate 10 minutes ago
END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
START_TIME=$(date -u -d "10 minutes ago" +"%Y-%m-%dT%H:%M:%SZ")

# Fetch the SQL statements and store the result in a JSON log file, with 1-minute granularity
result=$(aws pi get-resource-metrics \
    --region "$AWS_REGION" \
    --service-type RDS \
    --identifier "$DB_INSTANCE_IDENTIFIER" \
    --metric-queries '[
        {
            "Metric": "db.load.avg",
            "GroupBy": {"Group": "db.sql", "Limit": 10}
        }
    ]' \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period-in-seconds 60 \
    --output json)

# Check for AWS CLI errors
if [ $? -ne 0 ]; then
    echo "Error: AWS CLI command failed. Please check your AWS credentials, region, and RDS instance identifier."
    echo "$result"
    exit 1
fi

# Save the result to a JSON file
echo "$result" > "$JSON_OUTPUT_FILE"

# Upload JSON file to S3 with metadata to force download on click
aws s3 cp "$JSON_OUTPUT_FILE" "s3://$S3_BUCKET_NAME/$S3_FILE_KEY" --region "$AWS_REGION" \
    --content-disposition "attachment; filename=\"$S3_FILE_KEY\""

# Generate a presigned URL for the uploaded JSON file (valid for 2 days)
S3_PRESIGNED_URL=$(aws s3 presign "s3://$S3_BUCKET_NAME/$S3_FILE_KEY" --region "$AWS_REGION" --expires-in 259200)

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install jq to pretty-print JSON output."
    echo "Raw JSON output saved in $JSON_OUTPUT_FILE"
    exit 1
fi

# Output pretty-printed JSON for confirmation
echo "Pretty-printed JSON:"
cat "$JSON_OUTPUT_FILE" | jq '.'

# Jira API endpoint for commenting on an issue
JIRA_COMMENT_URL="$JIRA_BASE_URL/rest/api/2/issue/$JIRA_ISSUE_KEY/comment"

# Jira comment content with new lines
JIRA_COMMENT="Hello @,\n\nReceived an alert indicating that CPU utilization on the RDS database has exceeded 80%. This could impact performance, so it's crucial to review and optimize the top SQL queries contributing to the load.\n\n Download the metrics report, which includes the identified queries, here: ($S3_PRESIGNED_URL)"

# Add the comment to Jira using curl
curl -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
     -X POST \
     --data "{\"body\": \"$JIRA_COMMENT\"}" \
     -H "Content-Type: application/json" \
     "$JIRA_COMMENT_URL"

echo "Comment added to Jira issue $JIRA_ISSUE_KEY."

# Output the time range for context
echo -e "\nTime range of data:"
echo "Start Time: $START_TIME"
echo "End Time: $END_TIME"
