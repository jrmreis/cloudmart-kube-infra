cloudmart-ansible/
├── ansible.cfg
├── inventory.ini
├── deploy-cloudmart.yml
├── cleanup-cloudmart.yml
├── group_vars/
│   └── all.yml
└── roles/
    ├── common/
    │   ├── defaults/
    │   │   └── main.yml
    │   └── tasks/
    │       └── main.yml
    ├── aws_setup/
    │   ├── defaults/
    │   │   └── main.yml
    │   └── tasks/
    │       └── main.yml
    ├── eks_cluster/
    │   ├── defaults/
    │   │   └── main.yml
    │   └── tasks/
    │       └── main.yml
    ├── ecr_images/
    │   ├── defaults/
    │   │   └── main.yml
    │   ├── tasks/
    │   │   └── main.yml
    │   └── templates/
    │       ├── Dockerfile.backend.j2
    │       └── Dockerfile.frontend.j2
    └── k8s_deployment/
        ├── defaults/
        │   └── main.yml
        ├── tasks/
        │   └── main.yml
        └── templates/
            ├── cloudmart-backend.yaml.j2
            └── cloudmart-frontend.yaml.j2
