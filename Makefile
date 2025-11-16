.PHONY: help init-dev init-stg build-push-dev build-push-stg deploy-dev deploy-stg clean

# 環境変数
CURRENT_ENV := $(shell cd terraform && terraform workspace show)

help: ## このヘルプを表示
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# Terraform 初期化と環境セットアップ
init-dev: ## Dev環境の初期化（Terraform workspace: dev）
	@echo "🚀 Initializing Dev environment..."
	cd terraform && \
	terraform init && \
	terraform workspace select dev || terraform workspace new dev
	@echo "✅ Dev environment initialized"

init-stg: ## Stg環境の初期化（Terraform workspace: stg）
	@echo "🚀 Initializing Stg environment..."
	cd terraform && \
	terraform init && \
	terraform workspace select stg || terraform workspace new stg
	@echo "✅ Stg environment initialized"

# Terraformプラン
plan-dev: ## Dev環境のTerraformプランを表示
	cd terraform && \
	terraform workspace select dev && \
	terraform plan -var-file=dev.tfvars

plan-stg: ## Stg環境のTerraformプランを表示
	cd terraform && \
	terraform workspace select stg && \
	terraform plan -var-file=stg.tfvars

# Terraform適用
apply-dev: ## Dev環境にTerraformを適用
	cd terraform && \
	terraform workspace select dev && \
	terraform apply -var-file=dev.tfvars

apply-stg: ## Stg環境にTerraformを適用
	cd terraform && \
	terraform workspace select stg && \
	terraform apply -var-file=stg.tfvars

# Terraformの出力取得
output-dev: ## Dev環境のTerraform出力を表示
	cd terraform && \
	terraform workspace select dev && \
	terraform output

output-stg: ## Stg環境のTerraform出力を表示
	cd terraform && \
	terraform workspace select stg && \
	terraform output

# Dockerイメージのビルドとプッシュ
build-push-dev: ## Dev環境用にDockerイメージをビルドしてプッシュ
	@echo "🔨 Building and pushing images for Dev environment..."
	@cd terraform && terraform workspace select dev
	$(eval PROJECT_ID := gcloud-and-terraform)
	$(eval REGION := asia-northeast1)
	$(eval REPO_ID := todo-app-dev)
	gcloud auth configure-docker $(REGION)-docker.pkg.dev
	docker buildx build --platform linux/amd64 -t $(REGION)-docker.pkg.dev/$(PROJECT_ID)/$(REPO_ID)/frontend:latest ./src/frontend --push
	docker buildx build --platform linux/amd64 -t $(REGION)-docker.pkg.dev/$(PROJECT_ID)/$(REPO_ID)/backend:latest ./src/backend --push
	@echo "✅ Images pushed to Artifact Registry (dev)"

build-push-stg: ## Stg環境用にDockerイメージをビルドしてプッシュ
	@echo "🔨 Building and pushing images for Stg environment..."
	@cd terraform && terraform workspace select stg
	$(eval PROJECT_ID := gcloud-and-terraform-stg)
	$(eval REGION := asia-northeast1)
	$(eval REPO_ID := todo-app-stg)
	gcloud auth configure-docker $(REGION)-docker.pkg.dev
	docker buildx build --platform linux/amd64 -t $(REGION)-docker.pkg.dev/$(PROJECT_ID)/$(REPO_ID)/frontend:latest ./src/frontend --push
	docker buildx build --platform linux/amd64 -t $(REGION)-docker.pkg.dev/$(PROJECT_ID)/$(REPO_ID)/backend:latest ./src/backend --push
	@echo "✅ Images pushed to Artifact Registry (stg)"

# GKEクラスタへの接続
connect-dev: ## Dev環境のGKEクラスタに接続
	@cd terraform && terraform workspace select dev
	gcloud container clusters get-credentials gke-cluster-dev \
		--zone=asia-northeast1-a \
		--project=gcloud-and-terraform

connect-stg: ## Stg環境のGKEクラスタに接続
	@cd terraform && terraform workspace select stg
	gcloud container clusters get-credentials gke-cluster-stg \
		--zone=asia-northeast1-a \
		--project=gcloud-and-terraform-stg

# Kubernetesマニフェストの適用準備（プレースホルダーを置換）
prepare-k8s-dev: ## Dev環境用にK8sマニフェストを準備
	@echo "📝 Preparing Kubernetes manifests for Dev..."
	@cd terraform && terraform workspace select dev
	$(eval PROJECT_ID := gcloud-and-terraform)
	$(eval REGION := asia-northeast1)
	$(eval REPO_ID := todo-app-dev)
	$(eval DB_IP := $(shell cd terraform && terraform output -raw db_private_ip))
	$(eval DB_USER := $(shell cd terraform && terraform output -raw db_user))
	$(eval DB_PASSWORD := $(shell cd terraform && terraform output -raw db_password | sed 's/[&#/%\]/\\&/g'))
	$(eval SA_EMAIL := $(shell cd terraform && terraform output -raw service_account_email))
	@mkdir -p k8s/generated/dev
	@for file in k8s/*.yaml; do \
		sed -e 's|REGION-docker.pkg.dev/PROJECT_ID/REPO_ID|$(REGION)-docker.pkg.dev/$(PROJECT_ID)/$(REPO_ID)|g' \
		    -e 's|DB_PRIVATE_IP|$(DB_IP)|g' \
		    -e 's|PLACEHOLDER_DB_USER|$(DB_USER)|g' \
		    -e 's|PLACEHOLDER_DB_PASSWORD|$(DB_PASSWORD)|g' \
		    -e 's|GKE_WORKLOAD_SA_EMAIL|$(SA_EMAIL)|g' \
		    -e 's|INGRESS_IP_NAME|ingress-ip-dev|g' \
		    -e 's|SSL_CERT_NAME|managed-cert|g' \
		    -e 's|DOMAIN|sample-gke.dev.gcp.tomohiko.io|g' \
		    $$file > k8s/generated/dev/$$(basename $$file); \
	done
	@echo "✅ Manifests prepared in k8s/generated/dev/"

prepare-k8s-stg: ## Stg環境用にK8sマニフェストを準備
	@echo "📝 Preparing Kubernetes manifests for Stg..."
	@cd terraform && terraform workspace select stg
	$(eval PROJECT_ID := gcloud-and-terraform-stg)
	$(eval REGION := asia-northeast1)
	$(eval REPO_ID := todo-app-stg)
	$(eval DB_IP := $(shell cd terraform && terraform output -raw db_private_ip))
	$(eval DB_USER := $(shell cd terraform && terraform output -raw db_user))
	$(eval DB_PASSWORD := $(shell cd terraform && terraform output -raw db_password | sed 's/[&#/%\]/\\&/g'))
	$(eval SA_EMAIL := $(shell cd terraform && terraform output -raw service_account_email))
	@mkdir -p k8s/generated/stg
	@for file in k8s/*.yaml; do \
		sed -e 's|REGION-docker.pkg.dev/PROJECT_ID/REPO_ID|$(REGION)-docker.pkg.dev/$(PROJECT_ID)/$(REPO_ID)|g' \
		    -e 's|DB_PRIVATE_IP|$(DB_IP)|g' \
		    -e 's|PLACEHOLDER_DB_USER|$(DB_USER)|g' \
		    -e 's|PLACEHOLDER_DB_PASSWORD|$(DB_PASSWORD)|g' \
		    -e 's|GKE_WORKLOAD_SA_EMAIL|$(SA_EMAIL)|g' \
		    -e 's|INGRESS_IP_NAME|ingress-ip-stg|g' \
		    -e 's|SSL_CERT_NAME|managed-cert|g' \
		    -e 's|DOMAIN|sample-gke.stg.gcp.tomohiko.io|g' \
		    $$file > k8s/generated/stg/$$(basename $$file); \
	done
	@echo "✅ Manifests prepared in k8s/generated/stg/"

# Kubernetesへのデプロイ
deploy-dev: prepare-k8s-dev connect-dev ## Dev環境にアプリケーションをデプロイ
	@echo "🚀 Deploying to Dev environment..."
	kubectl apply -f k8s/generated/dev/
	@echo "✅ Deployed to Dev"
	@echo "📊 Check status with: kubectl get pods,svc,ingress"

deploy-stg: prepare-k8s-stg connect-stg ## Stg環境にアプリケーションをデプロイ
	@echo "🚀 Deploying to Stg environment..."
	kubectl apply -f k8s/generated/stg/
	@echo "✅ Deployed to Stg"
	@echo "📊 Check status with: kubectl get pods,svc,ingress"

# ステータス確認
status-dev: connect-dev ## Dev環境のKubernetesリソース状態を確認
	kubectl get pods,svc,ingress,managedcertificate

status-stg: connect-stg ## Stg環境のKubernetesリソース状態を確認
	kubectl get pods,svc,ingress,managedcertificate

# ログ確認
logs-frontend-dev: connect-dev ## Dev環境のフロントエンドログを表示
	kubectl logs -l app=frontend --tail=100 -f

logs-backend-dev: connect-dev ## Dev環境のバックエンドログを表示
	kubectl logs -l app=backend --tail=100 -f

logs-frontend-stg: connect-stg ## Stg環境のフロントエンドログを表示
	kubectl logs -l app=frontend --tail=100 -f

logs-backend-stg: connect-stg ## Stg環境のバックエンドログを表示
	kubectl logs -l app=backend --tail=100 -f

# クリーンアップ
clean: ## 生成されたファイルをクリーンアップ
	rm -rf k8s/generated
	@echo "✅ Cleaned generated files"

destroy-dev: ## Dev環境のリソースを削除（シンプル版、問題がある場合はdestroy-all-devを使用）
	@echo "⚠️  WARNING: This will destroy all resources in Dev environment!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		cd terraform && \
		terraform workspace select dev && \
		terraform destroy -var-file=dev.tfvars -auto-approve; \
	else \
		echo "Cancelled."; \
	fi

destroy-stg: ## Stg環境のリソースを削除（シンプル版、問題がある場合はdestroy-all-stgを使用）
	@echo "⚠️  WARNING: This will destroy all resources in Stg environment!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		cd terraform && \
		terraform workspace select stg && \
		terraform destroy -var-file=stg.tfvars -auto-approve; \
	else \
		echo "Cancelled."; \
	fi

destroy-all-dev: ## Dev環境を完全削除（依存関係エラーも自動解決）
	@echo "⚠️  WARNING: This will COMPLETELY destroy all resources in Dev environment!"
	@echo "This includes: GKE, Cloud SQL, Artifact Registry, Load Balancer, DNS records, VPC"
	@read -p "Are you ABSOLUTELY sure? Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		$(MAKE) _destroy-all-impl ENV=dev; \
	else \
		echo "❌ Cancelled."; \
	fi

destroy-all-stg: ## Stg環境を完全削除（依存関係エラーも自動解決）
	@echo "⚠️  WARNING: This will COMPLETELY destroy all resources in Stg environment!"
	@echo "This includes: GKE, Cloud SQL, Artifact Registry, Load Balancer, DNS records, VPC"
	@read -p "Are you ABSOLUTELY sure? Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		$(MAKE) _destroy-all-impl ENV=stg; \
	else \
		echo "❌ Cancelled."; \
	fi

_destroy-all-impl: ## 内部ターゲット：完全削除の実装
	@echo "🗑️  Starting complete destruction of $(ENV) environment..."
	@echo ""
	@echo "📌 Step 1: Deleting Kubernetes resources..."
	@if gcloud container clusters get-credentials gke-cluster-$(ENV) \
		--zone=asia-northeast1-a \
		--project=$(if $(filter $(ENV),dev),gcloud-and-terraform,gcloud-and-terraform-stg) 2>/dev/null; then \
		echo "  - Deleting all deployments..."; \
		kubectl delete deployment --all --grace-period=0 --force 2>/dev/null || true; \
		echo "  - Deleting all services..."; \
		kubectl delete service --all --grace-period=0 --force 2>/dev/null || true; \
		echo "  - Deleting ingress..."; \
		kubectl delete ingress --all 2>/dev/null || true; \
		echo "✅ Kubernetes resources deleted"; \
	else \
		echo "⚠️  GKE cluster not found or not accessible (may already be deleted)"; \
	fi
	@echo ""
	@echo "📌 Step 2: Getting Cloud SQL instance name..."
	@cd terraform && terraform workspace select $(ENV) > /dev/null 2>&1 || true
	$(eval DB_INSTANCE := $(shell cd terraform && terraform output -raw db_instance_name 2>/dev/null || echo ""))
	@if [ -n "$(DB_INSTANCE)" ]; then \
		echo "  - Found Cloud SQL instance: $(DB_INSTANCE)"; \
		echo "  - Deleting Cloud SQL instance..."; \
		gcloud sql instances delete $(DB_INSTANCE) \
			--project=$(if $(filter $(ENV),dev),gcloud-and-terraform,gcloud-and-terraform-stg) \
			--quiet 2>/dev/null || echo "⚠️  Cloud SQL instance not found or already deleted"; \
		echo "  - Removing Cloud SQL from Terraform state..."; \
		cd terraform && \
		terraform state rm google_sql_database_instance.postgres 2>/dev/null || true; \
		terraform state rm google_sql_database.database 2>/dev/null || true; \
		terraform state rm google_sql_user.user 2>/dev/null || true; \
		echo "✅ Cloud SQL cleaned up"; \
	else \
		echo "⚠️  No Cloud SQL instance found in Terraform state"; \
	fi
	@echo ""
	@echo "📌 Step 3: Running Terraform destroy (attempt 1)..."
	@cd terraform && \
	terraform workspace select $(ENV) && \
	terraform destroy -var-file=$(ENV).tfvars -auto-approve || echo "⚠️  First destroy attempt completed with errors (expected)"
	@echo ""
	@echo "📌 Step 4: Cleaning up VPC Peering and Private IP..."
	@echo "  - Attempting to delete VPC Peering..."
	@gcloud services vpc-peerings delete \
		--service=servicenetworking.googleapis.com \
		--network=gke-vpc-$(ENV) \
		--project=$(if $(filter $(ENV),dev),gcloud-and-terraform,gcloud-and-terraform-stg) \
		--quiet 2>/dev/null || echo "⚠️  VPC Peering not found or already deleted"
	@echo "  - Attempting to delete Private IP address..."
	@gcloud compute addresses delete private-ip-address-$(ENV) \
		--global \
		--project=$(if $(filter $(ENV),dev),gcloud-and-terraform,gcloud-and-terraform-stg) \
		--quiet 2>/dev/null || echo "⚠️  Private IP address not found or already deleted"
	@echo "  - Removing VPC Peering from Terraform state..."
	@cd terraform && \
	terraform state rm google_service_networking_connection.private_vpc_connection 2>/dev/null || true; \
	terraform state rm google_compute_global_address.private_ip_address 2>/dev/null || true
	@echo ""
	@echo "📌 Step 5: Running Terraform destroy (attempt 2)..."
	@cd terraform && \
	terraform workspace select $(ENV) && \
	terraform destroy -var-file=$(ENV).tfvars -auto-approve || echo "⚠️  Second destroy attempt completed with errors (expected)"
	@echo ""
	@echo "📌 Step 6: Final verification..."
	$(eval REMAINING := $(shell cd terraform && terraform state list 2>/dev/null | wc -l))
	@if [ "$(REMAINING)" -eq "0" ]; then \
		echo "✅ All resources successfully destroyed!"; \
		echo ""; \
		echo "📊 Verification:"; \
		echo "  - Terraform state: Empty"; \
		echo "  - Monthly cost: \$$0"; \
		echo ""; \
		echo "🎉 $(ENV) environment completely destroyed!"; \
	else \
		echo "⚠️  Some resources may still remain in Terraform state:"; \
		cd terraform && terraform state list; \
		echo ""; \
		echo "Run 'cd terraform && terraform state list' to check remaining resources"; \
	fi

# 環境の停止・再開
stop-dev: ## Dev環境を停止（ノード+Cloud SQLを停止して課金を削減）
	@./scripts/stop-all.sh dev

stop-stg: ## Stg環境を停止（ノード+Cloud SQLを停止して課金を削減）
	@./scripts/stop-all.sh stg

start-dev: ## Dev環境を再開（ノード+Cloud SQLを起動）
	@./scripts/start-all.sh dev

start-stg: ## Stg環境を再開（ノード+Cloud SQLを起動）
	@./scripts/start-all.sh stg

