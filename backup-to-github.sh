#!/bin/bash

# CloudMart DynamoDB to GitHub Backup Script
# This script backs up DynamoDB tables and commits them to a GitHub repository
# Usage: ./backup-to-github.sh [setup|backup|restore]

set -e

# Configuration
AWS_REGION="us-east-1"
TABLES=("cloudmart-products" "cloudmart-orders" "cloudmart-tickets")
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DATE_ONLY=$(date +%Y%m%d)
LOG_DIR="/home/ec2-user/logs"
LOG_FILE="${LOG_DIR}/github-backup-${TIMESTAMP}.log"

# GitHub Configuration - EDIT THESE
GITHUB_REPO_URL="https://github.com/jrmreis/bkp_dina_db.git"  # Your GitHub repo
GITHUB_USERNAME="jrmreis"  # Your GitHub username
GITHUB_EMAIL="jrmreis@gmail.com"  # Your email
BACKUP_REPO_DIR="/home/ec2-user/dynamodb-backup-repo"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")  echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$LOG_FILE" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $message" | tee -a "$LOG_FILE" ;;
        "WARNING") echo -e "${YELLOW}[WARNING]${NC} $message" | tee -a "$LOG_FILE" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" | tee -a "$LOG_FILE" ;;
    esac
}

# Check if AWS CLI is configured
check_aws_config() {
    if ! aws sts get-caller-identity &>/dev/null; then
        log "ERROR" "AWS CLI not configured properly. Please run 'aws configure'"
        exit 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    log "INFO" "Using AWS Account: $account_id"
}

# Check if git is configured
check_git_config() {
    if ! git config --global user.name &>/dev/null; then
        log "INFO" "Configuring Git user..."
        git config --global user.name "$GITHUB_USERNAME"
        git config --global user.email "$GITHUB_EMAIL"
    fi
    
    log "INFO" "Git configured for user: $(git config --global user.name)"
}

# Setup GitHub repository for backups
setup_github_repo() {
    log "INFO" "Setting up GitHub repository for DynamoDB backups..."
    
    check_git_config
    
    # Remove existing directory if it exists
    if [ -d "$BACKUP_REPO_DIR" ]; then
        log "WARNING" "Backup repository directory exists, removing..."
        rm -rf "$BACKUP_REPO_DIR"
    fi
    
    # Clone or initialize repository
    if git ls-remote "$GITHUB_REPO_URL" &>/dev/null; then
        log "INFO" "Cloning existing repository..."
        git clone "$GITHUB_REPO_URL" "$BACKUP_REPO_DIR"
    else
        log "INFO" "Repository appears to be empty, initializing..."
        mkdir -p "$BACKUP_REPO_DIR"
        cd "$BACKUP_REPO_DIR"
        git init
        git remote add origin "$GITHUB_REPO_URL"
    fi
    
    cd "$BACKUP_REPO_DIR"
    
    # Create directory structure
    mkdir -p backups/{daily,weekly,monthly}
    mkdir -p restore-scripts
    mkdir -p docs
    
    # Create README if it doesn't exist
    if [ ! -f "README.md" ]; then
        cat > README.md << 'EOF'
# CloudMart DynamoDB Backups

This repository contains automated backups of CloudMart DynamoDB tables.

## Structure

- `backups/daily/` - Daily backup files
- `backups/weekly/` - Weekly backup summaries  
- `backups/monthly/` - Monthly backup archives
- `restore-scripts/` - Scripts to restore from backups
- `docs/` - Documentation and backup reports

## Latest Backup

Check the latest backup in the daily folder or view the backup log in docs/backup-log.md

## Restore Instructions

See `restore-scripts/restore-instructions.md` for detailed restore procedures.
EOF
    fi
    
    # Create backup log file
    if [ ! -f "docs/backup-log.md" ]; then
        cat > docs/backup-log.md << 'EOF'
# CloudMart Backup Log

## Backup History

| Date | Tables | Status | Notes |
|------|--------|--------|-------|
EOF
    fi
    
    # Create restore instructions
    cat > restore-scripts/restore-instructions.md << 'EOF'
# Restore Instructions

## Quick Restore

1. Download the backup file from the `backups/daily/` directory
2. Extract the JSON file: `tar -xzf backup-file.tar.gz`
3. Use AWS CLI to restore: `aws dynamodb batch-write-item --request-items file://table-data.json`

## Detailed Steps

### 1. Choose Backup File
```bash
# List available backups
ls -la backups/daily/

# Download specific backup
curl -O https://raw.githubusercontent.com/[username]/[repo]/main/backups/daily/[backup-file]
```

### 2. Extract Data
```bash
tar -xzf cloudmart-backup-YYYYMMDD-HHMMSS.tar.gz
```

### 3. Restore to DynamoDB
```bash
# For each table
aws dynamodb batch-write-item --request-items file://cloudmart-products.json
aws dynamodb batch-write-item --request-items file://cloudmart-orders.json  
aws dynamodb batch-write-item --request-items file://cloudmart-tickets.json
```

### 4. Verify Restore
```bash
# Check item counts
aws dynamodb scan --table-name cloudmart-products --select COUNT
```
EOF
    
    # Create initial commit
    git add .
    if git diff --cached --quiet; then
        log "INFO" "No changes to commit (repository already initialized)"
    else
        git commit -m "Initial setup: CloudMart DynamoDB backup repository"
        
        # Push to GitHub (if remote exists)
        if git remote get-url origin &>/dev/null; then
            log "INFO" "Pushing initial setup to GitHub..."
            git push -u origin main 2>/dev/null || git push -u origin master 2>/dev/null || {
                log "WARNING" "Could not push to GitHub. You may need to set up authentication."
                log "INFO" "Repository is ready locally at: $BACKUP_REPO_DIR"
            }
        fi
    fi
    
    log "SUCCESS" "GitHub repository setup completed"
}

# Export DynamoDB table to JSON
export_table_to_json() {
    local table_name=$1
    local output_file=$2
    
    log "INFO" "Exporting table $table_name to $output_file"
    
    # Check if Python boto3 is available
    if ! python3 -c "import boto3" &>/dev/null; then
        log "INFO" "Installing boto3..."
        pip3 install --user boto3
    fi
    
    # Create Python export script
    cat > "/tmp/export_table.py" << 'EOF'
import boto3
import json
import sys
from decimal import Decimal
from datetime import datetime

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

def export_table(table_name, output_file, region):
    try:
        dynamodb = boto3.resource('dynamodb', region_name=region)
        table = dynamodb.Table(table_name)
        
        print(f"Scanning table: {table_name}")
        
        response = table.scan()
        items = response['Items']
        
        # Handle pagination
        while 'LastEvaluatedKey' in response:
            response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
            items.extend(response['Items'])
        
        # Create batch write format for easy restore
        if items:
            batch_write_format = {
                table_name: [
                    {'PutRequest': {'Item': item}} for item in items
                ]
            }
            
            with open(output_file, 'w') as f:
                json.dump(batch_write_format, f, cls=DecimalEncoder, indent=2)
            
            print(f"Exported {len(items)} items to {output_file}")
            return len(items)
        else:
            print(f"Table {table_name} is empty")
            return 0
        
    except Exception as e:
        print(f"Error exporting {table_name}: {str(e)}")
        return -1

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python3 export_table.py <table_name> <output_file> <region>")
        sys.exit(1)
    
    table_name = sys.argv[1]
    output_file = sys.argv[2]
    region = sys.argv[3]
    
    result = export_table(table_name, output_file, region)
    sys.exit(0 if result >= 0 else 1)
EOF
    
    if python3 /tmp/export_table.py "$table_name" "$output_file" "$AWS_REGION"; then
        log "SUCCESS" "Successfully exported $table_name"
        rm -f /tmp/export_table.py
        return 0
    else
        log "ERROR" "Failed to export $table_name"
        rm -f /tmp/export_table.py
        return 1
    fi
}

# Perform backup to GitHub
backup_to_github() {
    log "INFO" "Starting DynamoDB backup to GitHub..."
    
    check_aws_config
    
    if [ ! -d "$BACKUP_REPO_DIR" ]; then
        log "ERROR" "GitHub repository not set up. Run setup first."
        return 1
    fi
    
    cd "$BACKUP_REPO_DIR"
    
    # Pull latest changes
    git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true
    
    # Create backup directory for today
    local backup_dir="backups/daily/${DATE_ONLY}"
    mkdir -p "$backup_dir"
    
    local backup_success=true
    local total_items=0
    local backup_summary=""
    
    # Export each table
    for table in "${TABLES[@]}"; do
        log "INFO" "Processing table: $table"
        
        # Check if table exists
        if aws dynamodb describe-table --table-name "$table" --region "$AWS_REGION" &>/dev/null; then
            local json_file="${backup_dir}/${table}.json"
            
            if export_table_to_json "$table" "$json_file"; then
                local item_count=$(jq ".[\"$table\"] | length" "$json_file" 2>/dev/null || echo "0")
                total_items=$((total_items + item_count))
                backup_summary="${backup_summary}| $table | $item_count items | ✅ Success |\n"
                log "SUCCESS" "Backed up $table ($item_count items)"
            else
                backup_summary="${backup_summary}| $table | 0 items | ❌ Failed |\n"
                backup_success=false
                log "ERROR" "Failed to backup $table"
            fi
        else
            backup_summary="${backup_summary}| $table | N/A | ⚠️ Not Found |\n"
            log "WARNING" "Table $table does not exist"
        fi
    done
    
    # Create backup archive
    local archive_name="cloudmart-backup-${TIMESTAMP}.tar.gz"
    tar -czf "${backup_dir}/${archive_name}" -C "$backup_dir" *.json 2>/dev/null || true
    
    # Create backup report
    cat > "${backup_dir}/backup-report.md" << EOF
# CloudMart Backup Report

**Date:** $(date)  
**Timestamp:** $TIMESTAMP  
**AWS Account:** $(aws sts get-caller-identity --query Account --output text)  
**Region:** $AWS_REGION  
**Total Items:** $total_items  

## Tables Backed Up

| Table | Items | Status |
|-------|-------|--------|
$(echo -e "$backup_summary")

## Files Created

- \`${archive_name}\` - Compressed backup archive
$(for table in "${TABLES[@]}"; do
    if [ -f "${backup_dir}/${table}.json" ]; then
        echo "- \`${table}.json\` - Individual table backup"
    fi
done)

## Restore Command

\`\`\`bash
# Extract archive
tar -xzf ${archive_name}

# Restore tables (ensure tables exist first)
$(for table in "${TABLES[@]}"; do
    echo "aws dynamodb batch-write-item --request-items file://${table}.json"
done)
\`\`\`
EOF
    
    # Update backup log
    local status_emoji="✅"
    if [ "$backup_success" = false ]; then
        status_emoji="❌"
    fi
    
    echo "| $(date '+%Y-%m-%d %H:%M') | ${#TABLES[@]} tables | $status_emoji | $total_items total items |" >> docs/backup-log.md
    
    # Commit and push to GitHub
    git add .
    
    if ! git diff --cached --quiet; then
        git commit -m "Backup ${DATE_ONLY}: ${total_items} items from ${#TABLES[@]} CloudMart tables"
        
        if git push origin main 2>/dev/null || git push origin master 2>/dev/null; then
            log "SUCCESS" "Backup pushed to GitHub successfully"
        else
            log "WARNING" "Backup saved locally but could not push to GitHub"
            log "INFO" "Local backup available at: $backup_dir"
        fi
    else
        log "INFO" "No changes to commit (tables may be empty)"
    fi
    
    # Clean up old daily backups (keep last 7 days)
    find backups/daily -name "2*" -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null || true
    
    if [ "$backup_success" = true ]; then
        log "SUCCESS" "GitHub backup completed successfully!"
        log "INFO" "Total items backed up: $total_items"
        log "INFO" "Backup location: ${backup_dir}"
        log "INFO" "Archive: ${backup_dir}/${archive_name}"
    else
        log "WARNING" "Backup completed with some errors. Check the logs."
    fi
}

# Restore from GitHub backup
restore_from_github() {
    local backup_date=$1
    local table_name=$2
    
    if [ -z "$backup_date" ]; then
        log "ERROR" "Usage: restore <YYYYMMDD> [table_name]"
        log "INFO" "Available backups:"
        if [ -d "$BACKUP_REPO_DIR/backups/daily" ]; then
            ls -1 "$BACKUP_REPO_DIR/backups/daily" | sort -r | head -10
        fi
        return 1
    fi
    
    local backup_dir="$BACKUP_REPO_DIR/backups/daily/$backup_date"
    
    if [ ! -d "$backup_dir" ]; then
        log "ERROR" "Backup not found for date: $backup_date"
        return 1
    fi
    
    cd "$backup_dir"
    
    if [ -n "$table_name" ]; then
        # Restore specific table
        local json_file="${table_name}.json"
        if [ -f "$json_file" ]; then
            log "INFO" "Restoring table $table_name from $backup_date"
            if aws dynamodb batch-write-item --request-items "file://$json_file" --region "$AWS_REGION"; then
                log "SUCCESS" "Table $table_name restored successfully"
            else
                log "ERROR" "Failed to restore table $table_name"
            fi
        else
            log "ERROR" "Backup file not found: $json_file"
        fi
    else
        # Restore all tables
        log "INFO" "Restoring all CloudMart tables from $backup_date"
        for table in "${TABLES[@]}"; do
            local json_file="${table}.json"
            if [ -f "$json_file" ]; then
                log "INFO" "Restoring table $table"
                if aws dynamodb batch-write-item --request-items "file://$json_file" --region "$AWS_REGION"; then
                    log "SUCCESS" "Table $table restored successfully"
                else
                    log "ERROR" "Failed to restore table $table"
                fi
            else
                log "WARNING" "Backup file not found for table: $table"
            fi
        done
    fi
}

# Display usage
show_usage() {
    echo "CloudMart DynamoDB to GitHub Backup Tool"
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  setup                    - Setup GitHub repository for backups"
    echo "  backup                   - Backup DynamoDB tables to GitHub"
    echo "  restore <YYYYMMDD>       - Restore all tables from specific date"
    echo "  restore <YYYYMMDD> <table> - Restore specific table from date"
    echo "  status                   - Show backup status"
    echo ""
    echo "Examples:"
    echo "  $0 setup"
    echo "  $0 backup"
    echo "  $0 restore 20241127"
    echo "  $0 restore 20241127 cloudmart-products"
    echo ""
    echo "Configuration:"
    echo "  GitHub repo: $GITHUB_REPO_URL"
    echo "  Local repo: $BACKUP_REPO_DIR"
    echo "  AWS region: $AWS_REGION"
}

# Show backup status
show_status() {
    log "INFO" "CloudMart GitHub Backup Status"
    echo
    
    if [ -d "$BACKUP_REPO_DIR" ]; then
        cd "$BACKUP_REPO_DIR"
        log "SUCCESS" "GitHub repository setup at: $BACKUP_REPO_DIR"
        
        if [ -d ".git" ]; then
            local repo_url=$(git remote get-url origin 2>/dev/null || echo "Unknown")
            local last_commit=$(git log -1 --pretty=format:"%h - %s (%cr)" 2>/dev/null || echo "Unknown")
            log "INFO" "Repository: $repo_url"
            log "INFO" "Last commit: $last_commit"
        fi
        
        echo
        log "INFO" "Recent backups:"
        if [ -d "backups/daily" ]; then
            ls -1 backups/daily | sort -r | head -5 | while read backup_date; do
                if [ -d "backups/daily/$backup_date" ]; then
                    local files=$(ls backups/daily/$backup_date/*.json 2>/dev/null | wc -l || echo "0")
                    log "INFO" "  $backup_date ($files tables)"
                fi
            done
        else
            log "WARNING" "No daily backups found"
        fi
    else
        log "WARNING" "GitHub repository not set up. Run setup first."
    fi
}

# Main execution
main() {
    local command=${1:-help}
    shift 2>/dev/null || true
    
    log "INFO" "CloudMart GitHub Backup Tool"
    log "INFO" "Command: $command"
    log "INFO" "Log file: $LOG_FILE"
    
    case $command in
        "setup")
            setup_github_repo
            ;;
        "backup")
            backup_to_github
            ;;
        "restore")
            restore_from_github "$@"
            ;;
        "status")
            show_status
            ;;
        "help"|"--help"|"-h"|"")
            show_usage
            exit 0
            ;;
        *)
            log "ERROR" "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
    
    log "SUCCESS" "Operation completed successfully"
}

# Run main function
main "$@"
