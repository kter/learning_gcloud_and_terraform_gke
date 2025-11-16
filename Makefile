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
	$(eval DB_PASSWORD_RAW := $(shell cd terraform && terraform output -raw db_password))
	$(eval DB_PASSWORD := $(shell printf '%s\n' '$(DB_PASSWORD_RAW)' | sed 's/[&/\]/\\&/g'))
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
	$(eval DB_PASSWORD_RAW := $(shell cd terraform && terraform output -raw db_password))
	$(eval DB_PASSWORD := $(shell printf '%s\n' '$(DB_PASSWORD_RAW)' | sed 's/[&/\]/\\&/g'))
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

destroy-dev: ## Dev環境のリソースを削除（注意：全てのリソースが削除されます）
	@echo "⚠️  WARNING: This will destroy all resources in Dev environment!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		cd terraform && \
		terraform workspace select dev && \
		terraform destroy -var-file=dev.tfvars; \
	else \
		echo "Cancelled."; \
	fi

destroy-stg: ## Stg環境のリソースを削除（注意：全てのリソースが削除されます）
	@echo "⚠️  WARNING: This will destroy all resources in Stg environment!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		cd terraform && \
		terraform workspace select stg && \
		terraform destroy -var-file=stg.tfvars; \
	else \
		echo "Cancelled."; \
	fi

