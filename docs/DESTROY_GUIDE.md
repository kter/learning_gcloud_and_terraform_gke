# 環境削除ガイド

このガイドでは、GKE学習環境を完全に削除する方法について説明します。

## 🎯 概要

GCP上の学習環境を削除する際、以下のような依存関係エラーが発生することがあります：

- Cloud SQL: ユーザーやデータベースの削除エラー
- VPC Peering: 他のサービスが使用中のエラー
- Private IP Address: ネットワークリソースの削除順序エラー

`destroy-all-*` コマンドは、これらの問題を自動的に解決します。

---

## ✅ 推奨: 完全削除コマンド

### 基本的な使い方

```bash
# Dev環境を完全削除
make destroy-all-dev

# Stg環境を完全削除
make destroy-all-stg
```

### 実行例

```bash
$ make destroy-all-dev

⚠️  WARNING: This will COMPLETELY destroy all resources in Dev environment!
This includes: GKE, Cloud SQL, Artifact Registry, Load Balancer, DNS records, VPC
Are you ABSOLUTELY sure? Type 'yes' to continue: yes

🗑️  Starting complete destruction of dev environment...

📌 Step 1: Deleting Kubernetes resources...
  - Deleting all deployments...
  - Deleting all services...
  - Deleting ingress...
✅ Kubernetes resources deleted

📌 Step 2: Getting Cloud SQL instance name...
  - Found Cloud SQL instance: todo-db-dev-ixro
  - Deleting Cloud SQL instance...
  - Removing Cloud SQL from Terraform state...
✅ Cloud SQL cleaned up

📌 Step 3: Running Terraform destroy (attempt 1)...
  [Terraform destroy output...]
⚠️  First destroy attempt completed with errors (expected)

📌 Step 4: Cleaning up VPC Peering and Private IP...
  - Attempting to delete VPC Peering...
  - Attempting to delete Private IP address...
  - Removing VPC Peering from Terraform state...

📌 Step 5: Running Terraform destroy (attempt 2)...
  [Terraform destroy output...]

📌 Step 6: Final verification...
✅ All resources successfully destroyed!

📊 Verification:
  - Terraform state: Empty
  - Monthly cost: $0

🎉 dev environment completely destroyed!
```

### 実行時間

- **Dev環境**: 約10-12分
- **Stg環境**: 約10-12分

---

## 🔧 処理の詳細

### Step 1: Kubernetes リソースの削除

```bash
kubectl delete deployment --all --grace-period=0 --force
kubectl delete service --all --grace-period=0 --force
kubectl delete ingress --all
```

**目的**: Cloud SQLへの接続を切断し、依存関係を解消

### Step 2: Cloud SQL の直接削除

```bash
gcloud sql instances delete <INSTANCE_NAME> --quiet
terraform state rm google_sql_database_instance.postgres
terraform state rm google_sql_database.database
terraform state rm google_sql_user.user
```

**目的**: ユーザー/データベースの依存関係エラーを回避

### Step 3: Terraform Destroy（1回目）

```bash
terraform destroy -var-file=dev.tfvars -auto-approve
```

**目的**: 大部分のリソースを削除（エラーが出ても継続）

### Step 4: VPC Peering と Private IP のクリーンアップ

```bash
gcloud services vpc-peerings delete --service=servicenetworking.googleapis.com --network=gke-vpc-dev --quiet
gcloud compute addresses delete private-ip-address-dev --global --quiet
terraform state rm google_service_networking_connection.private_vpc_connection
terraform state rm google_compute_global_address.private_ip_address
```

**目的**: VPCネットワークの依存関係を解消

### Step 5: Terraform Destroy（2回目）

```bash
terraform destroy -var-file=dev.tfvars -auto-approve
```

**目的**: 残りのリソース（VPC、サブネットなど）を削除

### Step 6: 最終確認

```bash
terraform state list
```

**目的**: すべてのリソースが削除されたことを確認

---

## 🆚 コマンド比較

### `make destroy-dev` vs `make destroy-all-dev`

| 項目 | `destroy-dev` | `destroy-all-dev` |
|------|---------------|-------------------|
| **確認プロンプト** | 1回 | 1回 |
| **自動化** | ❌ Terraform のみ | ✅ 完全自動 |
| **依存関係エラー** | ❌ 手動対応が必要 | ✅ 自動解決 |
| **実行時間** | 5-7分（エラー時は不明） | 10-12分 |
| **Kubernetes削除** | ❌ 手動 | ✅ 自動 |
| **Cloud SQL削除** | Terraformに依存 | 直接削除 |
| **VPC Peering** | Terraformに依存 | 自動クリーンアップ |
| **進捗表示** | Terraformのみ | 詳細な6ステップ |
| **最終レポート** | ❌ なし | ✅ あり |
| **推奨用途** | 正常時のみ | **常に推奨** |

---

## ⚠️ トラブルシューティング

### エラー: "GKE cluster not found"

```
⚠️  GKE cluster not found or not accessible (may already be deleted)
```

**原因**: GKEクラスタが既に削除されているか、認証エラー

**対処**: 問題ありません。処理は自動的に続行されます。

### エラー: "Cloud SQL instance not found"

```
⚠️  Cloud SQL instance not found or already deleted
```

**原因**: Cloud SQLインスタンスが既に削除されている

**対処**: 問題ありません。処理は自動的に続行されます。

### エラー: "VPC Peering not found"

```
⚠️  VPC Peering not found or already deleted
```

**原因**: VPC Peeringが既に削除されている

**対処**: 問題ありません。処理は自動的に続行されます。

### 最終確認で残りリソースがある場合

```
⚠️  Some resources may still remain in Terraform state:
google_compute_network.vpc
```

**対処**:

1. 手動でリソースを削除:
```bash
gcloud compute networks delete gke-vpc-dev --project=gcloud-and-terraform --quiet
```

2. Terraform stateから削除:
```bash
cd terraform
terraform state rm google_compute_network.vpc
```

3. 再度確認:
```bash
make destroy-all-dev
```

---

## 💰 コスト削減の比較

### 削除前（通常運用）

| リソース | 月額費用 |
|---------|---------|
| GKE クラスタ管理費 | $72 |
| GKE ノード (e2-medium × 2) | $24-36 |
| Cloud SQL (db-f1-micro) | $7-15 |
| Load Balancer | $18-25 |
| Artifact Registry | $0.10 |
| Cloud DNS (レコード) | $0.20 |
| **合計** | **$116-136** |

### 削除後

| リソース | 月額費用 |
|---------|---------|
| すべて削除 | **$0** |

**節約額**: $116-136/月

---

## 📋 チェックリスト

削除を実行する前に確認してください：

- [ ] データのバックアップは不要（学習環境のため）
- [ ] 他のチームメンバーが使用していない
- [ ] Cloud DNSゾーンは削除しない（再利用予定）
- [ ] GCS Terraform Stateバケットは削除しない（再利用予定）
- [ ] `gcloud` 認証が有効（`gcloud auth list` で確認）
- [ ] 正しいプロジェクトを選択（`gcloud config get-value project`）

---

## 🔄 再構築の手順

削除後、同じ環境を再構築する場合：

```bash
# 1. インフラ構築（10-15分）
make init-dev
make apply-dev

# 2. アプリデプロイ（5-7分）
make build-push-dev
make deploy-dev

# 3. 確認
kubectl get pods,svc,ingress
```

**合計**: 約15-20分で同じ環境を再構築可能

---

## 📝 関連コマンド

### 環境の停止（削除せずにコスト削減）

```bash
# ノードとCloud SQLを停止（課金を削減）
make stop-dev

# 再開
make start-dev
```

**月額費用**: $79-85（$37-50の節約）

### 状態確認

```bash
# Terraform state
cd terraform
terraform state list

# GCPリソース
gcloud container clusters list --project=gcloud-and-terraform
gcloud sql instances list --project=gcloud-and-terraform
gcloud compute addresses list --global --project=gcloud-and-terraform
```

---

## 🎓 学習のヒント

### 何度も構築・削除を繰り返す

```bash
# 削除
make destroy-all-dev

# 再構築
make init-dev && make apply-dev && make build-push-dev && make deploy-dev
```

**メリット**:
- Terraformコードの理解が深まる
- GCPリソースの依存関係を学べる
- 構築プロセスを体験できる
- 課金を最小限に抑えられる

### 削除プロセスの学習

`destroy-all-dev` の実行ログを見て、以下を学習できます：

1. Kubernetesリソースの削除順序
2. Cloud SQLの依存関係
3. VPC Peeringの仕組み
4. Terraformの状態管理
5. GCPリソースの削除順序

---

## 🆘 サポート

問題が発生した場合：

1. **Makefileを確認**: `_destroy-all-impl` ターゲットの実装を確認
2. **手動実行**: 各ステップを手動で実行して問題を特定
3. **Terraform state**: `terraform state list` で残りリソースを確認
4. **GCP Console**: GCP Consoleでリソースの状態を確認

---

## 📚 参考リンク

- [README.md](../README.md) - メインドキュメント
- [Makefile](../Makefile) - 全コマンドの実装
- [scripts/stop-all.sh](../scripts/stop-all.sh) - 環境停止スクリプト
- [scripts/start-all.sh](../scripts/start-all.sh) - 環境再開スクリプト

