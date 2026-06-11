#!/bin/bash
set -e

echo "📦 Building ShopFlow Lambda packages..."

SERVICES=("user-service" "product-service" "order-service")

for SERVICE in "${SERVICES[@]}"; do
  echo "→ Building $SERVICE..."
  cd services/$SERVICE
  npm install --production --silent
  zip -r function.zip index.js node_modules package.json > /dev/null
  echo "✅ $SERVICE packaged"
  cd ../..
done

echo ""
echo "🚀 All services packaged. Ready for Terraform."
