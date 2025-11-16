#!/bin/bash
# GKE学習環境の完全停止スクリプト
# 
# 使用方法:
#   ./scripts/stop-all.sh dev
#   ./scripts/stop-all.sh stg

set -e

ENV=${1:-dev}

echo "🛑 Stopping ${ENV} environment..."

# Terraform workspace選択
cd terraform
terraform workspace select $ENV

# 1. ノードプールを0にスケール
echo "📉 Scaling down node pool to 0..."
CLUSTER_NAME=$(terraform output -raw gke_cluster_name)
ZONE=$(terraform output -raw zone)
NODE_POOL="primary-node-pool-${ENV}"

gcloud container clusters resize $CLUSTER_NAME \
  --node-pool=$NODE_POOL \
  --num-nodes=0 \
  --zone=$ZONE \
  --quiet

echo "✅ Node pool scaled to 0"

# 2. Cloud SQLを停止
echo "🗄️ Stopping Cloud SQL instance..."
DB_INSTANCE=$(terraform output -raw db_instance_name)

gcloud sql instances patch $DB_INSTANCE \
  --activation-policy=NEVER \
  --quiet

echo "✅ Cloud SQL instance stopped"

echo ""
echo "🎉 ${ENV} environment stopped successfully!"
echo ""
echo "💰 Estimated savings: ~$37-50/month"
echo ""
echo "To restart, run: ./scripts/start-all.sh ${ENV}"

