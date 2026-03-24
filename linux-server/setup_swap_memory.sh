#!/bin/bash

# ============================================================
# Script : setup_swap_memory.sh
# Description : Safely creates and mounts a swap file to prevent out-of-memory (OOM) crashes on low RAM instances.
# ============================================================

# Script to create and configure swap memory
echo "=== Swap Memory Setup Script ==="
echo

# Function to validate size input
validate_size() {
    local size="$1"
    # Check if size matches pattern like 1G, 2G, 512M, etc.
    if [[ $size =~ ^[0-9]+[GMgm]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Ask user for swap memory size
while true; do
    echo "Enter swap memory size (e.g., 1G, 2G, 512M):"
    echo "  - Use 'G' for Gigabytes (e.g., 2G for 2GB)"
    echo "  - Use 'M' for Megabytes (e.g., 512M for 512MB)"
    read -p "Swap size: " swap_size
    
    if validate_size "$swap_size"; then
        # Convert to uppercase for consistency
        swap_size=$(echo "$swap_size" | tr '[:lower:]' '[:upper:]')
        break
    else
        echo "Error: Invalid format. Please use format like '1G', '2G', or '512M'"
        echo
    fi
done

echo
echo "Setting up swap file with size: $swap_size"
echo "This may take a few moments..."
echo

# Check if /swapfile1 already exists
if [ -f /swapfile1 ]; then
    echo "Warning: /swapfile1 already exists!"
    read -p "Do you want to remove the existing swap file and create a new one? (y/N): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo "Removing existing swap file..."
        sudo swapoff /swapfile1 2>/dev/null
        sudo rm -f /swapfile1
    else
        echo "Setup cancelled."
        exit 0
    fi
fi

# Create swap file
echo "Step 1/6: Creating swap file..."
if sudo fallocate -l "$swap_size" /swapfile1; then
    echo " Swap file created successfully"
else
    echo " Failed to create swap file"
    exit 1
fi

# Set proper permissions
echo "Step 2/6: Setting permissions..."
if sudo chmod 600 /swapfile1; then
    echo " Permissions set to 600"
else
    echo " Failed to set permissions"
    exit 1
fi

# Make swap
echo "Step 3/6: Setting up swap space..."
if sudo mkswap /swapfile1; then
    echo " Swap space configured"
else
    echo " Failed to setup swap space"
    exit 1
fi

# Enable swap
echo "Step 4/6: Enabling swap..."
if sudo swapon /swapfile1; then
    echo " Swap enabled"
else
    echo " Failed to enable swap"
    exit 1
fi

# Add to fstab for persistence
echo "Step 5/6: Adding to /etc/fstab for persistence..."
if grep -q "/swapfile1" /etc/fstab; then
    echo " Entry already exists in /etc/fstab"
else
    if echo '/swapfile1 none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null; then
        echo " Added to /etc/fstab"
    else
        echo " Failed to add to /etc/fstab"
        exit 1
    fi
fi

# Show memory status
echo "Step 6/6: Displaying memory status..."
echo
echo "=== Current Memory Status ==="
free -h

echo
echo "=== Setup Complete ==="
echo " Swap file created: /swapfile1 ($swap_size)"
echo " Swap is now active and will persist after reboot"
echo
echo "Additional commands you can use:"
echo "  - View swap usage: sudo swapon --show"
echo "  - Disable swap: sudo swapoff /swapfile1"
echo "  - Enable swap: sudo swapon /swapfile1"
echo "  - Check swap usage: cat /proc/swaps"
