output "project_id" {
  description = "Provisioned GCP project ID."
  value       = google_project.focusquest.project_id
}

output "regions" {
  description = "Deployed regions."
  value       = var.regions
}

output "cloudsql_instance_names" {
  description = "Cloud SQL instance names by region."
  value       = { for region, instance in module.cloudsql : region => instance.instance_name }
}

output "redis_instance_names" {
  description = "Memorystore Redis instance names by region."
  value       = { for region, instance in module.redis : region => instance.instance_name }
}

output "pubsub_topics" {
  description = "Created Pub/Sub topic names."
  value       = module.pubsub.topic_names
}

output "avatar_bucket_names" {
  description = "Avatar asset bucket names by region."
  value       = { for region, bucket in module.storage : region => bucket.bucket_name }
}

output "kms_keyring_names" {
  description = "Cloud KMS keyring names by region."
  value       = module.kms.keyring_names
}

output "cloud_armor_policy_name" {
  description = "Cloud Armor security policy name."
  value       = module.cloud_armor.security_policy_name
}

output "vpc_service_perimeter_name" {
  description = "VPC Service Controls perimeter name."
  value       = module.vpc_service_controls.perimeter_name
}

output "service_account_emails" {
  description = "Provisioned service account emails."
  value       = module.iam.service_account_emails
}
