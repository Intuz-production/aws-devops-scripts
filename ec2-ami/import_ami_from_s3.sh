#!/bin/bash

# ============================================================
# Script : import_ami_from_s3.sh
# Description : Restores an exported AMI backup (.bin) from an S3 bucket back into an EC2 AMI.
# ============================================================

# Colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_success() {
    echo -e "${GREEN} $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_error() {
    echo -e "${RED} $1${NC}"
}

print_warning() {
    echo -e "${YELLOW} $1${NC}"
}

# Function to check if S3 object exists
check_s3_object_exists() {
    local bucket=$1
    local key=$2
    aws s3 ls "s3://${bucket}/${key}" &>/dev/null
    return $?
}

# Function to list .bin files in S3 bucket
list_bin_files() {
    local bucket=$1
    local folder=$2
    
    print_info "Searching for .bin files in s3://${bucket}/${folder}"
    echo ""
    
    if [ -n "$folder" ]; then
        aws s3 ls "s3://${bucket}/${folder}" --recursive | grep "\.bin$" | awk '{print $4}'
    else
        aws s3 ls "s3://${bucket}/" --recursive | grep "\.bin$" | awk '{print $4}'
    fi
}

# Function to restore AMI from S3
restore_ami_from_s3() {
    local bucket=$1
    local object_key=$2
    local ami_name=$3
    
    print_info "Starting AMI restore from S3"
    print_info "Bucket: $bucket"
    print_info "Object: $object_key"
    
    # Check if S3 object exists
    if ! check_s3_object_exists "$bucket" "$object_key"; then
        print_error "S3 object 's3://${bucket}/${object_key}' not found"
        return 1
    fi
    
    print_success "S3 object found"
    
    # Create restore image task
    print_info "Creating restore image task..."
    
    if [ -n "$ami_name" ]; then
        result=$(aws ec2 create-restore-image-task \
            --object-key "$object_key" \
            --bucket "$bucket" \
            --name "$ami_name" 2>&1)
    else
        result=$(aws ec2 create-restore-image-task \
            --object-key "$object_key" \
            --bucket "$bucket" 2>&1)
    fi
    
    if [ $? -ne 0 ]; then
        print_error "Failed to create restore image task"
        echo "$result"
        return 1
    fi
    
    print_success "Restore image task created successfully"
    
    # Extract the AMI ID from the result
    ami_id=$(echo "$result" | grep -o '"ImageId": "[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$ami_id" ]; then
        print_warning "Could not extract AMI ID from response"
        echo "$result"
        ami_id="unknown"
    else
        print_success "AMI ID: $ami_id"
    fi
    
    print_info "Waiting for AMI to be available (this may take 10-30 minutes)..."
    echo ""
    
    # Wait for the AMI to be available
    if [ "$ami_id" != "unknown" ]; then
        counter=0
        while true; do
            state=$(aws ec2 describe-images --image-ids "$ami_id" --query 'Images[0].State' --output text 2>/dev/null)
            
            if [ "$state" = "available" ]; then
                echo ""
                print_success "AMI is now available!"
                break
            elif [ "$state" = "failed" ]; then
                echo ""
                print_error "AMI creation failed!"
                aws ec2 describe-images --image-ids "$ami_id"
                return 1
            elif [ -z "$state" ] || [ "$state" = "None" ]; then
                echo -n "."
                sleep 30
            else
                echo -n "."
                sleep 30
            fi
            
            counter=$((counter + 1))
            if [ $counter -gt 120 ]; then
                echo ""
                print_warning "Timeout waiting for AMI. Please check manually."
                break
            fi
        done
    else
        print_info "Please check AWS console for restore progress"
    fi
    
    echo ""
    print_success "Restore completed!"
    echo ""
    echo "AMI Details:"
    if [ "$ami_id" != "unknown" ]; then
        aws ec2 describe-images --image-ids "$ami_id" --output table
    fi
    
    return 0
}

# Main script
echo -e "${BLUE}"
echo "=================================="
echo "  S3 BIN to AMI Import Tool"
echo "=================================="
echo -e "${NC}"

# Main loop
while true; do
    echo ""
    print_info "Enter S3 details (or type 'exit' to quit)"
    echo ""
    
    # Get S3 bucket name
    read -p "Enter S3 bucket name (e.g., my-ami-backup-bucket): " bucket
    
    # Check if user wants to exit
    if [ "$bucket" = "exit" ] || [ "$bucket" = "quit" ]; then
        print_info "Exiting script. Goodbye!"
        exit 0
    fi
    
    if [ -z "$bucket" ]; then
        print_error "Bucket name cannot be empty"
        continue
    fi
    
    # Ask if user wants to see available .bin files
    read -p "Do you want to see available .bin files in this bucket? (y/n): " show_files
    
    if [ "$show_files" = "y" ] || [ "$show_files" = "Y" ]; then
        read -p "Enter folder path (optional, press Enter for root): " folder
        echo ""
        list_bin_files "$bucket" "$folder"
        echo ""
    fi
    
    # Get object key (file path)
    echo "Enter the full object key (file path in S3)"
    echo "Examples:"
    echo "  - ami-0e8f39c2553636135.bin"
    echo "  - project-name/ami-0e8f39c2553636135.bin"
    echo "  - backup/2024/my-server.bin"
    echo ""
    read -p "Object key: " object_key
    
    if [ -z "$object_key" ]; then
        print_error "Object key cannot be empty"
        continue
    fi
    
    # Get AMI name (optional)
    read -p "Enter a name for the new AMI (optional, press Enter to skip): " ami_name
    
    # Confirm before proceeding
    echo ""
    print_warning "Please confirm:"
    echo "  S3 Bucket: $bucket"
    echo "  Object Key: $object_key"
    echo "  Full Path: s3://${bucket}/${object_key}"
    if [ -n "$ami_name" ]; then
        echo "  AMI Name: $ami_name"
    else
        echo "  AMI Name: (auto-generated)"
    fi
    echo ""
    
    read -p "Proceed with restore? (y/n): " confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_info "Restore cancelled"
        continue
    fi
    
    # Restore AMI
    restore_ami_from_s3 "$bucket" "$object_key" "$ami_name"
    
    if [ $? -eq 0 ]; then
        print_success "AMI restore completed successfully!"
    else
        print_error "AMI restore failed. Please check the errors above."
    fi
    
    echo ""
    echo "=================================="
    read -p "Do you want to restore another AMI? (y/n): " another
    
    if [ "$another" != "y" ] && [ "$another" != "Y" ]; then
        print_info "Exiting script. Goodbye!"
        exit 0
    fi
done
