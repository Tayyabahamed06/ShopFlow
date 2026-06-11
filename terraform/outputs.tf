output "api_gateway_url" {
  description = "ShopFlow API base URL"
  value       = "https://${aws_api_gateway_rest_api.shopflow.id}.execute-api.${var.aws_region}.amazonaws.com/prod"
}

output "user_service_url" {
  value = "https://${aws_api_gateway_rest_api.shopflow.id}.execute-api.${var.aws_region}.amazonaws.com/prod/users"
}

output "product_service_url" {
  value = "https://${aws_api_gateway_rest_api.shopflow.id}.execute-api.${var.aws_region}.amazonaws.com/prod/products"
}

output "order_service_url" {
  value = "https://${aws_api_gateway_rest_api.shopflow.id}.execute-api.${var.aws_region}.amazonaws.com/prod/orders"
}

output "ecr_user_service_url" {
  value = aws_ecr_repository.user_service.repository_url
}

output "ecr_product_service_url" {
  value = aws_ecr_repository.product_service.repository_url
}

output "ecr_order_service_url" {
  value = aws_ecr_repository.order_service.repository_url
}

output "users_table_name" {
  value = aws_dynamodb_table.users.name
}

output "products_table_name" {
  value = aws_dynamodb_table.products.name
}

output "orders_table_name" {
  value = aws_dynamodb_table.orders.name
}
