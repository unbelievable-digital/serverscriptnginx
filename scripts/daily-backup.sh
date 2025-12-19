#!/usr/bin/env bash

################################################################################
# Daily Backup Script
#
# Automatically backs up all WordPress sites
# Scheduled to run daily at 2 AM via cron
################################################################################

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Source core libraries
source "${BASE_DIR}/lib/core.sh"
source "${BASE_DIR}/lib/backup.sh"

# Configuration
CONFIG_FILE="${BASE_DIR}/config/wpserver.conf"
BACKUP_LOG="${BASE_DIR}/logs/backup.log"

# Initialize
echo "========================================" >> "$BACKUP_LOG"
echo "Backup started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$BACKUP_LOG"
echo "========================================" >> "$BACKUP_LOG"

# Run backup
backup_all_sites >> "$BACKUP_LOG" 2>&1

# Cleanup old backups
cleanup_old_backups >> "$BACKUP_LOG" 2>&1

echo "Backup completed: $(date '+%Y-%m-%d %H:%M:%S')" >> "$BACKUP_LOG"
echo "" >> "$BACKUP_LOG"
