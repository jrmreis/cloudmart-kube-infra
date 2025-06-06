# CloudMart AI Assistant Role

This Ansible role deploys the complete AI Assistant infrastructure for the CloudMart e-commerce platform. It creates a serverless, event-driven architecture using AWS services to power AI-enhanced product recommendations and real-time data processing.

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   DynamoDB      │    │     Lambda      │    │    Bedrock      │
│   Tables        │────│   Functions     │────│  AI Models      │
│                 │    │                 │    │                 │
│ • Products      │    │ • List Products │    │ • Claude        │
│ • Orders        │    │ • BigQuery Sync │    │ • Claude Instant│
│ • Tickets       │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │
         │ DynamoDB Streams      │ CloudWatch Logs
         ▼                       ▼
┌─────────────────┐    ┌─────────────────┐
│   BigQuery      │    │   CloudWatch    │
│   Analytics     │    │   Monitoring    │
└─────────────────┘    └─────────────────┘
```

## 📋 Components

### DynamoDB Tables
- **Products Table**: Stores product catalog for AI recommendations
- **Orders Table**: Captures order data with stream processing enabled
- **Tickets Table**: Manages customer support tickets

### Lambda Functions
- **List Products**: Provides product data to Bedrock AI models
- **DynamoDB to BigQuery**: Real-time data synchronization for analytics

### AI Integration
- **Amazon Bedrock**: Powers intelligent product recommendations
- **Model Support**: Claude v2, Claude Instant v1

### Monitoring & Security
- **CloudWatch**: Comprehensive logging and monitoring
- **IAM**: Least-privilege security model
- **Event-driven**: DynamoDB Streams for real-time processing

## 🚀 Quick Start

### Prerequisites

1. **AWS Configuration**
   ```bash
   aws configure
   # or set environment variables
   export AWS_ACCESS_KEY_ID=your_key
   export AWS_SECRET_ACCESS_KEY=your_secret
   export AWS_DEFAULT_REGION=us-east-1
   ```

2. **Ansible Requirements**
   ```bash
   ansible-galaxy collection install amazon.aws
   pip install boto3 botocore
   ```

3. **Lambda Artifacts**
   ```bash
   mkdir lambda-artifacts
   # Place your Lambda zip files here:
   # - list_products.zip
   # - dynamodb_to_bigquery.zip
   ```

### Basic Deployment

```bash
# Deploy to development environment
ansible-playbook deploy-cloudmart.yml --tags ai-assistant

# Deploy to production
ansible-playbook deploy-cloudmart.yml -e environment=prod --tags ai-assistant

# Deploy with custom configuration
ansible-playbook deploy-cloudmart.yml -e environment=staging -e aws_region=us-west-2 --tags ai-assistant
```

## ⚙️ Configuration

### Default Variables (`defaults/main.yml`)

```yaml
# AWS Configuration
aws_region: "us-east-1"
project_name: "cloudmart"
environment: "dev"

# Lambda Configuration
lambda_functions:
  - name: "cloudmart-list-products-dev"
    runtime: "nodejs20.x"
    timeout: 30
    memory_size: 256

# Bedrock Configuration
bedrock_enabled: true
bedrock_models: ["claude-v2", "claude-instant-v1"]
```

### Environment-Specific Configuration

Create environment-specific variable files:

```yaml
# group_vars/dev.yml
environment: "dev"
lambda_memory_size: 256
lambda_timeout: 30

# group_vars/prod.yml
environment: "prod"
lambda_memory_size: 1024
lambda_timeout: 300
```

### Custom Variables

Override any default variable in your playbook:

```yaml
- hosts: localhost
  vars:
    aws_region: "eu-west-1"
    project_name: "mycompany-cloudmart"
    bedrock_enabled: false
  roles:
    - ai-assistant
```

## 📁 Directory Structure

```
roles/ai-assistant/
├── defaults/
│   └── main.yml          # Default variables
├── vars/
│   └── main.yml          # Internal variables
├── tasks/
│   ├── main.yml          # Main task orchestration
│   ├── validate.yml      # Input validation
│   ├── dynamodb.yml      # DynamoDB table creation
│   ├── iam.yml           # IAM roles and policies
│   ├── lambda.yml        # Lambda function deployment
│   ├── cloudwatch.yml    # Monitoring setup
│   ├── bedrock.yml       # AI integration
│   ├── events.yml        # Event source mapping
│   ├── cleanup.yml       # Resource cleanup
│   └── summary.yml       # Deployment summary
├── meta/
│   └── main.yml          # Role metadata
└── README.md             # This file
```

## 🏷️ Tags

Use tags to run specific parts of the deployment:

```bash
# Deploy only DynamoDB tables
ansible-playbook deploy-cloudmart.yml --tags dynamodb

# Deploy only Lambda functions
ansible-playbook deploy-cloudmart.yml --tags lambda

# Setup monitoring only
ansible-playbook deploy-cloudmart.yml --tags cloudwatch

# Full infrastructure deployment
ansible-playbook deploy-cloudmart.yml --tags infrastructure

# AI/Bedrock integration only
ansible-playbook deploy-cloudmart.yml --tags ai,bedrock
```

Available tags:
- `validation` - Input validation
- `dynamodb` - DynamoDB tables
- `iam` - IAM roles and policies
- `lambda` - Lambda functions
- `cloudwatch` - Monitoring
- `bedrock` - AI integration
- `events` - Event source mapping
- `cleanup` - Resource cleanup
- `summary` - Deployment summary
- `infrastructure` - All infrastructure components
- `ai` - AI-related components

## 🛠️ Advanced Usage

### Multi-Region Deployment

```bash
# Deploy to multiple regions
for region in us-east-1 us-west-2 eu-west-1; do
  ansible-playbook deploy-cloudmart.yml \
    -e aws_region=$region \
    -e environment=prod \
    --tags ai-assistant
done
```

### Custom Lambda Configuration

```yaml
lambda_functions:
  - name: "{{ project_name }}-custom-function-{{ environment }}"
    filename: "./custom-function.zip"
    handler: "custom.handler"
    runtime: "python3.9"
    timeout: 60
    memory_size: 512
    environment_variables:
      CUSTOM_VAR: "custom_value"
```

### VPC Integration

```yaml
# Enable VPC deployment
cloudmart_vpc_config:
  SubnetIds:
    - subnet-12345678
    - subnet-87654321
  SecurityGroupIds:
    - sg-12345678
```

## 🧹 Cleanup

To remove all AI Assistant resources:

```bash
# Cleanup with confirmation prompt
ansible-playbook deploy-cloudmart.yml --tags cleanup -e cleanup=true

# Cleanup specific environment
ansible-playbook deploy-cloudmart.yml --tags cleanup -e cleanup=true -e environment=dev
```

⚠️ **Warning**: Cleanup operations are irreversible and will delete all data!

## 📊 Monitoring

### CloudWatch Dashboards

The role automatically creates:
- Lambda function metrics
- DynamoDB table metrics
- Error rate alarms
- Performance monitoring

### Log Analysis

```bash
# View Lambda logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/cloudmart"

# Stream real-time logs
aws logs tail /aws/lambda/cloudmart-list-products-dev --follow
```

### Metrics

Key metrics to monitor:
- Lambda invocation count
- Lambda error rate
- Lambda duration
- DynamoDB read/write capacity
- DynamoDB throttle events

## 🔧 Troubleshooting

### Common Issues

1. **Lambda deployment fails**
   ```bash
   # Check if zip files exist
   ls -la lambda-artifacts/
   
   # Verify file permissions
   chmod 644 lambda-artifacts/*.zip
   ```

2. **DynamoDB table creation timeout**
   ```bash
   # Check AWS service health
   aws dynamodb describe-limits --region us-east-1
   ```

3. **IAM permission errors**
   ```bash
   # Verify AWS credentials
   aws sts get-caller-identity
   
   # Check IAM permissions
   aws iam simulate-principal-policy \
     --policy-source-arn $(aws sts get-caller-identity --query Arn --output text) \
     --action-names dynamodb:CreateTable
   ```

### Debug Mode

Enable verbose output:

```bash
ansible-playbook deploy-cloudmart.yml --tags ai-assistant -vvv
```

### Validation

The role includes comprehensive validation:
- AWS region format validation
- Environment value validation
- Lambda artifact existence check
- Required variable validation

## 🤝 Contributing

1. Follow the existing code structure
2. Add appropriate tags to new tasks
3. Update documentation for new features
4. Test in multiple environments
5. Follow Ansible best practices

## 📄 License

MIT License - see LICENSE file for details.

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section
2. Review CloudWatch logs
3. Verify AWS service limits
4. Create an issue in the repository

---

**CloudMart AI Assistant Role** - Powering intelligent e-commerce with AWS and AI 🚀
