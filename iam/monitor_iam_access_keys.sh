#!/bin/bash

# ============================================================
# Script : monitor_iam_access_keys.sh
# Description : Tracks age of IAM access keys and triggers alerts for key rotation policies.
# ============================================================

# Define variables
ALERT_DAYS=180      # Number of days after which the key should be rotated
SNS_TOPIC_ARN=""  # Replace with your SNS topic ARN
PROJECT_NAME=""  # Replace with your project name
USERNAMES=("" "")  # IAM usernames to check

# Get the current date in Unix timestamp format
current_date=$(date +%s)

# Initialize a variable to store the alert message
alert_message="This is a reminder to rotate your IAM access keys."
key_info=""

for USERNAME in "${USERNAMES[@]}"; do
    # Get access keys for the specified user
    keys=$(aws iam list-access-keys --user-name "$USERNAME" --query 'AccessKeyMetadata[*].[AccessKeyId,CreateDate]' --output text)

    while read -r key_id create_date; do
        # Convert create date to Unix timestamp format
        key_create_date=$(date -d "$create_date" +%s)
        
        # Calculate the age of the access key in days
        age_days=$(( (current_date - key_create_date) / (60*60*24) ))
        
        # Check if the access key is older than the threshold
        if [ "$age_days" -gt "$ALERT_DAYS" ]; then
            key_info+="IAM User $USERNAME access key ID: $key_id is $age_days days old and "
        fi
    done <<< "$keys"
done

# Remove the trailing "and " and add the final message part
key_info="${key_info% and }"
alert_message+="In $PROJECT_NAME project $key_info so please rotate it."

# Send an alert if there are any keys that need rotation
if [ -n "$key_info" ]; then
    aws sns publish --topic-arn "$SNS_TOPIC_ARN" --message "$alert_message" --subject "IAM Access Key Rotation Reminder"
fi
