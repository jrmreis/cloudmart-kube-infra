# CloudMart Deployment

## Structure
cloudmart-ansible/
├── ansible.cfg
├── inventory/
│   ├── production.ini
│   ├── staging.ini
│   └── development.ini
├── playbooks/
│   ├── deploy-cloudmart.yml
│   ├── cleanup-cloudmart.yml
│   └── maintenance/
│       ├── backup.yml
│       ├── update-certificates.yml
│       └── rolling-updates.yml
├── group_vars/
│   ├── all.yml
│   ├── production.yml
│   ├── staging.yml
│   └── development.yml
└── roles/
    ├── common/
    │   ├── defaults/
    │   │   └── main.yml
    │   ├── tasks/
    │   │   └── main.yml
    │   └── handlers/
    │       └── main.yml
    ├── aws_setup/
    │   ├── defaults/
    │   │   └── main.yml
    │   ├── tasks/
    │   │   └── main.yml
    │   └── handlers/
    │       └── main.yml
    ├── eks_cluster/
    │   ├── defaults/
    │   │   └── main.yml
    │   ├── tasks/
    │   │   ├── main.yml
    │   │   ├── create_cluster.yml
    │   │   └── update_cluster.yml
    │   └── templates/
    │       └── eks-config.yaml.j2
    ├── ecr_images/
    │   ├── defaults/
    │   │   └── main.yml
    │   ├── tasks/
    │   │   ├── main.yml
    │   │   ├── build_images.yml
    │   │   └── push_images.yml
    │   └── templates/
    │       ├── Dockerfile.backend.j2
    │       └── Dockerfile.frontend.j2
    ├── k8s_deployment/
    │   ├── defaults/
    │   │   └── main.yml
    │   ├── tasks/
    │   │   ├── main.yml
    │   │   ├── deploy_backend.yml
    │   │   ├── deploy_frontend.yml
    │   │   └── deploy_database.yml
    │   └── templates/
    │       ├── cloudmart-backend.yaml.j2
    │       ├── cloudmart-frontend.yaml.j2
    │       ├── cloudmart-ingress.yaml.j2
    │       ├── cloudmart-configmap.yaml.j2
    │       └── cloudmart-secrets.yaml.j2
    ├── monitoring/
    │   ├── defaults/
    │   │   └── main.yml
    │   ├── tasks/
    │   │   └── main.yml
    │   └── templates/
    │       ├── prometheus-values.yaml.j2
    │       └── grafana-values.yaml.j2
    └── security/
        ├── defaults/
        │   └── main.yml
        ├── tasks/
        │   └── main.yml
        └── templates/
            ├── network-policies.yaml.j2
            └── pod-security-policies.yaml.j2

## Setup Information
- Instance ID: i-08fc4aa6f8f7c3ddd
- Public IP: 54.235.136.182
- Setup completed: Mon Apr 28 21:12:02 UTC 2025

## Important Directories
- CloudMart Source: /home/ec2-user/cloudmart-infrastructure
- Challenge Files: /home/ec2-user/challenge-day2
- Logs: /home/ec2-user/logs

## Health Check
Run the health check script to see the current status of your deployment:


## Docker Containers
Access the applications directly:
- Backend: http://54.235.136.182:5000
- Frontend: http://54.235.136.182:5001

## Logs
All setup logs are available in the /home/ec2-user/logs directory.

## Log File
A unified log of the setup process is available at:
- /home/ec2-user/logs/cloudmart_setup_20250428-2107.log
- Symlinked at /home/ec2-user/logs/latest.log
# cloudmart-kube-infra

ansible-playbook -i inventory.ini deploy-cloudmart.yml --connection=local

