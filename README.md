# AWS DevOps Scripts for Automation, Monitoring and Security

This library is maintained by [Intuz](https://www.intuz.com) — an AI-first software development company specializing in [AWS Cloud Consulting](https://www.intuz.com/cloud)
and [DevOps Services](https://www.intuz.com/agile-devops-services).
<br><br>

This repository contains a curated collection of Shell and Python scripts to automate, monitor, and secure AWS infrastructure and Linux servers.

All scripts follow DevOps best practices, avoid hardcoded credentials, and are designed to integrate easily into production environments.

## What This Repository Helps You Achieve

Managing AWS and Linux environments often involves repetitive scripting, cost tracking, security checks, and operational firefighting.

This repository helps you:

- Automate routine DevOps and cloud operations
- Reduce AWS costs across S3, RDS, and CloudWatch
- Improve security with IAM audits and access controls
- Monitor infrastructure health and system performance
- Respond faster to incidents with ready-to-use scripts

Instead of building scripts from scratch, you can use this collection to standardize and scale your operations.

## What You’ll Find Here

A practical collection of AWS and Linux automation scripts built for real-world DevOps use cases.

### Key Features
- AWS automation scripts for S3, RDS, IAM, EC2, and CloudWatch
- Linux server monitoring and maintenance scripts
- Cost optimization and cleanup utilities
- Security auditing and compliance checks
- Production-ready and easy to customize

## Repository Structure

Scripts are organized by AWS services and system operations.

### s3/ - Amazon S3 Automation Scripts
- s3-public-access-audit.sh - Detect and fix public bucket access
- s3-sync-buckets.sh - Sync data across buckets and regions
- s3-bucket-size-report.sh - Analyze bucket size and usage
- s3-empty-and-delete-bucket.sh - Safely delete buckets with versions
- s3-presign-url.sh - Generate secure temporary access URLs
- s3-enable-versioning.sh - Enable versioning across buckets
- s3-lifecycle-apply.sh - Apply lifecycle rules for cost optimization

### rds/ - Amazon RDS Automation Scripts
- rds-instance-status-report.sh - View database status and configuration
- rds-snapshot-report.sh - Identify unused snapshots
- rds-auto-snapshot-cleanup.sh - Remove outdated snapshots
- rds-start-stop.sh - Start or stop RDS instances in bulk
- get_rds_top_sql_queries.sh / rds_top_sql_to_jira.sh - Detect slow queries and log to Jira
- rds-connection-alert.sh - Monitor and alert on DB connections

### iam/ - AWS IAM Security Scripts
- iam-user-report.sh - Audit users and access keys
- iam-access-key-audit.sh - Detect unused or old keys
- iam-mfa-audit.sh - Identify users without MFA
- iam-inactive-user-cleanup.sh - Disable inactive users
- iam-role-policy-report.sh - Review IAM roles and permissions
- iam-rotate-access-key.sh - Rotate access keys safely
- iam-policy-wildcard-audit.sh - Detect overly permissive policies

### cloudwatch/ - Monitoring and Cost Optimization
- cw-cost-estimate.sh - Estimate CloudWatch logging costs
- cw-set-log-retention.sh - Apply retention policies
- cw-export-logs-to-s3.sh - Export logs to S3 for storage
- setup_cloudwatch_agent.sh - Install and configure monitoring agent

### linux-server/ - Linux Automation and Monitoring
- linux-system-health-report.sh - Check CPU, memory, disk, and load
- linux-disk-cleanup.sh - Clean unused files and free space
- linux-cache-manager.sh - Optimize memory usage
- linux-memory-alert.sh / linux-disk-alert.sh - Alert on resource limits
- linux-service-monitor.sh - Restart failed services automatically
- linux-user-audit.sh - Audit users and permissions
- setup_swap_memory.sh - Configure swap memory

### ec2-ami/ - EC2 Backup and Migration
- backup_ami_to_s3.sh - Export AMIs to S3
- import_ami_from_s3.sh - Restore AMIs from S3

## Getting Started

### Clone the Repository
```bash
git clone https://github.com/yourusername/aws-devops-scripts.git
cd aws-devops-scripts
```

### Make Scripts Executable
```bash
chmod +x */*.sh
```

### Install Dependencies
```bash
# Debian/Ubuntu
sudo apt-get install awscli jq
```

### Configure AWS CLI
```bash
aws configure
```

## Configuration Notes
- No credentials are hardcoded
- Update placeholders such as ARNs, emails, and endpoints
- Review scripts before using in production

## About Intuz

Intuz helps companies design, build, and scale cloud infrastructure with a strong focus on DevOps, automation, and cost optimization.

If you are looking to:
- Optimize your AWS costs
- Improve DevOps processes
- Build scalable cloud architecture
- Automate infrastructure and operations

You can reach out to the Intuz team for consulting and implementation support.

# License

Copyright (c) 2026 Intuz Solutions Pvt Ltd.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

<h1></h1>
<a href="http://www.intuz.com">
<img src="Screenshots/Logo3.png">
</a>
