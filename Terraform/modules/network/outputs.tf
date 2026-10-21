## modules/network/outputs.tf

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "app_subnet_id" {
  description = "ID of the public App subnet"
  value       = aws_subnet.app.id
}

output "db_subnet_id" {
  description = "ID of the private DB subnet"
  value       = aws_subnet.db.id
}

output "app_sg_id" {
  description = "ID of the App Security Group"
  value       = aws_security_group.app.id
}

output "db_sg_id" {
  description = "ID of the DB Security Group"
  value       = aws_security_group.db.id
}
