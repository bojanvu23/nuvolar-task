# Nuvolar Interview Task: Infrastructure & Application

This repository is part of an **interview task**. It demonstrates a modern approach to deploying cloud-native applications using Infrastructure as Code, Helm, and CI/CD best practices.

## Project Structure

- `github/` — A template CI pipeline that tests and builds an application, creates a Docker image, and pushes it to a Docker registry. The final step updates the remote repository containing Helm files, which are used for deploying the new version of the application. ArgoCD is used for GitOps to manage the deployment process.
- `helm/` — Helm charts for application services.
  - Each subfolder (e.g., `api-gateway`, `order-service`, `customer-service`) contains a Helm chart for deploying that service.
  Note: They should be in separate repository, but for this use-case is aceptable.
- `iac/` — Infrastructure as Code (Terraform files), used for provisioning AWS infrastructure.

## Accessable services

### Grafana
  -  https://grafana-nuvolar.aws-playground.space
  - `user: admin`
  - `pass: SuperSecret` 
   
### ArgoCD
  -  https://argocd-nuvolar.aws-playground.space
  - `user: admin`
  - `pass: ZeeVbLGxPH2KXBuX`
  

### CloudWatch Logs Dashboard
   - https://eu-central-1.console.aws.amazon.com/cloudwatch/home?region=eu-central-1#dashboards/dashboard/nuvolar-eks-cluster-public-logs