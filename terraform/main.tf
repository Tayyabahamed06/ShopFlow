terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─── ECR Repositories ───────────────────────────────────────────────
resource "aws_ecr_repository" "user_service" {
  name                 = "shopflow-user-service"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecr_repository" "product_service" {
  name                 = "shopflow-product-service"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecr_repository" "order_service" {
  name                 = "shopflow-order-service"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# ─── DynamoDB Tables ────────────────────────────────────────────────
resource "aws_dynamodb_table" "users" {
  name         = "shopflow-users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"

  attribute {
    name = "userId"
    type = "S"
  }

  tags = { Project = "ShopFlow", Service = "user" }
}

resource "aws_dynamodb_table" "products" {
  name         = "shopflow-products"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "productId"

  attribute {
    name = "productId"
    type = "S"
  }

  tags = { Project = "ShopFlow", Service = "product" }
}

resource "aws_dynamodb_table" "orders" {
  name         = "shopflow-orders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "orderId"

  attribute {
    name = "orderId"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  global_secondary_index {
    name            = "userId-index"
    hash_key        = "userId"
    projection_type = "ALL"
  }

  tags = { Project = "ShopFlow", Service = "order" }
}

# ─── Lambda Functions ───────────────────────────────────────────────
resource "aws_lambda_function" "user_service" {
  function_name = "shopflow-user-service"
  role          = aws_iam_role.lambda_exec.arn
  package_type  = "Zip"
  filename      = "${path.module}/../services/user-service/function.zip"
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 30

  environment {
    variables = {
      USERS_TABLE                         = aws_dynamodb_table.users.name
      AWS_NODEJS_CONNECTION_REUSE_ENABLED = "1"
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_policy]
  tags       = { Project = "ShopFlow", Service = "user" }
}

resource "aws_lambda_function" "product_service" {
  function_name = "shopflow-product-service"
  role          = aws_iam_role.lambda_exec.arn
  package_type  = "Zip"
  filename      = "${path.module}/../services/product-service/function.zip"
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 30

  environment {
    variables = {
      PRODUCTS_TABLE                      = aws_dynamodb_table.products.name
      AWS_NODEJS_CONNECTION_REUSE_ENABLED = "1"
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_policy]
  tags       = { Project = "ShopFlow", Service = "product" }
}

resource "aws_lambda_function" "order_service" {
  function_name = "shopflow-order-service"
  role          = aws_iam_role.lambda_exec.arn
  package_type  = "Zip"
  filename      = "${path.module}/../services/order-service/function.zip"
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 30

  environment {
    variables = {
      ORDERS_TABLE                        = aws_dynamodb_table.orders.name
      AWS_NODEJS_CONNECTION_REUSE_ENABLED = "1"
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_policy]
  tags       = { Project = "ShopFlow", Service = "order" }
}

# ─── API Gateway ────────────────────────────────────────────────────
resource "aws_api_gateway_rest_api" "shopflow" {
  name        = "shopflow-api"
  description = "ShopFlow Microservices API"
}

resource "aws_lambda_permission" "user_apigw" {
  statement_id  = "AllowAPIGatewayInvokeUser"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.user_service.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.shopflow.execution_arn}/*/*"
}

resource "aws_lambda_permission" "product_apigw" {
  statement_id  = "AllowAPIGatewayInvokeProduct"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.product_service.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.shopflow.execution_arn}/*/*"
}

resource "aws_lambda_permission" "order_apigw" {
  statement_id  = "AllowAPIGatewayInvokeOrder"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.order_service.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.shopflow.execution_arn}/*/*"
}

# ─── /users routes ──────────────────────────────────────────────────
resource "aws_api_gateway_resource" "users" {
  rest_api_id = aws_api_gateway_rest_api.shopflow.id
  parent_id   = aws_api_gateway_rest_api.shopflow.root_resource_id
  path_part   = "users"
}

resource "aws_api_gateway_resource" "users_proxy" {
  rest_api_id = aws_api_gateway_rest_api.shopflow.id
  parent_id   = aws_api_gateway_resource.users.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "users_any" {
  rest_api_id   = aws_api_gateway_rest_api.shopflow.id
  resource_id   = aws_api_gateway_resource.users.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "users_proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.shopflow.id
  resource_id   = aws_api_gateway_resource.users_proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "users" {
  rest_api_id             = aws_api_gateway_rest_api.shopflow.id
  resource_id             = aws_api_gateway_resource.users.id
  http_method             = aws_api_gateway_method.users_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.user_service.invoke_arn
}

resource "aws_api_gateway_integration" "users_proxy" {
  rest_api_id             = aws_api_gateway_rest_api.shopflow.id
  resource_id             = aws_api_gateway_resource.users_proxy.id
  http_method             = aws_api_gateway_method.users_proxy_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.user_service.invoke_arn
}

# ─── /products routes ───────────────────────────────────────────────
resource "aws_api_gateway_resource" "products" {
  rest_api_id = aws_api_gateway_rest_api.shopflow.id
  parent_id   = aws_api_gateway_rest_api.shopflow.root_resource_id
  path_part   = "products"
}

resource "aws_api_gateway_resource" "products_proxy" {
  rest_api_id = aws_api_gateway_rest_api.shopflow.id
  parent_id   = aws_api_gateway_resource.products.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "products_any" {
  rest_api_id   = aws_api_gateway_rest_api.shopflow.id
  resource_id   = aws_api_gateway_resource.products.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "products_proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.shopflow.id
  resource_id   = aws_api_gateway_resource.products_proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "products" {
  rest_api_id             = aws_api_gateway_rest_api.shopflow.id
  resource_id             = aws_api_gateway_resource.products.id
  http_method             = aws_api_gateway_method.products_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.product_service.invoke_arn
}

resource "aws_api_gateway_integration" "products_proxy" {
  rest_api_id             = aws_api_gateway_rest_api.shopflow.id
  resource_id             = aws_api_gateway_resource.products_proxy.id
  http_method             = aws_api_gateway_method.products_proxy_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.product_service.invoke_arn
}

# ─── /orders routes ─────────────────────────────────────────────────
resource "aws_api_gateway_resource" "orders" {
  rest_api_id = aws_api_gateway_rest_api.shopflow.id
  parent_id   = aws_api_gateway_rest_api.shopflow.root_resource_id
  path_part   = "orders"
}

resource "aws_api_gateway_resource" "orders_proxy" {
  rest_api_id = aws_api_gateway_rest_api.shopflow.id
  parent_id   = aws_api_gateway_resource.orders.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "orders_any" {
  rest_api_id   = aws_api_gateway_rest_api.shopflow.id
  resource_id   = aws_api_gateway_resource.orders.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "orders_proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.shopflow.id
  resource_id   = aws_api_gateway_resource.orders_proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "orders" {
  rest_api_id             = aws_api_gateway_rest_api.shopflow.id
  resource_id             = aws_api_gateway_resource.orders.id
  http_method             = aws_api_gateway_method.orders_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.order_service.invoke_arn
}

resource "aws_api_gateway_integration" "orders_proxy" {
  rest_api_id             = aws_api_gateway_rest_api.shopflow.id
  resource_id             = aws_api_gateway_resource.orders_proxy.id
  http_method             = aws_api_gateway_method.orders_proxy_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.order_service.invoke_arn
}

# ─── Deployment ─────────────────────────────────────────────────────
resource "aws_api_gateway_deployment" "shopflow" {
  rest_api_id = aws_api_gateway_rest_api.shopflow.id

  depends_on = [
    aws_api_gateway_integration.users,
    aws_api_gateway_integration.users_proxy,
    aws_api_gateway_integration.products,
    aws_api_gateway_integration.products_proxy,
    aws_api_gateway_integration.orders,
    aws_api_gateway_integration.orders_proxy,
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.shopflow.id
  rest_api_id   = aws_api_gateway_rest_api.shopflow.id
  stage_name    = "prod"
}

# ─── CloudWatch Log Groups ───────────────────────────────────────────
resource "aws_cloudwatch_log_group" "user_service" {
  name              = "/aws/lambda/shopflow-user-service"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "product_service" {
  name              = "/aws/lambda/shopflow-product-service"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "order_service" {
  name              = "/aws/lambda/shopflow-order-service"
  retention_in_days = 7
}

# ─── CloudWatch Alarms ───────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "user_errors" {
  alarm_name          = "shopflow-user-service-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "User service error rate too high"

  dimensions = {
    FunctionName = aws_lambda_function.user_service.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "product_errors" {
  alarm_name          = "shopflow-product-service-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Product service error rate too high"

  dimensions = {
    FunctionName = aws_lambda_function.product_service.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "order_errors" {
  alarm_name          = "shopflow-order-service-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Order service error rate too high"

  dimensions = {
    FunctionName = aws_lambda_function.order_service.function_name
  }
}
