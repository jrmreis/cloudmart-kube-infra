# External DynamoDB Backup Integration Guide

## Overview

This guide shows how to integrate external DynamoDB backup tools (like `jrmreis/bkp_dina_db`) with your existing CloudMart backup infrastructure, creating a comprehensive multi-tool backup strategy.

## 🚀 Quick Setup

### 1. Setup External Backup Tool

```bash
# Download and setup the integration script
chmod +x integrate-external-backup.sh

# Setup the external backup tool
./integrate-external-backup.sh setup
```

### 2. Test the Integration

```bash
# Run a backup using the external tool
./integrate-external-backup.sh backup

# Check status
./integrate-external-backup.sh status
```

### 3. Integrate with Existing System

```bash
# Integrate with your current CloudMart backup system
./integrate-external-backup.sh integrate
```

## 📋 Detailed Setup Process

### Step 1: Install the Integration Script

Save the `integrate-external-backup.sh` script to your EC2 instance and make it executable:

```bash
chmod +x integrate-external-backup.sh
```

### Step 2: Configure Repository URL

Edit the script to point to your specific repository:

```bash
# In the script, update this line:
EXTERNAL_REPO_URL="https://github.com/jrmreis/bkp_dina_db.git"
```

### Step 3: Run Setup

```bash
./integrate-external-backup.sh setup
```

This will:
- Clone the external repository
- Install dependencies (Python/Node.js packages)
- Create wrapper functions
- Generate CloudMart-specific configuration

## 🔧 Configuration

### CloudMart Configuration File

The setup creates `/home/ec2-user/external-backup-tools/cloudmart-config.json`:

```json
{
    "region": "us-east-1",
    "tables": [
        "cloudmart-products",
        "cloudmart-orders", 
        "cloudmart-tickets"
    ],
    "backup_dir": "/home/ec2-user/backup-data",
    "timestamp_format": "%Y%m%d-%H%M%S"
}
```

### Wrapper Script Compatibility

The integration automatically detects and works with these external tool patterns:

#### Python-based Tools
```bash
# Supports tools with these files:
- backup.py
- restore.py  
- main.py (with backup/restore subcommands)
```

#### Node.js-based Tools
```bash
# Supports tools with:
- index.js
- package.json
```

#### Bash-based Tools
```bash
# Supports tools with:
- backup.sh
- restore.sh
```

## 📁 Directory Structure

After setup, you'll have:

```
/home/ec2-user/
├── external-backup-tools/           # External tool repository
│   ├── cloudmart-config.json       # CloudMart configuration
│   ├── cloudmart-backup-wrapper.sh # Universal wrapper
│   └── [external tool files]       # From the repository
├── backup-data/                    # External tool backup storage
│   ├── cloudmart-products-20241127-1430/
│   ├── cloudmart-orders-20241127-1430/
│   └── cloudmart-external-backup-20241127-1430.tar.gz
├── backup-cloudmart-external.sh    # Combined backup script
├── daily-backup-external.sh        # Extended daily backup
└── logs/                           # All backup logs
```

## 🔄 Usage Commands

### Basic Operations

```bash
# Setup external tool
./integrate-external-backup.sh setup

# Run backup with external tool
./integrate-external-backup.sh backup

# Restore from external backup
./integrate-external-backup.sh restore cloudmart-products /path/to/backup.json

# Check status and available backups
./integrate-external-backup.sh status
```

### Combined Operations

After integration, you can use combined scripts:

```bash
# Run both native and external backups
./backup-cloudmart-external.sh

# Use the extended daily backup (includes external tool)
./daily-backup-external.sh
```

## 🔀 Backup Strategy Options

### Option 1: Parallel Backup Strategy
Run both native and external tools together:

```bash
# Daily automated backup (2 AM cron job)
0 2 * * * /home/ec2-user/backup-cloudmart-external.sh
```

### Option 2: Alternating Strategy
Alternate between different backup methods:

```bash
# Weekdays: Native backup
# Weekends: External backup
0 2 * * 1-5 /home/ec2-user/backup-cloudmart.sh ondemand
0 2 * * 6-7 /home/ec2-user/integrate-external-backup.sh backup
```

### Option 3: Layered Strategy
Different tools for different purposes:

```bash
# Daily: Native on-demand backups
0 2 * * * /home/ec2-user/backup-cloudmart.sh ondemand

# Weekly: External tool backup (more features)
0 3 * * 1 /home/ec2-user/integrate-external-backup.sh backup

# Monthly: Full export to S3
0 4 1 * * /home/ec2-user/backup-cloudmart.sh export
```

## 🛠️ Troubleshooting

### Common Issues and Solutions

#### 1. Repository Clone Fails
```bash
# Check URL and internet connectivity
git clone https://github.com/jrmreis/bkp_dina_db.git /tmp/test-clone

# If private repository, setup SSH keys:
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
# Add public key to GitHub
```

#### 2. Dependencies Missing
```bash
# Python dependencies
pip3 install --user boto3 pandas numpy

# Node.js dependencies  
npm install -g aws-sdk

# System dependencies
sudo yum install -y python3-dev build-essential
```

#### 3. Permission Issues
```bash
# Fix file permissions
chmod +x /home/ec2-user/external-backup-tools/*.sh
chmod +x /home/ec2-user/external-backup-tools/*.py

# Fix directory permissions
chown -R ec2-user:ec2-user /home/ec2-user/external-backup-tools/
```

#### 4. AWS Credentials
```bash
# Verify AWS configuration
aws sts get-caller-identity

# Check region setting
aws configure get region

# Test DynamoDB access
aws dynamodb list-tables --region us-east-1
```

### Debug Mode

Enable verbose logging:

```bash
# Run with debug output
bash -x ./integrate-external-backup.sh backup

# Check logs
tail -f /home/ec2-user/logs/external-backup-*.log
```

## 📊 Monitoring and Verification

### Backup Status Dashboard

```bash
# Quick status check
./integrate-external-backup.sh status

# Detailed status with native tools
./backup-status.sh

# Combined status report
cat > /home/ec2-user/full-backup-status.sh << 'EOF'
#!/bin/bash
echo "========== COMPLETE CLOUDMART BACKUP STATUS =========="
echo "Generated: $(date)"
echo ""

echo "=== Native Backup Status ==="
./backup-status.sh

echo ""
echo "=== External Backup Status ==="
./integrate-external-backup.sh status

echo ""
echo "=== Recent Combined Backups ==="
ls -la /home/ec2-user/logs/*backup* | tail -10
EOF

chmod +x /home/ec2-user/full-backup-status.sh
```

### Automated Verification

```bash
# Create backup verification script
cat > /home/ec2-user/verify-backups.sh << 'EOF'
#!/bin/bash

echo "Verifying backup integrity..."

# Check native backups
for table in cloudmart-products cloudmart-orders cloudmart-tickets; do
    echo "Checking native backups for $table..."
    aws dynamodb list-backups --table-name "$table" --region us-east-1 \
        --query 'BackupSummaries[0].[BackupName,BackupStatus]' --output table
done

# Check external backups
echo "Checking external backup files..."
find /home/ec2-user/backup-data -name "*.tar.gz" -mtime -7 -exec ls -lh {} \;

# Verify latest backup can be read
latest_backup=$(find /home/ec2-user/backup-data -name "*.tar.gz" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
if [ -n "$latest_backup" ]; then
    echo "Latest external backup: $latest_backup"
    tar -tzf "$latest_backup" | head -10
else
    echo "No external backup archives found"
fi
EOF

chmod +x /home/ec2-user/verify-backups.sh
```

## 🔐 Security Considerations

### Access Control

```bash
# Restrict access to backup directories
chmod 700 /home/ec2-user/backup-data
chmod 700 /home/ec2-user/external-backup-tools

# Secure configuration files
chmod 600 /home/ec2-user/external-backup-tools/cloudmart-config.json
```

### Encryption

```bash
# Encrypt backup archives
gpg --symmetric --cipher-algo AES256 backup-file.tar.gz

# Automated encryption
echo "BACKUP_ENCRYPT=true" >> /home/ec2-user/.backup-config
```

## 📈 Performance Optimization

### Parallel Processing

```bash
# Run backups in parallel
./backup-cloudmart.sh ondemand &
./integrate-external-backup.sh backup &
wait

echo "Both backups completed!"
```

### Storage Optimization

```bash
# Compress and archive old backups
find /home/ec2-user/backup-data -name "*.tar.gz" -mtime +30 -exec mv {} /archive/ \;

# Clean up temporary files
find /home/ec2-user/backup-data -name "*.tmp" -delete
```

## 🎯 Best Practices

1. **Test Integration Early**: Always test with small tables first
2. **Monitor Both Systems**: Set up monitoring for native and external tools
3. **Version Control**: Keep your integration scripts in version control
4. **Document Customizations**: Document any tool-specific modifications
5. **Regular Testing**: Test restore procedures monthly
6. **Backup Validation**: Always verify backup integrity
7. **Access Logging**: Log all backup and restore operations
8. **Resource Monitoring**: Monitor CPU, memory, and disk usage during backups

## 🔄 Migration Strategy

If migrating from one backup tool to another:

1. **Run in Parallel**: Keep both systems running during transition
2. **Validate Data**: Compare outputs between systems
3. **Test Restores**: Verify both systems can restore correctly
4. **Gradual Transition**: Move one table at a time
5. **Keep Fallback**: Maintain old system until confident in new one

This integration approach gives you the flexibility to use specialized DynamoDB backup tools while maintaining compatibility with your existing CloudMart infrastructure.
