# CloudMart Kubernetes Deployment with Ansible

This Ansible project automates the deployment of CloudMart application to AWS EKS (Elastic Kubernetes Service).

## Project Structure

```
cloudmart-ansible/
├── ansible.cfg             # Ansible configuration
├── inventory.ini           # Inventory file for the workstation
├── deploy-cloudmart.yml    # Main playbook for deployment
├── cleanup-cloudmart.yml   # Playbook to clean up resources
├── group_vars/
│   └── all.yml             # Global variables
└── roles/                  # Ansible roles
    ├── common/             # Common setup tasks
    ├── aws_setup/          # AWS CLI, eksctl, kubectl setup
    ├── eks_cluster/        # EKS cluster creation
    ├── ecr_images/         # ECR repositories and Docker images
    └── k8s_deployment/     # Kubernetes deployment
```

## Prerequisites

1. An EC2 instance created with the provided Terraform script
2. SSH access to the EC2 instance
3. AWS IAM user with appropriate permissions

## Configuration

Before running the playbooks, update the following files:

1. `inventory.ini`: Replace `WORKSTATION_IP` with your EC2 instance's public IP and update the SSH key path
2. `group_vars/all.yml`: Update AWS configuration, API keys, and other variables

## Deployment

To deploy CloudMart to Kubernetes:

```bash
# From your local machine
ansible-playbook -i inventory.ini deploy-cloudmart.yml
```

## Cleanup

To remove all Kubernetes resources and delete the EKS cluster:

```bash
# From your local machine
ansible-playbook -i inventory.ini cleanup-cloudmart.yml
```

## Roles Description

1. **common**: Installs system dependencies and prepares directories
2. **aws_setup**: Configures AWS CLI and installs eksctl and kubectl
3. **eks_cluster**: Creates the EKS cluster and IAM service account
4. **ecr_images**: Sets up ECR repositories and builds/pushes Docker images
5. **k8s_deployment**: Deploys the application to Kubernetes

## Architecture

This deployment creates:

1. An EKS cluster with t3.medium nodes in AWS us-east-1 region
2. ECR repositories for backend and frontend Docker images
3. Kubernetes deployments for the CloudMart backend and frontend
4. LoadBalancer services to expose both components

## Accessing the Application

After successful deployment, the playbook will output URLs for:

- Backend API: http://[backend-loadbalancer]:5000
- Frontend: http://[frontend-loadbalancer]:5001

You can also get these endpoints by running:

```bash
kubectl get svc
```
