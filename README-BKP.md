🚀 Quick Setup & First Backup
1. Configure the Script
bash# Save the script and make it executable
chmod +x backup-to-github.sh

# Edit these lines in the script:
# GITHUB_REPO_URL="https://github.com/jrmreis/bkp_dina_db.git"
# GITHUB_USERNAME="jrmreis"  
# GITHUB_EMAIL="your-email@example.com"
2. Setup GitHub Repository
bash# Initialize the GitHub repository for backups
./backup-to-github.sh setup
3. Run Your First Backup
bash# Backup all CloudMart tables to GitHub
./backup-to-github.sh backup
✨ What This Solution Does
Automatic Export:

Scans all CloudMart tables (products, orders, tickets)
Exports to JSON format (ready for restore)
Creates compressed archives
Generates backup reports

GitHub Integration:

Commits backups with timestamps
Pushes to your repository automatically
Creates organized folder structure
Maintains backup history

Smart Features:

Handles empty tables gracefully
Creates restore instructions automatically
Cleans up old backups (keeps 7 days)
Provides detailed logging

📁 Repository Structure Created
your-github-repo/
├── backups/
│   └── daily/
│       └── 20241127/
│           ├── cloudmart-products.json
│           ├── cloudmart-orders.json  
│           ├── cloudmart-tickets.json
│           ├── cloudmart-backup-20241127-135500.tar.gz
│           └── backup-report.md
├── restore-scripts/
│   └── restore-instructions.md
├── docs/
│   └── backup-log.md
└── README.md
🔧 Usage Commands
bash# Setup (run once)
./backup-to-github.sh setup

# Daily backup 
./backup-to-github.sh backup

# Check status
./backup-to-github.sh status

# Restore all tables from specific date
./backup-to-github.sh restore 20241127

# Restore specific table
./backup-to-github.sh restore 20241127 cloudmart-products
📅 Set Up Automated Daily Backups
bash# Add to crontab for daily backup at 3 AM
(crontab -l 2>/dev/null; echo "0 3 * * * /home/ec2-user/backup-to-github.sh backup") | crontab -
🔑 GitHub Authentication
If you get push errors, set up GitHub authentication:
bash# Option 1: Use Personal Access Token
git config --global credential.helper store
# Then enter token when prompted

# Option 2: Use SSH keys (recommended)
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
cat ~/.ssh/id_rsa.pub  # Add this to GitHub SSH keys
🎯 Benefits of This Approach
Version Control:

Track changes over time
Compare backups between dates
Rollback to any previous version

Accessibility:

Download backups from anywhere
Share with team members
View backup reports in browser

Reliability:

Multiple copies (local + GitHub)
Automatic compression
Error handling and logging

Easy Restore:
bash# Simple restore process
aws dynamodb batch-write-item --request-items file://cloudmart-products.json
This solution gives you a professional, version-controlled backup system that stores your DynamoDB data safely in GitHub with full restore capabilities!
Try running the setup now and let me know if you need any adjustments! 🚀
