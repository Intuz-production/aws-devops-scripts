#!/bin/bash

# ============================================================
# Script : setup_cloudwatch_agent.sh
# Description : Automated installation and configuration of the Amazon CloudWatch Agent on Debian/Ubuntu systems.
# ============================================================

# Download the CloudWatch agent package
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb

sudo dpkg --remove amazon-cloudwatch-agent
sudo dpkg --purge amazon-cloudwatch-agent


# Install the CloudWatch agent
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb

# Open the CloudWatch agent configuration file for editing
sudo touch /opt/aws/amazon-cloudwatch-agent/bin/config.json

# Add the provided configuration to the file
cat <<EOF | sudo tee -a /opt/aws/amazon-cloudwatch-agent/bin/config.json
{
        "agent": {
                "metrics_collection_interval": 60,
                "run_as_user": "root"
        },
        "metrics": {
                "aggregation_dimensions": [
                        [
                                "InstanceId"
                        ]
                ],
                "append_dimensions": {
                        "ImageId": "\${aws:ImageId}",
                        "InstanceId": "\${aws:InstanceId}",
                        "InstanceType": "\${aws:InstanceType}"
                },
                "metrics_collected": {
                        "disk": {
                                "measurement": [
                                        "used_percent"
                                ],
                                "metrics_collection_interval": 60,
                                "resources": [
                                        "/"
                                ]
                        },
                        "mem": {
                                "measurement": [
                                        "mem_used_percent"
                                ],
                                "metrics_collection_interval": 60
                        }
                }
        }
}
EOF

# Fetch and apply the configuration
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json

service amazon-cloudwatch-agent status
