output "project_id" {
  description = "GCP Project ID"
  value       = local.project_id
}

output "region" {
  description = "GCP Region"
  value       = local.region
}

output "zone" {
  description = "GCP Zone"
  value       = local.zone
}

output "gke_cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.primary.name
}

output "gke_cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "artifact_registry_repository" {
  description = "Artifact Registry repository URL"
  value       = "${local.region}-docker.pkg.dev/${local.project_id}/${google_artifact_registry_repository.docker_repo.repository_id}"
}

output "db_instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.postgres.name
}

output "db_connection_name" {
  description = "Cloud SQL connection name"
  value       = google_sql_database_instance.postgres.connection_name
}

output "db_private_ip" {
  description = "Cloud SQL private IP address"
  value       = google_sql_database_instance.postgres.private_ip_address
}

output "db_name" {
  description = "Database name"
  value       = google_sql_database.database.name
}

output "db_user" {
  description = "Database user"
  value       = google_sql_user.user.name
}

output "db_password" {
  description = "Database password"
  value       = random_password.db_password.result
  sensitive   = true
}

output "ingress_ip" {
  description = "Static IP address for Ingress"
  value       = google_compute_global_address.ingress_ip.address
}

output "domain" {
  description = "Domain name for the application"
  value       = local.domain
}

output "service_account_email" {
  description = "GKE Workload Service Account email"
  value       = google_service_account.gke_workload.email
}

output "ssl_certificate_name" {
  description = "Managed SSL Certificate name"
  value       = google_compute_managed_ssl_certificate.default.name
}

