output "app_instance_public_ip" {
  description = "Public IP address of the application instance"
  value       = aws_instance.app.public_ip
}

output "app_instance_private_ip" {
  description = "Private IP address of the application instance"
  value       = aws_instance.app.private_ip
}

output "db_instance_private_ip" {
  description = "Private IP address of the database instance"
  value       = aws_instance.db.private_ip
}
