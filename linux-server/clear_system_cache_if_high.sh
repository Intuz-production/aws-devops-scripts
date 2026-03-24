#!/bin/bash

# ============================================================
# Script : clear_system_cache_if_high.sh
# Description : Detects when Linux memory utilization hits high thresholds and defensively clears page cache without crashing.
# ============================================================

# Set the threshold for buff/cache memory in bytes (2GB)
THRESHOLD=$((1 * 1024 * 1024 * 1024))

# Get the value of buff/cache memory in bytes using 'free' command
buff_cache=$(free -b | awk 'NR==2{print $6}')

# Check if the buff/cache memory is greater than the threshold
if [ "$buff_cache" -gt "$THRESHOLD" ]; then
    echo "Buff/cache memory is greater than 2GB, clearing caches..."

    # Sync and clear page cache (echo 1)
    sudo sync; echo 1 | sudo tee /proc/sys/vm/drop_caches

    # Sync and clear dentries and inodes (echo 2)
    sudo sync; echo 2 | sudo tee /proc/sys/vm/drop_caches

    # Sync and clear page cache, dentries, and inodes (echo 3)
    sudo sync; echo 3 | sudo tee /proc/sys/vm/drop_caches

    echo "Memory cleared."
else
    echo "Buff/cache memory is below 2GB, no action needed."
fi
