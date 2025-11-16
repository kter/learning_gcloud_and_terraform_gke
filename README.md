# GKE学習用 TODO アプリケーション

Google Cloud Platform (GCP) と Terraform を使用した、学習用のGKEクラスタ環境構築プロジェクトです。

## 📋 目次

- [概要](#概要)
- [アーキテクチャ](#アーキテクチャ)
- [前提条件](#前提条件)
- [セットアップ手順](#セットアップ手順)
- [デプロイ手順](#デプロイ手順)
- [運用コマンド](#運用コマンド)
- [想定費用](#想定費用)
- [トラブルシューティング](#トラブルシューティング)
- [クリーンアップ](#クリーンアップ)

## 🎯 概要

このプロジェクトは、以下の技術スタックを使用したTODOアプリケーションをGKE上で動作させる学習環境を提供します。

### 技術スタック

- **フロントエンド**: Nuxt.js 3 (Vue.js)
- **バックエンド**: Python FastAPI
- **データベース**: Cloud SQL (PostgreSQL)
- **コンテナオーケストレーション**: Google Kubernetes Engine (GKE)
- **IaC**: Terraform
- **コンテナレジストリ**: Artifact Registry

### 環境

- **dev**: 開発環境 (`gcloud-and-terraform`)
- **stg**: ステージング環境 (`gcloud-and-terraform-stg`)

## 🏗️ アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                      Internet                                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ HTTPS (443)
                         │
┌────────────────────────▼────────────────────────────────────┐
│              Google Cloud Load Balancer                      │
│          (Managed SSL Certificate / Ingress)                 │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │
            ┌────────────┴────────────┐
            │                         │
┌───────────▼─────────┐    ┌─────────▼──────────┐
│  Frontend Service   │    │  Backend Service    │
│    (Nuxt.js)        │    │    (FastAPI)        │
│    Port: 3000       │    │    Port: 8000       │
└─────────────────────┘    └──────────┬──────────┘
                                      │
                                      │ Private IP
                                      │
                           ┌──────────▼───────────┐
                           │   Cloud SQL          │
                           │   (PostgreSQL)       │
                           │   db-f1-micro        │
                           └──────────────────────┘
```

### 主要コンポーネント

1. **VPC Network**: プライベートネットワーク環境
2. **GKE Cluster**: Kubernetes クラスタ (e2-micro × 1ノード)
3. **Artifact Registry**: Dockerイメージの保存
4. **Cloud SQL**: PostgreSQLデータベース (最小構成)
5. **Load Balancer**: GKE Ingress経由でのHTTPS通信
6. **Managed Certificate**: Google マネージド SSL証明書
7. **Cloud DNS**: ドメイン管理とAレコード自動登録

## 📦 前提条件

### 必要なツール

1. **gcloud CLI** (最新版)
   ```bash
   # インストール確認
   gcloud version
   
   # 初期設定
   gcloud init
   gcloud auth login
   gcloud auth application-default login
   ```

2. **tfenv** (Terraformバージョン管理)
   ```bash
   # Homebrewでインストール (macOS)
   brew install tfenv
   
   # または手動インストール
   git clone https://github.com/tfutils/tfenv.git ~/.tfenv
   echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bash_profile
   ```

3. **kubectl** (Kubernetesクライアント)
   ```bash
   # gcloud経由でインストール
   gcloud components install kubectl
   
   # または Homebrewでインストール
   brew install kubectl
   ```

4. **Docker** (コンテナイメージビルド用)
   ```bash
   # Docker Desktop をインストール
   # https://www.docker.com/products/docker-desktop
   ```

5. **make** (タスクランナー)
   ```bash
   # macOSには標準でインストール済み
   make --version
   ```

### GCPプロジェクトの作成

1. **Dev環境用プロジェクト**
   ```bash
   gcloud projects create gcloud-and-terraform --name="GKE Learning Dev"
   gcloud config set project gcloud-and-terraform
   
   # 必要なAPIを有効化
   gcloud services enable \
     compute.googleapis.com \
     container.googleapis.com \
     artifactregistry.googleapis.com \
     sqladmin.googleapis.com \
     servicenetworking.googleapis.com \
     dns.googleapis.com
   
   # 課金アカウントのリンク（要課金アカウント設定）
   gcloud beta billing accounts list
   gcloud beta billing projects link gcloud-and-terraform \
     --billing-account=BILLING_ACCOUNT_ID
   ```

2. **Stg環境用プロジェクト**
   ```bash
   gcloud projects create gcloud-and-terraform-stg --name="GKE Learning Stg"
   gcloud config set project gcloud-and-terraform-stg
   
   # 必要なAPIを有効化
   gcloud services enable \
     compute.googleapis.com \
     container.googleapis.com \
     artifactregistry.googleapis.com \
     sqladmin.googleapis.com \
     servicenetworking.googleapis.com \
     dns.googleapis.com
   
   # 課金アカウントのリンク
   gcloud beta billing projects link gcloud-and-terraform-stg \
     --billing-account=BILLING_ACCOUNT_ID
   ```

### Terraform State用GCSバケットの作成

```bash
# Dev環境プロジェクトに戻す
gcloud config set project gcloud-and-terraform

# GCSバケット作成（グローバルで一意な名前が必要）
gsutil mb -p gcloud-and-terraform -l asia-northeast1 gs://gcloud-and-terraform-tfstate

# バージョニング有効化（推奨）
gsutil versioning set on gs://gcloud-and-terraform-tfstate
```

### Cloud DNSゾーンの確認

**重要**: このプロジェクトでは、既存のCloud DNSゾーンを使用します。各プロジェクトに以下のゾーンが作成されている必要があります。

```bash
# Dev環境のDNSゾーンを確認
gcloud config set project gcloud-and-terraform
gcloud dns managed-zones list

# 出力例:
# NAME                   DNS_NAME                DESCRIPTION  VISIBILITY
# dev-gcp-tomohiko-io    dev.gcp.tomohiko.io.    ...          public

# Stg環境のDNSゾーンを確認
gcloud config set project gcloud-and-terraform-stg
gcloud dns managed-zones list

# 出力例:
# NAME                   DNS_NAME                DESCRIPTION  VISIBILITY
# stg-gcp-tomohiko-io    stg.gcp.tomohiko.io.    ...          public
```

**ゾーン名の設定**:
- Dev環境: ゾーン名 `dev-gcp-tomohiko-io` でドメイン `dev.gcp.tomohiko.io`
- Stg環境: ゾーン名 `stg-gcp-tomohiko-io` でドメイン `stg.gcp.tomohiko.io`

もしゾーン名が異なる場合は、`terraform/variables.tf` の `dns_zone_name` を実際のゾーン名に変更してください。

**Terraformによる自動DNS設定**:
- `terraform apply` 実行時に、Ingress用の静的IPが自動的にAレコードとして登録されます
- 手動でのDNS設定は不要です

## 🚀 セットアップ手順

### 1. Terraformのバージョン固定

```bash
# tfenv を使用してTerraformをインストール
cd terraform
tfenv install
tfenv use

# バージョン確認
terraform version
# Terraform v1.9.5
```

`.terraform-version` ファイルにバージョンが記載されているため、`tfenv install` で自動的に正しいバージョンがインストールされます。

### 2. Dev環境の構築

```bash
# Terraform初期化とworkspace作成
make init-dev

# プラン確認
make plan-dev

# インフラ構築（約10-15分かかります）
make apply-dev

# 構築結果の確認
make output-dev
```

### 3. DNS設定の確認

**Terraformが自動的にDNSレコードを登録します！**

`terraform apply` 実行後、以下のDNSレコードが自動的に作成されます：

```bash
# DNSレコードの確認
make output-dev

# 出力例:
# dns_record_fqdn = "sample-gke.dev.gcp.tomohiko.io."
# ingress_ip = "34.xxx.xxx.xxx"
```

DNSレコードの伝搬を確認：

```bash
# DNSが正しく設定されたか確認
dig sample-gke.dev.gcp.tomohiko.io
nslookup sample-gke.dev.gcp.tomohiko.io

# Cloud DNSで確認
gcloud dns record-sets list --zone=dev-gcp-tomohiko-io --project=gcloud-and-terraform
```

**注意**: DNS伝搬には数分かかる場合があります（通常は1-5分）。

### 4. Dockerイメージのビルドとプッシュ

```bash
# Dev環境用イメージをビルド＆プッシュ
make build-push-dev
```

### 5. GKEへのデプロイ

```bash
# Kubernetesマニフェストを準備してデプロイ
make deploy-dev

# デプロイ状態の確認
make status-dev
```

### 6. SSL証明書のプロビジョニング確認

Google マネージドSSL証明書のプロビジョニングには最大で15-30分かかります。

**前提条件**: 
- DNSレコードが正しく設定されている（Terraformが自動設定済み）
- DNSが伝搬している（通常1-5分）

```bash
# GKEに接続
make connect-dev

# SSL証明書の状態確認
kubectl describe managedcertificate managed-cert

# Status が "Active" になるまで待機
# ドメインが正しくIPアドレスに解決されていることが必要です

# DNSの伝搬確認
dig sample-gke.dev.gcp.tomohiko.io +short
# Ingress IPが返ってくればOK
```

### 7. アプリケーションへのアクセス

```bash
# ブラウザで以下のURLにアクセス
https://sample-gke.dev.gcp.tomohiko.io
```

## 🔄 デプロイ手順（コード更新時）

アプリケーションコードを更新した場合の再デプロイ手順：

```bash
# 1. Dockerイメージを再ビルド＆プッシュ
make build-push-dev

# 2. Kubernetesにデプロイ（Podの再作成）
make deploy-dev

# または、個別にPodを再起動
kubectl rollout restart deployment/frontend
kubectl rollout restart deployment/backend
```

## 🛠️ 運用コマンド

### Makefile コマンド一覧

```bash
# ヘルプの表示
make help

# 環境構築
make init-dev           # Dev環境の初期化
make init-stg           # Stg環境の初期化

# Terraform操作
make plan-dev           # Dev環境のプラン確認
make apply-dev          # Dev環境への適用
make output-dev         # Dev環境の出力表示

# イメージビルド＆プッシュ
make build-push-dev     # Dev環境用
make build-push-stg     # Stg環境用

# デプロイ
make deploy-dev         # Dev環境へデプロイ
make deploy-stg         # Stg環境へデプロイ

# ステータス確認
make status-dev         # Dev環境のステータス確認
make status-stg         # Stg環境のステータス確認

# ログ確認
make logs-frontend-dev  # Dev環境フロントエンドログ
make logs-backend-dev   # Dev環境バックエンドログ

# クリーンアップ
make clean              # 生成ファイルの削除
make destroy-dev        # Dev環境の完全削除
make destroy-stg        # Stg環境の完全削除
```

### 直接kubectlを使用する場合

```bash
# GKEクラスタに接続
make connect-dev

# Pod一覧
kubectl get pods

# Service一覧
kubectl get svc

# Ingress確認
kubectl get ingress

# ログの確認
kubectl logs -f deployment/frontend
kubectl logs -f deployment/backend

# Podへの接続
kubectl exec -it <pod-name> -- /bin/sh

# リソースの削除
kubectl delete -f k8s/generated/dev/
```

## 💰 想定費用

以下は、アイドル時間を長く、最小限のトラフィックで運用した場合の**月額概算費用**です。

### Dev環境（1ヶ月あたり）

| サービス | 構成 | 想定費用（月額） | 備考 |
|---------|------|-----------------|------|
| **GKE Cluster** | Standard, 1ノード (e2-micro preemptible) | $7 - $15 | Preemptibleノード使用で大幅削減 |
| **Cloud SQL** | PostgreSQL, db-f1-micro, 10GB HDD | $10 - $15 | 最小スペック、ゾーン冗長なし |
| **Cloud Load Balancing** | 1 Forwarding Rule, 最小トラフィック | $18 - $25 | 基本料金（アイドル時） |
| **Artifact Registry** | ストレージ 1GB以下 | $0.10 - $1 | 無料枠内でほぼ無料 |
| **Compute Engine Persistent Disk** | 10GB Standard PD for GKE | $0.40 - $2 | GKEノード用ディスク |
| **VPC / Networking** | Private IP, NAT Gateway（不使用） | $1 - $3 | VPC Peeringやegress料金 |
| **Cloud DNS** | DNSレコード追加のみ（既存ゾーン使用） | $0 - $0.10 | Terraformが自動管理、ゾーン料金は含まず |

**合計: 約 $37 - $62 / 月 (約 ¥5,500 - ¥9,300)**

### Stg環境（1ヶ月あたり）

Dev環境と同じ構成のため、同額を想定。

**合計（Dev + Stg）: 約 $74 - $124 / 月 (約 ¥11,000 - ¥18,600)**

### コスト削減のヒント

1. **Preemptibleノードの活用**
   - 通常のノードと比較して最大80%のコスト削減
   - 学習環境では問題なく使用可能

2. **不要時のシャットダウン**
   ```bash
   # GKEクラスタのノード数を0にする
   gcloud container clusters resize gke-cluster-dev --num-nodes=0 --zone=asia-northeast1-a
   
   # 復旧時
   gcloud container clusters resize gke-cluster-dev --num-nodes=1 --zone=asia-northeast1-a
   ```

3. **Cloud SQLの停止**
   ```bash
   # データベースを一時停止（課金停止）
   gcloud sql instances patch todo-db-dev-xxxx --activation-policy=NEVER
   
   # 再開
   gcloud sql instances patch todo-db-dev-xxxx --activation-policy=ALWAYS
   ```

4. **完全に削除する場合**
   ```bash
   # 全リソースの削除
   make destroy-dev
   make destroy-stg
   ```

5. **Autopilotモードの検討**
   - アイドル時のコストが低い
   - ノード管理不要
   - ただし最小料金がStandardより高い場合あり

### 無料枠について

GCPには新規ユーザー向けに$300の無料クレジットがあります（90日間有効）。
これを使えば、最初の数ヶ月は実質無料で学習できます。

## 🔍 トラブルシューティング

### 1. SSL証明書がActiveにならない

**原因**: DNSレコードの伝搬待ち、またはTerraformによるDNS設定の問題

**解決策**:
```bash
# TerraformでDNSレコードが正しく作成されたか確認
cd terraform
terraform output dns_record_fqdn
terraform output ingress_ip

# Cloud DNSに登録されているか確認
gcloud dns record-sets list --zone=dev-gcp-tomohiko-io \
  --project=gcloud-and-terraform | grep sample-gke

# DNSの伝搬確認
dig sample-gke.dev.gcp.tomohiko.io +short
nslookup sample-gke.dev.gcp.tomohiko.io

# SSL証明書の状態確認
kubectl describe managedcertificate managed-cert

# 15-30分待機してから再確認
```

**DNSレコードが作成されていない場合**:
```bash
# Terraformを再適用
make apply-dev
```

### 2. Podが起動しない

**原因**: イメージのPullエラー、リソース不足など

**解決策**:
```bash
# Pod状態の詳細確認
kubectl describe pod <pod-name>

# ログ確認
kubectl logs <pod-name>

# イメージが正しくプッシュされているか確認
gcloud artifacts docker images list \
  asia-northeast1-docker.pkg.dev/gcloud-and-terraform/todo-app-dev
```

### 3. バックエンドがデータベースに接続できない

**原因**: Workload Identity設定ミス、プライベートIP設定不備

**解決策**:
```bash
# Cloud SQLのプライベートIPを確認
cd terraform
terraform output db_private_ip

# Secretの確認
kubectl describe secret db-credentials

# バックエンドPodから接続テスト
kubectl exec -it <backend-pod-name> -- sh
# pod内で
ping <db_private_ip>
```

### 4. Terraform適用時のエラー

**原因**: APIが有効化されていない、権限不足

**解決策**:
```bash
# 必要なAPIが有効か確認
gcloud services list --enabled --project=gcloud-and-terraform

# APIの有効化
gcloud services enable compute.googleapis.com container.googleapis.com \
  artifactregistry.googleapis.com sqladmin.googleapis.com \
  servicenetworking.googleapis.com dns.googleapis.com
```

### 5. "Error 404: The requested URL was not found"

**原因**: Ingressが正しく設定されていない、Serviceが起動していない

**解決策**:
```bash
# Ingressの状態確認
kubectl describe ingress todo-app-ingress

# Backendの状態確認
kubectl get ingress todo-app-ingress -o yaml

# Serviceの確認
kubectl get svc
kubectl describe svc frontend
kubectl describe svc backend
```

## 🧹 クリーンアップ

### リソースの完全削除

```bash
# Dev環境の削除（DNSレコードも自動削除されます）
make destroy-dev

# Stg環境の削除（DNSレコードも自動削除されます）
make destroy-stg

# GCSバケットの削除（Terraform State）
gsutil rm -r gs://gcloud-and-terraform-tfstate

# プロジェクト自体を削除する場合
gcloud projects delete gcloud-and-terraform
gcloud projects delete gcloud-and-terraform-stg
```

**注意**: 
- `destroy` コマンドは全てのリソース（GKE、Cloud SQL、DNSレコードなど）を削除します
- DNSレコードも自動的に削除されますが、Cloud DNSゾーン自体は削除されません
- 実行前に確認が求められます

**DNSレコードの手動確認**（念のため）:
```bash
# 削除後の確認
gcloud dns record-sets list --zone=dev-gcp-tomohiko-io \
  --project=gcloud-and-terraform | grep sample-gke
# 何も表示されなければ正常に削除されています
```

## 📚 学習リソース

### 公式ドキュメント

- [Google Kubernetes Engine (GKE)](https://cloud.google.com/kubernetes-engine/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Cloud SQL for PostgreSQL](https://cloud.google.com/sql/docs/postgres)
- [Artifact Registry](https://cloud.google.com/artifact-registry/docs)
- [Cloud DNS](https://cloud.google.com/dns/docs)

### 次のステップ

1. **監視とロギング**
   - Cloud Monitoring でメトリクス収集
   - Cloud Logging でログ集約

2. **CI/CDパイプライン**
   - Cloud Build でビルド自動化
   - GitHub Actions との連携

3. **セキュリティ強化**
   - Binary Authorization
   - Workload Identity の詳細設定
   - Secret Manager の利用

4. **スケーリング**
   - Horizontal Pod Autoscaler
   - Cluster Autoscaler
   - 複数ノードプール

## 📝 ライセンス

このプロジェクトは学習目的のサンプルコードです。自由に改変・利用してください。

## 🤝 コントリビューション

改善提案やバグ報告は Issue または Pull Request でお願いします。

---

**Happy Learning! 🚀**

