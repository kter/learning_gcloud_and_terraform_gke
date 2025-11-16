terraform {
  required_version = ">= 1.9.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "google" {
  project = local.project_id
  region  = local.region
}

# VPCネットワーク
resource "google_compute_network" "vpc" {
  name                    = "gke-vpc-${terraform.workspace}"
  auto_create_subnetworks = false
}

# サブネット
resource "google_compute_subnetwork" "subnet" {
  name          = "gke-subnet-${terraform.workspace}"
  ip_cidr_range = "10.0.0.0/24"
  region        = local.region
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/16"
  }
}

# Cloud SQL用プライベートIPアクセス
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address-${terraform.workspace}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# Artifact Registry
resource "google_artifact_registry_repository" "docker_repo" {
  location      = local.region
  repository_id = "todo-app-${terraform.workspace}"
  description   = "Docker repository for TODO application (${terraform.workspace})"
  format        = "DOCKER"
}

# GKEクラスタ (Standard mode with minimal configuration)
resource "google_container_cluster" "primary" {
  name     = "gke-cluster-${terraform.workspace}"
  location = local.zone

  # 初期ノードプールを削除してカスタムノードプールを使用
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Workload Identity有効化
  workload_identity_config {
    workload_pool = "${local.project_id}.svc.id.goog"
  }

  # Cloud SQLプロキシアドオン
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }
}

# GKEノードプール
resource "google_container_node_pool" "primary_nodes" {
  name       = "primary-node-pool-${terraform.workspace}"
  location   = local.zone
  cluster    = google_container_cluster.primary.name
  node_count = local.gke_node_count

  node_config {
    preemptible  = true
    machine_type = local.gke_machine_type

    disk_size_gb = 20
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# Cloud SQL Instance
resource "random_password" "db_password" {
  length  = 16
  special = true
}

resource "google_sql_database_instance" "postgres" {
  name             = "todo-db-${terraform.workspace}-${random_string.db_suffix.result}"
  database_version = "POSTGRES_15"
  region           = local.region

  settings {
    tier              = local.db_tier
    availability_type = "ZONAL"
    disk_size         = 10
    disk_type         = "PD_HDD"

    backup_configuration {
      enabled            = true
      start_time         = "02:00"
      point_in_time_recovery_enabled = false
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }
  }

  deletion_protection = false

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

resource "random_string" "db_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "google_sql_database" "database" {
  name     = var.db_name
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_user" "user" {
  name     = var.db_user
  instance = google_sql_database_instance.postgres.name
  password = random_password.db_password.result
}

# Service Account for GKE workloads
resource "google_service_account" "gke_workload" {
  account_id   = "gke-workload-${terraform.workspace}"
  display_name = "GKE Workload Service Account (${terraform.workspace})"
}

# Cloud SQL Clientロールの付与
resource "google_project_iam_member" "gke_workload_sql" {
  project = local.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.gke_workload.email}"
}

# Artifact Registryへのアクセス権限
resource "google_artifact_registry_repository_iam_member" "docker_reader" {
  project    = local.project_id
  location   = google_artifact_registry_repository.docker_repo.location
  repository = google_artifact_registry_repository.docker_repo.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.gke_workload.email}"
}

# Workload Identity Binding
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.gke_workload.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.project_id}.svc.id.goog[default/todo-app-ksa]"
}

# Static IP for Ingress
resource "google_compute_global_address" "ingress_ip" {
  name = "ingress-ip-${terraform.workspace}"
}

# Managed SSL Certificate
resource "google_compute_managed_ssl_certificate" "default" {
  name = "ssl-cert-${terraform.workspace}"

  managed {
    domains = [local.domain]
  }
}

# 既存のCloud DNSゾーンを参照
data "google_dns_managed_zone" "main" {
  name    = local.dns_zone_name
  project = local.project_id
}

# Ingress用のAレコードを自動登録
resource "google_dns_record_set" "ingress" {
  name         = "${local.domain}."
  type         = "A"
  ttl          = 300
  managed_zone = data.google_dns_managed_zone.main.name
  rrdatas      = [google_compute_global_address.ingress_ip.address]
  project      = local.project_id
}

