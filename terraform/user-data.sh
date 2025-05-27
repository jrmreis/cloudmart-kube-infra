#!/bin/bash

# Create logs directory
mkdir -p /home/ec2-user/logs
chown ec2-user:ec2-user /home/ec2-user/logs

# Set log file path with timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M)
UNIFIED_LOG="/home/ec2-user/logs/cloudmart_setup_$TIMESTAMP.log"

# Initialize the unified log file with header
echo "========== CLOUDMART SETUP LOG ==========" > $UNIFIED_LOG
echo "Started at: $(date)" >> $UNIFIED_LOG

# Get instance metadata for logging
EC2_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
EC2_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "Instance ID: $EC2_INSTANCE_ID" >> $UNIFIED_LOG
echo "Public IP: $EC2_PUBLIC_IP" >> $UNIFIED_LOG
echo "=========================================" >> $UNIFIED_LOG
echo "" >> $UNIFIED_LOG

# Make log file accessible to ec2-user
chown ec2-user:ec2-user $UNIFIED_LOG

# Function to log with timestamp to the unified log
log_with_timestamp() {
    local step_name="$1"
    local start_time=$(date +"%Y-%m-%d %H:%M:%S")
    
    echo "[$start_time] STARTING: $step_name" | tee -a "$UNIFIED_LOG"
    
    # Execute the command and capture output
    eval "$2" 2>&1 | tee -a "$UNIFIED_LOG"
    
    local status=$?
    local end_time=$(date +"%Y-%m-%d %H:%M:%S")
    
    if [ $status -eq 0 ]; then
        echo "[$end_time] COMPLETED: $step_name (SUCCESS)" | tee -a "$UNIFIED_LOG"
    else
        echo "[$end_time] COMPLETED: $step_name (FAILED with status $status)" | tee -a "$UNIFIED_LOG"
    fi
    
    echo "----------------------------------------" | tee -a "$UNIFIED_LOG"
    
    return $status
}

# Function to handle download with timeout and retry
download_with_retry() {
  local url=$1
  local output_file=$2
  local max_retries=3
  local timeout=300  # 5 minutes timeout
  local retry=0
  
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] DOWNLOAD: Starting download of $url" | tee -a "$UNIFIED_LOG"
  
  while [ $retry -lt $max_retries ]; do
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] DOWNLOAD: Attempt $((retry+1)) for $url" | tee -a "$UNIFIED_LOG"
    
    # Use timeout command to prevent hanging downloads
    if timeout $timeout wget -q "$url" -O "$output_file"; then
      echo "[$(date +"%Y-%m-%d %H:%M:%S")] DOWNLOAD: Success for $url" | tee -a "$UNIFIED_LOG"
      return 0
    else
      retry=$((retry+1))
      echo "[$(date +"%Y-%m-%d %H:%M:%S")] DOWNLOAD: Failed attempt $retry for $url" | tee -a "$UNIFIED_LOG"
      sleep 10  # Wait before retrying
    fi
  done
  
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] DOWNLOAD: All attempts failed for $url" | tee -a "$UNIFIED_LOG"
  # Try alternative method
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] DOWNLOAD: Trying with curl as alternative method" | tee -a "$UNIFIED_LOG"
  if curl -s -o "$output_file" "$url"; then
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] DOWNLOAD: Success with curl for $url" | tee -a "$UNIFIED_LOG"
    return 0
  else
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] DOWNLOAD: All methods failed for $url" | tee -a "$UNIFIED_LOG"
    return 1
  fi
}

# Update system packages
log_with_timestamp "System Update" "sudo yum update -y"

# Install yum-utils and other dependencies
log_with_timestamp "Installing Dependencies" "sudo yum install -y yum-utils python3 python3-pip jq wget unzip curl timeout"

# Add HashiCorp repository
log_with_timestamp "Adding HashiCorp Repository" "sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo"

# Install Terraform
log_with_timestamp "Installing Terraform" "sudo yum -y install terraform && terraform version"

# Install Git
log_with_timestamp "Installing Git" "sudo yum install -y git && git --version"

# Clone repository with the updated URL and proper error handling
log_with_timestamp "Cloning CloudMart Infrastructure Repository" "
  # Try to clone with a timeout to prevent hanging
  timeout 120 git clone -b dev https://github.com/jrmreis/cloudmart-kube-infra.git /home/ec2-user/cloudmart-kube-infra
  
  # Check if clone was successful
  if [ \$? -ne 0 ]; then
    echo 'First clone attempt failed, trying alternative method...'
    
    # Try with depth 1 to speed up clone
    timeout 120 git clone --depth 1 https://github.com/jrmreis/cloudmart-kube-infra.git /home/ec2-user/cloudmart-kube-infra
    
    if [ \$? -ne 0 ]; then
      echo 'Second clone attempt failed, trying with git archive...'
      
      # Try with git archive as a last resort
      mkdir -p /home/ec2-user/cloudmart-kube-infra
      curl -L https://github.com/jrmreis/cloudmart-kube-infra/archive/main.tar.gz | tar -xz -C /home/ec2-user/cloudmart-kube-infra --strip-components=1
      
      if [ \$? -ne 0 ]; then
        echo 'ERROR: All git clone methods failed.'
        return 1
      else
        echo 'Successfully downloaded repository using archive method'
      fi
    else
      echo 'Successfully cloned repository with depth 1'
    fi
  else
    echo 'Successfully cloned repository'
  fi
  
  # Ensure proper ownership
  chown -R ec2-user:ec2-user /home/ec2-user/cloudmart-kube-infra
"

# Update system again
log_with_timestamp "Final System Update" "sudo yum update -y"

# Install and configure Docker
log_with_timestamp "Installing Docker" "sudo yum install docker -y"
log_with_timestamp "Starting Docker Service" "sudo systemctl start docker && sudo systemctl enable docker"
log_with_timestamp "Testing Docker Installation" "sudo docker run hello-world"

# Add current user to docker group
log_with_timestamp "Adding ec2-user to Docker Group" "sudo usermod -a -G docker ec2-user"

# Create delete_cloudmart.sh script
log_with_timestamp "Creating Cleanup Script" "cat > /home/ec2-user/delete_cloudmart.sh << 'EOF2'
#!/bin/bash

# Script to clean up CloudMart Kubernetes resources and delete the EKS cluster
# Usage: ./cleanup-cloudmart.sh

echo \"Starting CloudMart cleanup...\"

# Delete frontend service and deployment
echo \"Deleting frontend resources...\"
kubectl delete service cloudmart-frontend-app-service
kubectl delete deployment cloudmart-frontend-app

# Delete backend service and deployment
echo \"Deleting backend resources...\"
kubectl delete service cloudmart-backend-app-service
kubectl delete deployment cloudmart-backend-app

# Delete the EKS cluster
echo \"Deleting EKS cluster 'cloudmart' in us-east-1 region...\"
eksctl delete cluster --name cloudmart --region us-east-1

echo \"CloudMart cleanup completed!\"
EOF2
chmod +x /home/ec2-user/delete_cloudmart.sh
chown ec2-user:ec2-user /home/ec2-user/delete_cloudmart.sh"

# Create directory structure and download project files for backend
log_with_timestamp "Setting up Backend Directory" "mkdir -p /home/ec2-user/challenge-day2/backend"

log_with_timestamp "Downloading Backend Files" "cd /home/ec2-user/challenge-day2/backend && download_with_retry https://tcb-public-events.s3.amazonaws.com/mdac/resources/day2/cloudmart-backend.zip cloudmart-backend.zip"

log_with_timestamp "Extracting Backend Files" "cd /home/ec2-user/challenge-day2/backend && unzip -o cloudmart-backend.zip"

# Create directory structure and download project files for frontend
log_with_timestamp "Setting up Frontend Directory" "mkdir -p /home/ec2-user/challenge-day2/frontend"

log_with_timestamp "Downloading Frontend Files" "cd /home/ec2-user/challenge-day2/frontend && download_with_retry https://tcb-public-events.s3.amazonaws.com/mdac/resources/day2/cloudmart-frontend.zip cloudmart-frontend.zip"

log_with_timestamp "Extracting Frontend Files" "cd /home/ec2-user/challenge-day2/frontend && unzip -o cloudmart-frontend.zip"

# Create .env file with environment variables
log_with_timestamp "Creating Backend .env File" "cat > /home/ec2-user/challenge-day2/backend/.env << EOF2
PORT=5000
AWS_REGION=us-east-1
BEDROCK_AGENT_ID=<seu-bedrock-agent-id>
BEDROCK_AGENT_ALIAS_ID=<seu-bedrock-agent-alias-id>
OPENAI_API_KEY=<sua-chave-api-openai>
OPENAI_ASSISTANT_ID=<seu-id-assistente-openai>
EOF2
chmod 600 /home/ec2-user/challenge-day2/backend/.env
chown ec2-user:ec2-user /home/ec2-user/challenge-day2/backend/.env"

# Create Dockerfile for backend
log_with_timestamp "Creating Backend Dockerfile" "cat > /home/ec2-user/challenge-day2/backend/Dockerfile << EOF2
FROM node:18
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 5000
CMD [\"npm\", \"start\"]
EOF2
chmod 644 /home/ec2-user/challenge-day2/backend/Dockerfile
chown ec2-user:ec2-user /home/ec2-user/challenge-day2/backend/Dockerfile"

# Create frontend .env file with environment variables
log_with_timestamp "Creating Frontend .env File" "cat > /home/ec2-user/challenge-day2/frontend/.env << EOF2
VITE_API_BASE_URL=http://$EC2_PUBLIC_IP:5000/api
EOF2"

# Create frontend Dockerfile
log_with_timestamp "Creating Frontend Dockerfile" "cat > /home/ec2-user/challenge-day2/frontend/Dockerfile << EOF2
FROM node:16-alpine as build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
FROM node:16-alpine
WORKDIR /app
RUN npm install -g serve
COPY --from=build /app/dist /app
ENV PORT=5001
ENV NODE_ENV=production
EXPOSE 5001
CMD [\"serve\", \"-s\", \".\", \"-l\", \"5001\"]
EOF2"

# Set proper ownership
log_with_timestamp "Setting File Ownership" "chown -R ec2-user:ec2-user /home/ec2-user/challenge-day2 && chown -R ec2-user:ec2-user /home/ec2-user/cloudmart-kube-infra"

# Build and run backend Docker container
log_with_timestamp "Building Backend Docker Image" "cd /home/ec2-user/challenge-day2/backend && docker build -t cloudmart-backend ."
log_with_timestamp "Running Backend Container" "cd /home/ec2-user/challenge-day2/backend && docker run -d -p 5000:5000 --env-file .env --name cloudmart-backend-container cloudmart-backend"

# Build and run frontend Docker container
log_with_timestamp "Building Frontend Docker Image" "cd /home/ec2-user/challenge-day2/frontend && docker build -t cloudmart-frontend ."
log_with_timestamp "Running Frontend Container" "cd /home/ec2-user/challenge-day2/frontend && docker run -d -p 5001:5001 --name cloudmart-frontend-container cloudmart-frontend"

# Create health check script
log_with_timestamp "Creating Health Check Script" "cat > /home/ec2-user/health-check.sh << EOF2
#!/bin/bash

# Health check script - Run this to check the status of your deployment
LOG_FILE=\"/home/ec2-user/logs/cloudmart_health_\$(date +%Y%m%d-%H%M).log\"

echo \"========== CLOUDMART HEALTH CHECK =========\" | tee \$LOG_FILE
echo \"Time: \$(date)\" | tee -a \$LOG_FILE
echo \"Instance ID: \$(curl -s http://169.254.169.254/latest/meta-data/instance-id)\" | tee -a \$LOG_FILE
echo \"Public IP: \$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)\" | tee -a \$LOG_FILE
echo \"\" | tee -a \$LOG_FILE

echo \"Docker Status:\" | tee -a \$LOG_FILE
docker ps | tee -a \$LOG_FILE
echo \"\" | tee -a \$LOG_FILE

echo \"Docker Logs (Backend):\" | tee -a \$LOG_FILE
docker logs cloudmart-backend-container --tail 20 2>&1 | tee -a \$LOG_FILE
echo \"\" | tee -a \$LOG_FILE

echo \"Docker Logs (Frontend):\" | tee -a \$LOG_FILE
docker logs cloudmart-frontend-container --tail 20 2>&1 | tee -a \$LOG_FILE
echo \"\" | tee -a \$LOG_FILE

echo \"System Resources:\" | tee -a \$LOG_FILE
df -h | tee -a \$LOG_FILE
echo \"\" | tee -a \$LOG_FILE
free -m | tee -a \$LOG_FILE
echo \"\" | tee -a \$LOG_FILE
top -b -n 1 | head -20 | tee -a \$LOG_FILE

echo \"=== Health check completed and saved to \$LOG_FILE ===\" | tee -a \$LOG_FILE
EOF2
chmod +x /home/ec2-user/health-check.sh
chown ec2-user:ec2-user /home/ec2-user/health-check.sh"

# Install Ansible as the last task, specifically for ec2-user (not root)
log_with_timestamp "Installing Ansible" "sudo -u ec2-user python3 -m pip install --user ansible"

# Configure Ansible PATH persistently for ec2-user
log_with_timestamp "Configuring Ansible PATH" "
  # Add to ec2-user's .bashrc if not already there
  sudo -u ec2-user bash -c 'grep -q \"PATH=.*\\.local\\/bin\" ~/.bashrc || echo \"export PATH=\\\$PATH:\\\$HOME/.local/bin\" >> ~/.bashrc'
  
  # Add to ec2-user's .bash_profile if not already there
  sudo -u ec2-user bash -c 'grep -q \"PATH=.*\\.local\\/bin\" ~/.bash_profile || echo \"export PATH=\\\$PATH:\\\$HOME/.local/bin\" >> ~/.bash_profile'
  
  # Create a system-wide profile that will source ec2-user's ansible
  echo '# Make ec2-user ansible available to all users
if [ -f /home/ec2-user/.local/bin/ansible ]; then
  export PATH=\$PATH:/home/ec2-user/.local/bin
fi' | sudo tee /etc/profile.d/ansible.sh
  
  # Make the profile script executable
  sudo chmod +x /etc/profile.d/ansible.sh
  
  # Verify ansible installation
  echo 'Verifying ansible installation:'
  sudo -u ec2-user bash -c 'PATH=\$PATH:\$HOME/.local/bin ansible --version || echo \"Ansible verification failed\"'
"

# Create a user-friendly README
log_with_timestamp "Creating README" "cat > /home/ec2-user/README.md << EOF2
# CloudMart Deployment

## Setup Information
- Instance ID: $EC2_INSTANCE_ID
- Public IP: $EC2_PUBLIC_IP
- Setup completed: $(date)

## Important Directories
- CloudMart Source: /home/ec2-user/cloudmart-kube-infra
- Challenge Files: /home/ec2-user/challenge-day2
- Logs: /home/ec2-user/logs

## Health Check
Run the health check script to see the current status of your deployment:
\`\`\`
./health-check.sh
\`\`\`

## Docker Containers
Access the applications directly:
- Backend: http://$EC2_PUBLIC_IP:5000
- Frontend: http://$EC2_PUBLIC_IP:5001

## Logs
All setup logs are available in the /home/ec2-user/logs directory.
EOF2"

# Make README accessible to ec2-user
log_with_timestamp "Setting README Permissions" "chown ec2-user:ec2-user /home/ec2-user/README.md"

# Final setup status
log_with_timestamp "Completing Setup" "echo \"Setup completed at $(date)\" > /home/ec2-user/setup-complete.log && echo \"Docker container status:\" >> /home/ec2-user/setup-complete.log && docker ps >> /home/ec2-user/setup-complete.log"

# Create a symlink to the latest log file for easy access
log_with_timestamp "Creating Log Symlink" "ln -sf $UNIFIED_LOG /home/ec2-user/logs/latest.log && chown ec2-user:ec2-user /home/ec2-user/logs/latest.log"

# Update README to mention the unified log
log_with_timestamp "Updating README with Log Info" "echo -e '\n## Log File\nA unified log of the setup process is available at:\n- $UNIFIED_LOG\n- Symlinked at /home/ec2-user/logs/latest.log' >> /home/ec2-user/README.md"

echo "Installation complete! See /home/ec2-user/logs for detailed logs and /home/ec2-user/README.md for usage instructions."
