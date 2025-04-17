# EKS Infrastructure as Code

This Terraform configuration sets up an AWS EKS cluster with essential add-ons and monitoring tools for this purpose.

## Architecture

The infrastructure includes:
- EKS cluster with managed node groups
- VPC with public and private subnets
- Essential EKS add-ons
- Monitoring stack (Prometheus, Grafana)
- Logging stack (FluentBit + CloudWatch)
- ArgoCD for GitOps
- cert-manager for TLS certificate management

## Prerequisites

- Terraform (>= 1.0.0)
- AWS CLI configured with appropriate credentials
- kubectl

## Initial Setup Steps

Before running Terraform, you need to set up the S3 bucket and DynamoDB table for state management:

1. Setup AWS Cli and configure AWS credentials:
  - https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
  - https://docs.aws.amazon.com/cli/v1/userguide/cli-chap-configure.html

2. Create S3 bucket for Terraform state:
```bash
# Create bucket in eu-central-1 region
aws s3api create-bucket --bucket nuvolar-infra-terraform-state --region eu-central-1 --create-bucket-configuration LocationConstraint=eu-central-1
  ```
```bash 
# Enable versioning
aws s3api put-bucket-versioning --bucket nuvolar-infra-terraform-state --versioning-configuration Status=Enabled
  ```
```bash
# Enable server-side encryption
aws s3api put-bucket-encryption --bucket nuvolar-infra-terraform-state --server-side-encryption-configuration '{\"Rules\": [{\"ApplyServerSideEncryptionByDefault\": {\"SSEAlgorithm\": \"AES256\"}}]}'
  ```
```bash
# Enable Object Lock (deletion protection)
aws s3api put-object-lock-configuration --bucket nuvolar-infra-terraform-state --object-lock-configuration '{\"ObjectLockEnabled\": \"Enabled\", \"Rule\": {\"DefaultRetention\": {\"Mode\": \"COMPLIANCE\", \"Days\": 1}}}'
  ```
```bash
# Apply bucket policy to prevent accidental deletion
aws s3api put-bucket-policy --bucket nuvolar-infra-terraform-state --policy '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "DenyDeleteObject",
            "Effect": "Deny",
            "Principal": "*",
            "Action": [
                "s3:DeleteObject",
                "s3:DeleteObjectVersion"
            ],
            "Resource": "arn:aws:s3:::nuvolar-infra-terraform-state/*"
        }
    ]
}'
```
3. Create DynamoDB table for state locking:
```bash
aws dynamodb create-table --table-name nuvolar-infra-terraform-state-lock --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --deletion-protection-enabled
```

## Configuration

### Variables

Required variables in `terraform.tfvars`:
- `region`: AWS region
- `project_name`: Project name for resource tagging
- `cluster_name`: EKS cluster name
- `node_group_name`: Node group name
- `domain_name`: Domain name for Ingress resources
- `route53_hosted_zone_id`: Route53 hosted zone ID

## Provisioning

### First run
1. Important: Comment all code in `ingresses.tf`, it requires:
   - DNS records to be resolvable
   - Kubernetes cluster to be fully ready
   - cert-manager to be operational
  so `letsencrypt_dns_clusterissuer` makes problems. 
  Unmenaged to resolve with 'depends_on', this is temporary and need to be fixed.
2. Initialize Terraform:
   ```bash
   terraform init
   ```
3. Review the plan:
   ```bash
   terraform plan
   ```
4. Apply the configuration:
   ```bash
   terraform apply
   ```
5. After the cluster is up and running, wait for DNS propagation and then:
   - Uncomment `letsencrypt_dns_clusterissuer` from `ingresses.tf`
   - Run `terraform plan` and `terraform apply` again to create the cluster issuer
   - Uncomment ingresses definition from `ingresses.tf`
   - Run `terraform plan` and `terraform apply`
6. EKS cluster is ready

Note: It's possible that there is not need for all these steps, but this works.

### Updating Resources

To update resources:
1. Modify the configuration
2. Run `terraform plan` to review changes
3. Apply changes with `terraform apply`

### Cleanup

To destroy all resources:
```bash
terraform destroy
```

### Updating Resources

To update resources:
1. Modify the configuration
2. Run `terraform plan` to review changes
3. Apply changes with `terraform apply`


## Desirable improvements
- Fix dependency `letsencrypt_dns_clusterissuer`
- Update all resources and providers to latest versions (if possible)
- Tune FluentBit config
- Switch to EFK from CloudWatch
- Create module for EKS
- Create Grafana dashboards

