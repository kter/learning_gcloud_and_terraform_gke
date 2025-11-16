#!/bin/bash
# GKE学習環境の再開スクリプト
# 
# 使用方法:
#   ./scripts/start-all.sh dev
#   ./scripts/start-all.sh stg

set -e

ENV=${1:-dev}

echo "🚀 Starting ${ENV} environment..."

# Terraform workspace選択
cd terraform
terraform workspace select $ENV

# 1. Cloud SQLを起動
echo "🗄️ Starting Cloud SQL instance..."
DB_INSTANCE=$(terraform output -raw db_instance_name)

gcloud sql instances patch $DB_INSTANCE \
  --activation-policy=ALWAYS \
  --quiet

echo "✅ Cloud SQL instance started"
echo "⏳ Waiting for Cloud SQL to be ready..."
sleep 30

# 2. ノードプールをスケールアップ
echo "📈 Scaling up node pool to 2..."
CLUSTER_NAME=$(terraform output -raw gke_cluster_name)
ZONE=$(terraform output -raw zone)
NODE_POOL="primary-node-pool-${ENV}"

gcloud container clusters resize $CLUSTER_NAME \
  --node-pool=$NODE_POOL \
  --num-nodes=2 \
  --zone=$ZONE \
  --quiet

echo "✅ Node pool scaled to 2"
echo "⏳ Waiting for nodes to be ready..."
sleep 60

# 3. Podの状態確認
echo "📊 Checking pod status..."
gcloud container clusters get-credentials $CLUSTER_NAME \
  --zone=$ZONE \
  --project=$(terraform output -raw project_id)

kubectl get pods

echo ""
echo "🎉 ${ENV} environment started successfully!"
echo ""
echo "🌐 Application URL: https://$(terraform output -raw domain)"
echo ""
echo "💡 Note: It may take a few minutes for all services to be fully ready."

