variable "project_configs" {
  description = "Configuration for each environment"
  type = map(object({
    project_id     = string
    region         = string
    zone           = string
    domain         = string
    db_tier        = string
    gke_node_count = number
    gke_machine_type = string
  }))
  default = {
    dev = {
      project_id       = "gcloud-and-terraform"
      region           = "asia-northeast1"
      zone             = "asia-northeast1-a"
      domain           = "sample-gke.dev.gcp.tomohiko.io"
      db_tier          = "db-f1-micro"
      gke_node_count   = 1
      gke_machine_type = "e2-micro"
    }
    stg = {
      project_id       = "gcloud-and-terraform-stg"
      region           = "asia-northeast1"
      zone             = "asia-northeast1-a"
      domain           = "sample-gke.stg.gcp.tomohiko.io"
      db_tier          = "db-f1-micro"
      gke_node_count   = 1
      gke_machine_type = "e2-micro"
    }
  }
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "tododb"
}

variable "db_user" {
  description = "Database user"
  type        = string
  default     = "todouser"
}

locals {
  workspace_config = var.project_configs[terraform.workspace]
  project_id       = local.workspace_config.project_id
  region           = local.workspace_config.region
  zone             = local.workspace_config.zone
  domain           = local.workspace_config.domain
  db_tier          = local.workspace_config.db_tier
  gke_node_count   = local.workspace_config.gke_node_count
  gke_machine_type = local.workspace_config.gke_machine_type
}

