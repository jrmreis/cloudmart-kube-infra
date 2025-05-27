provider "aws" {
  region = "us-east-1"  # You can change this to your preferred region
  profile = "eksuser"   # Altere para o nome do seu USER (IAM) + "aws configure --profile eksuser"
}

# DynamoDB Tables
resource "aws_dynamodb_table" "cloudmart_products" {
  name           = "cloudmart-products"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  attribute {
    name = "id"
    type = "S"
  }
  
  tags = {
    Name        = "cloudmart-products"
    Environment = "Development"
    Project     = "CloudMart"
  }
}

resource "aws_dynamodb_table" "cloudmart_orders" {
  name           = "cloudmart-orders"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  attribute {
    name = "id"
    type = "S"
  }
  
  tags = {
    Name        = "cloudmart-orders"
    Environment = "Development"
    Project     = "CloudMart"
  }
}

resource "aws_dynamodb_table" "cloudmart_tickets" {
  name           = "cloudmart-tickets"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  attribute {
    name = "id"
    type = "S"
  }
  
  tags = {
    Name        = "cloudmart-tickets"
    Environment = "Development"
    Project     = "CloudMart"
  }
}

# Get the latest Amazon Linux 2 AMI (free tier eligible)
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create a security group for the EC2 instance
resource "aws_security_group" "workstation_sg" {
  name        = "workstation-sg"
  description = "Security group for workstation EC2 instance"

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Note: For production, restrict to your IP
    description = "SSH access"
  }

  # Port 5000 access
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Port 5000 access"
  }

  # Port 5001 access
  ingress {
    from_port   = 5001
    to_port     = 5001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Port 5001 access"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "workstation-sg"
  }
}

# Get existing IAM role
data "aws_iam_role" "ec2_admin_role" {
  name = "EC2Admin"
}

# Create an instance profile with the IAM role
resource "aws_iam_instance_profile" "ec2_admin_profile" {
  name = "workstation-profile"
  role = data.aws_iam_role.ec2_admin_role.name
}

# Create ECR Repositories for our applications
resource "aws_ecr_repository" "cloudmart_backend" {
  name                 = "cloudmart-backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
  
  tags = {
    Name        = "cloudmart-backend"
    Environment = "Development"
    Project     = "CloudMart"
  }
}

resource "aws_ecr_repository" "cloudmart_frontend" {
  name                 = "cloudmart-frontend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
  
  tags = {
    Name        = "cloudmart-frontend"
    Environment = "Development"
    Project     = "CloudMart"
  }
}

# Create IAM Policy for EKS Node Group
resource "aws_iam_role" "eks_node_group" {
  name = "eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

# Create IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# Create the EC2 instance
resource "aws_instance" "workstation" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"  # Free tier eligible
  iam_instance_profile   = aws_iam_instance_profile.ec2_admin_profile.name
  vpc_security_group_ids = [aws_security_group.workstation_sg.id]
  user_data              = file("${path.module}/user-data.sh")
  user_data_replace_on_change = true
  
  # You can add a key pair for SSH access
  # key_name = "your-key-pair-name"
  
  root_block_device {
    volume_size = 20  # Increased from 8 GB to ensure enough space for Docker and applications
    volume_type = "gp3"  # Using gp3 for better performance and still eligible for free tier
    encrypted   = true
  }
  
  tags = {
    Name        = "workstation"
    Environment = "Development"
    Provisioner = "Terraform"
  }

  # Add a dependency to ensure the IAM role is available before the instance is created
  depends_on = [aws_iam_instance_profile.ec2_admin_profile]

  # Enable termination protection
  disable_api_termination = false  # Set to true in production to prevent accidental termination
  
  # Enable detailed monitoring (note: not free tier eligible)
  monitoring = false
}

# Elastic IP for fixed address
resource "aws_eip" "workstation_eip" {
  instance = aws_instance.workstation.id
  domain   = "vpc"
  
  tags = {
    Name = "workstation-eip"
  }
}

# Output the public IP of the instance
output "public_ip" {
  value = aws_eip.workstation_eip.public_ip
}

# Output the public DNS of the instance
output "public_dns" {
  value = aws_instance.workstation.public_dns
}

# Output when setup is complete
output "setup_instructions" {
  value = "Connect via SSH using: ssh ec2-user@${aws_eip.workstation_eip.public_ip}. Setup will be completed when /home/ec2-user/setup-complete.log exists. Detailed logs are in /home/ec2-user/logs/"
}
