#!/bin/bash

# ============================================================
# Script : backup_ami_to_s3.sh
# Description : Exports an existing EC2 AMI to a static .bin file in an AWS S3 bucket for long-term storage.
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

# Function to check if AMI exists
check_ami_exists() {
    local ami_id=$1
    aws ec2 describe-images --image-ids "$ami_id" &>/dev/null
    return $?
}

# Function to check if S3 bucket exists
check_bucket_exists() {
    local bucket=$1
    aws s3 ls "s3://$bucket" &>/dev/null
    return $?
}

# Function to export AMI to S3
export_ami_to_s3() {
    local ami_id=$1
    local bucket=$2
    local folder=$3
    
    print_info "Starting export for AMI: $ami_id"
    
    # Check if AMI exists
    if ! check_ami_exists "$ami_id"; then
        print_error "AMI $ami_id not found or you don't have permission to access it"
        return 1
    fi
    
    # Check if bucket exists
    if ! check_bucket_exists "$bucket"; then
        print_error "S3 bucket '$bucket' not found or you don't have permission to access it"
        return 1
    fi
    
    # Start the store image task
    print_info "Creating store image task..."
    result=$(aws ec2 create-store-image-task --image-id "$ami_id" --bucket "$bucket" 2>&1)
    
    if [ $? -ne 0 ]; then
        print_error "Failed to create store image task"
        echo "$result"
        return 1
    fi
    
    print_success "Store image task created successfully"
    
    # Extract the object key from the result
    object_key=$(echo "$result" | grep -o '"ObjectKey": "[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$object_key" ]; then
        object_key="${ami_id}.bin"
    fi
    
    print_info "Object key: $object_key"
    print_info "Waiting for export to complete (this may take 10-30 minutes)..."
    
    # Wait for the task to complete
    while true; do
        status=$(aws ec2 describe-store-image-tasks --image-ids "$ami_id" --query 'StoreImageTaskResults[0].StoreTaskState' --output text 2>/dev/null)
        
        if [ "$status" = "Completed" ]; then
            print_success "Export completed!"
            break
        elif [ "$status" = "Failed" ]; then
            print_error "Export failed!"
            aws ec2 describe-store-image-tasks --image-ids "$ami_id"
            return 1
        else
            echo -n "."
            sleep 30
        fi
    done
    
    echo ""
    
    # Move to specified folder if provided
    if [ -n "$folder" ]; then
        # Remove trailing slash if present
        folder=${folder%/}
        
        print_info "Moving file to folder: $folder/"
        
        aws s3 mv "s3://${bucket}/${object_key}" "s3://${bucket}/${folder}/${object_key}"
        
        if [ $? -eq 0 ]; then
            print_success "File moved to s3://${bucket}/${folder}/${object_key}"
        else
            print_error "Failed to move file to folder"
            return 1
        fi
    else
        print_success "File stored at s3://${bucket}/${object_key}"
    fi
    
    return 0
}

# Main script
echo -e "${BLUE}"
echo "=================================="
echo "  AMI to S3 Export Tool"
echo "=================================="
echo -e "${NC}"

# Main loop
while true; do
    echo ""
    print_info "Enter AMI details (or type 'exit' to quit)"
    echo ""
    
    # Get AMI ID
    read -p "Enter AMI ID (e.g., ami-0e8f39c2553636135): " ami_id
    
    # Check if user wants to exit
    if [ "$ami_id" = "exit" ] || [ "$ami_id" = "quit" ]; then
        print_info "Exiting script. Goodbye!"
        exit 0
    fi
    
    # Validate AMI ID format
    if [[ ! "$ami_id" =~ ^ami-[a-f0-9]{8,17}$ ]]; then
        print_error "Invalid AMI ID format. Please enter a valid AMI ID (e.g., ami-0e8f39c2553636135)"
        continue
    fi
    
    # Get S3 bucket name
    read -p "Enter S3 bucket name (e.g., my-ami-backup-bucket): " bucket
    
    if [ -z "$bucket" ]; then
        print_error "Bucket name cannot be empty"
        continue
    fi
    
    # Get folder name (optional)
    read -p "Enter folder name in bucket (optional, press Enter to skip): " folder
    
    # Confirm before proceeding
    echo ""
    print_warning "Please confirm:"
    echo "  AMI ID: $ami_id"
    echo "  S3 Bucket: $bucket"
    if [ -n "$folder" ]; then
        echo "  Folder: $folder/"
    else
        echo "  Folder: (root of bucket)"
    fi
    echo ""
    
    read -p "Proceed with export? (y/n): " confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_info "Export cancelled"
        continue
    fi
    
    # Export AMI
    export_ami_to_s3 "$ami_id" "$bucket" "$folder"
    
    if [ $? -eq 0 ]; then
        print_success "AMI export completed successfully!"
    else
        print_error "AMI export failed. Please check the errors above."
    fi
    
    echo ""
    echo "=================================="
    read -p "Do you want to export another AMI? (y/n): " another
    
    if [ "$another" != "y" ] && [ "$another" != "Y" ]; then
        print_info "Exiting script. Goodbye!"
        exit 0
    fi
done
