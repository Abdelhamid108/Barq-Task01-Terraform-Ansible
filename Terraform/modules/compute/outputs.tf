## modules/compute/outputs.tf
output "app_instance_public_ip" {
    description = "app instance public ip"
    value       = aws_instance.app.public_ip
}

output "app_instance_priavte_ip" {
    description = "app instance public ip"
    value       = aws_instance.app.private_ip
}

output "db_instance_private_ip" {
    description = "db instance private ip"
    value       = aws_instance.db.private_ip
}
