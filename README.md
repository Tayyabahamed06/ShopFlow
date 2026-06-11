# ShopFlow — Production-Grade Microservices Platform

A fully serverless e-commerce backend built as independent microservices on AWS.

## Architecture
- **User Service** — Registration, login, profiles (Lambda + DynamoDB)
- **Product Service** — Catalog, product creation, listing (Lambda + DynamoDB)
- **Order Service** — Order placement, status tracking (Lambda + DynamoDB + GSI)
- **API Gateway** — Single entry point routing to all 3 services
- **ECR** — Docker images for each service

## DevOps Stack
- **Terraform** — Full IaC (45 resources)
- **GitHub Actions** — CI/CD pipeline with 3 stages
- **OIDC** — Keyless AWS authentication from GitHub
- **Trivy** — Docker image security scanning
- **CloudWatch** — Logs + error alarms per service

## Live API
Base URL: https://448fssifzi.execute-api.us-east-1.amazonaws.com/prod

### Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /users/register | Register a new user |
| POST | /users/login | Login |
| GET | /users/{userId} | Get user profile |
| POST | /products | Create product |
| GET | /products | List all products |
| GET | /products/{productId} | Get product |
| POST | /orders | Place an order |
| GET | /orders/{orderId} | Get order |
| GET | /orders/user/{userId} | Get user's orders |
| PATCH | /orders/{orderId}/status | Update order status |

## Infrastructure
Provisioned with Terraform. To deploy:
```bash
cd terraform
terraform init
terraform apply
```

## CI/CD
Every push to main triggers:
1. Trivy security scan on all 3 services
2. Docker build + push to ECR
3. Lambda deployment via zip
