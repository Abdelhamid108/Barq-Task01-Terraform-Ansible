## outputs.tf

output "app_public_ip" {
  description = "Public IP address of the App server"
  value       = module.compute.app_instance_public_ip
}

output "app_private_ip" {
  description = "Private IP address of the App server"
  value       = module.compute.app_instance_private_ip
}

output "db_private_ip" {
  description = "Private IP address of the DB server"
  value       = module.compute.db_instance_private_ip
}

output "app_url" {
  description = "HTTP Endpoint to access the Nginx application"
  value       = "http://${module.compute.app_instance_public_ip}"
}