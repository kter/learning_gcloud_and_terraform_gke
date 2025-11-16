#!/bin/bash
# GKE学習環境の完全削除スクリプト
# 
# 警告: このスクリプトはすべてのリソースを削除します！
# データベースのデータも失われます！
#
# 使用方法:
#   ./scripts/destroy-all.sh dev
#   ./scripts/destroy-all.sh stg

set -e

ENV=${1:-dev}

echo "⚠️  WARNING: This will PERMANENTLY DELETE all resources in ${ENV} environment!"
echo "⚠️  Including all data in Cloud SQL database!"
echo ""
read -p "Are you sure? Type 'yes' to continue: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "❌ Cancelled."
  exit 1
fi

echo ""
echo "🗑️ Destroying ${ENV} environment..."

cd terraform
terraform workspace select $ENV
terraform destroy -var-file=${ENV}.tfvars -auto-approve

echo ""
echo "🎉 ${ENV} environment destroyed successfully!"
echo ""
echo "💰 You will no longer be charged for these resources."
echo ""
echo "To recreate, run: make init-${ENV} && make apply-${ENV}"

