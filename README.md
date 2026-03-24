# AWS and Linux DevOps Script Library

Welcome to the AWS and Linux DevOps Script Library. This repository contains a curated collection of Shell and Python scripts designed to automate, monitor, and secure your AWS infrastructure and Linux servers.

All scripts are written with best practices in mind, avoiding hardcoded credentials, and are ready to be seamlessly integrated into your daily DevOps workflows.

## Repository Structure

The scripts are organized into categories based on the service they interact with:

### 1. s3/ - Amazon S3 Management
- s3-public-access-audit.sh - Scans all buckets for public access and optionally auto-fixes them.
- s3-sync-buckets.sh - Syncs items across buckets (supports cross-region and dry-runs).
- s3-bucket-size-report.sh - Generates a report showing total sizes and object counts for all buckets.
- s3-empty-and-delete-bucket.sh - Safely purges all objects and versions before deleting a bucket.
- s3-presign-url.sh - Generates secure, temporary download URLs for private S3 objects.
- s3-enable-versioning.sh - Mass-enables versioning for compliance.
- s3-lifecycle-apply.sh - Applies a standard tiered lifecycle storage policy to reduce costs.

### 2. rds/ - Amazon RDS Management
- rds-instance-status-report.sh - Provides a clean table of all database engines, sizes, and Multi-AZ status.
- rds-snapshot-report.sh - Analyzes snapshot ages and highlights those wasting storage.
- rds-auto-snapshot-cleanup.sh - Deletes manual snapshots older than N days to manage costs.
- rds-start-stop.sh - Starts or stops single/multiple RDS instances asynchronously.
- get_rds_top_sql_queries.sh / rds_top_sql_to_jira.sh - Extracts slow/bloated queries and auto-posts them to Jira.
- rds-connection-alert.sh - Monitors DB connection overhead and sends an SNS alert if thresholds are met.

### 3. iam/ - Identity and Access Management
- iam-user-report.sh - Reports all users, their creation date, last login, and associated keys.
- iam-access-key-audit.sh - Audits Access Keys for age and inactivity, firing SNS alerts for overdue rotations.
- iam-mfa-audit.sh - Flags and reports users without MFA enabled.
- iam-inactive-user-cleanup.sh - Checks for inactive users, disables their console access, and invalidates keys.
- iam-role-policy-report.sh - Catalogs IAM roles along with their inline and managed policies.
- iam-rotate-access-key.sh - Safely provides new keys while keeping the old ones active temporarily for smooth application transition.
- iam-policy-wildcard-audit.sh - Finds risky custom policies with Action: * or Resource: *.

### 4. cloudwatch/ - Telemetry and Monitoring
- cw-cost-estimate.sh - Analyzes stored logs to estimate monthly CloudWatch costs.
- cw-set-log-retention.sh - Implements a unified retention policy for log groups natively preventing runaway storage expansion.
- cw-export-logs-to-s3.sh - Automates the export of CloudWatch Logs to S3 for long-term cold storage.
- setup_cloudwatch_agent.sh - Quickly bootstraps the amazon-cloudwatch-agent on generic Linux servers.

### 5. linux-server/ - OS-Level Operations
- linux-system-health-report.sh - Displays a quick server snapshot including CPU, Memory, Disk, Load, and failing Systemd units.
- linux-disk-cleanup.sh - Automatically frees space by purging old caches, logs, temp files, and unused containers.
- linux-cache-manager.sh - Non-destructively cycles OS-level RAM cache limits.
- linux-memory-alert.sh and linux-disk-alert.sh - Lightweight cron-based monitors that SNS alert when Memory/Disk cross safe boundaries.
- linux-service-monitor.sh - Auto-restarts failed Systemd services (e.g. pm2, nginx) and immediately alerts the team.
- linux-user-audit.sh - Finds risky local user accounts (e.g. empty passwords, unchecked sudo privileges).
- setup_swap_memory.sh - Implements and mounts Swap memory gracefully for low-tier instancing.

### 6. ec2-ami/ - Compute Image Backups
- backup_ami_to_s3.sh - Exports AMIs into static .bin files directly to AWS S3.
- import_ami_from_s3.sh - Restores exported AMI backups from S3 into functional EC2 Images.

---

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/aws-devops-scripts.git
   cd aws-devops-scripts
   ```

2. Make scripts executable:
   ```bash
   chmod +x */*.sh
   ```

3. Prerequisites:
   Many of these tools interface directly with the AWS API. Ensure you have the `aws-cli` and `jq` installed on your machine.
   ```bash
   # Debian/Ubuntu
   sudo apt-get install awscli jq
   
   # Confirm Configuration
   aws configure
   ```

4. Variables and Placeholders:
   No hard-coded credentials exist within this repository (keys, emails, etc., have been standardized to your-variable). Before running a script (especially those connecting to SNS or Jira), edit the top lines to match your specific ARNs and endpoints.

---

## Contributing
Contributions, issues, and feature requests are welcome! 
Feel free to check issues page to propose new additions. 

## License
This project is licensed under the MIT License - open for full scale business/personal adoption.
