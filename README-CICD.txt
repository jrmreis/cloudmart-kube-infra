CloudMart CI/CD Pipeline
This document describes the Continuous Integration and Continuous Deployment pipeline for the CloudMart application.

Overview
The pipeline automates the following steps:

Testing the application code
Building Docker images
Pushing images to Amazon ECR
Deploying the application to Kubernetes using Ansible
Pipeline Architecture
GitHub Repository
       │
       ▼
┌─────────────┐
│  GitHub     │
│  Actions    │  ◄── Triggered on push to main/develop
└─────┬───────┘
      │
      ▼
┌─────────────┐     ┌─────────────┐
│  Test Job   │     │  AWS         │
│  (npm test) │     │  ECR         │ ◄── Store Docker images
└─────┬───────┘     └──────┬──────┘
      │                    │
      ▼                    │
┌─────────────┐            │
│  Build Job  │────────────┘
│  (Docker)   │
└─────┬───────┘
      │
      ▼
┌─────────────┐     ┌─────────────┐
│  Deploy Job │────►│  AWS         │
│  (Ansible)  │     │  EKS         │ ◄── Run Kubernetes workloads
└─────────────┘     └─────────────┘
Prerequisites
AWS Account with appropriate permissions
EKS Cluster already provisioned
ECR Repositories created for frontend and backend
GitHub repository with CloudMart code and Ansible configuration
GitHub Actions Workflow
The workflow is defined in .github/workflows/cloudmart-ci-cd.yml and consists of three jobs:

Test: Runs unit tests for frontend and backend
Build-and-Push: Builds Docker images and pushes them to ECR
Deploy: Uses Ansible to deploy the application to EKS
Branch Strategy
main: Production environment
develop: Staging environment
Feature branches should be created from develop and merged back via Pull Requests
Required GitHub Secrets
The following secrets must be added to your GitHub repository:

AWS_ACCESS_KEY_ID: Access key for AWS IAM user
AWS_SECRET_ACCESS_KEY: Secret key for AWS IAM user
Monitoring Deployments
Check GitHub Actions for workflow status
You can use Ansible logs for detailed deployment information
Use kubectl to verify the deployment status:
bash
kubectl get pods
kubectl get deployments
kubectl get services
kubectl get ingress
Rollback Procedure
If a deployment fails or causes issues:

Find the previous successful workflow run in GitHub Actions
Note the commit SHA or tag of the previous working version
Manually trigger the workflow with the previous version:
bash
# Update the extra_vars.yml with previous image tags
ansible-playbook -i inventory/production.ini deploy-cloudmart.yml --extra-vars "@rollback_vars.yml"
Troubleshooting
Common issues and solutions:

Failed Tests: Check test logs in GitHub Actions for details
Image Push Failures: Verify IAM permissions for ECR
Deployment Failures: Check Ansible logs and kubectl events
