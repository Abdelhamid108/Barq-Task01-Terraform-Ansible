## modules/network/outputs.tf

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "app_sg_id" {
  description = "ID of the App Security Group"
  value       = aws_security_group.app.id
}

output "db_sg_id" {
  description = "ID of the DB Security Group"
  value       = aws_security_group.db.id
}
