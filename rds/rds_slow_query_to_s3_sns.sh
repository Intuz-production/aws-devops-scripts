#!/bin/bash

# ============================================================
# Script : rds_slow_query_to_s3_sns.sh
# Description : Fetches MySQL slow query logs from RDS, exports to S3, and sends an SNS notification.
# ============================================================

# AWS RDS instance identifier
RDS_INSTANCE=""

# AWS S3 bucket name
S3_BUCKET=""

# AWS region
AWS_REGION=""

# Directory where logs will be temporarily stored
LOG_DIR="/tmp/slowquerylogs"

# Ensure log directory exists
mkdir -p $LOG_DIR

# Initialize a variable to store uploaded log file names
UPLOADED_LOG_FILES=""

# Check logs for the last 6 hours
for i in {0..5}; do
    # Calculate the timestamp for each of the past 6 hours
    TIMESTAMP=$(date -u -d "$i hours ago" +%Y-%m-%d.%k | sed 's/ //g')
    
    # AWS CLI command to download the RDS slow query log
    aws rds download-db-log-file-portion \
        --db-instance-identifier $RDS_INSTANCE \
        --log-file-name slowquery/mysql-slowquery.log.$TIMESTAMP \
        --output text > $LOG_DIR/mysql-slowquery.log.$TIMESTAMP
    
    # Check if the downloaded log file exists and is > 2.4 KB
    LOG_FILE="$LOG_DIR/mysql-slowquery.log.$TIMESTAMP"
    
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt 2400 ]; then
        echo "Uploading $LOG_FILE to S3 bucket $S3_BUCKET"
        aws s3 cp $LOG_FILE s3://$S3_BUCKET/
        
        # Append the uploaded log file name to the list
        UPLOADED_LOG_FILES="$UPLOADED_LOG_FILES mysql-slowquery.log.$TIMESTAMP,"
    else
        echo "No log file downloaded because file size is <= 2.4 KB or file does not exist"
    fi

    # Clean up: remove downloaded log file
    rm -f $LOG_FILE
done

# Check if there are any uploaded log files
if [ -n "$UPLOADED_LOG_FILES" ]; then
    # Remove the trailing comma
    UPLOADED_LOG_FILES=${UPLOADED_LOG_FILES%,}
    
    # Send email notification via SNS
    TOPIC_ARN=""
    MESSAGE=" The files $UPLOADED_LOG_FILES have been uploaded to S3 bucket $S3_BUCKET.  Please review the log files and optimize the queries."
    aws sns publish --topic-arn $TOPIC_ARN --message "$MESSAGE"
fi
