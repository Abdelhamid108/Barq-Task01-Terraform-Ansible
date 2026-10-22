## variables.tf

variable "project_name" {
  description = "Name prefix for infrastructure resources"
  type        = string
  default     = "barq-task"
}

variable "aws_region" {
  description = "AWS Region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "app_subnet_cidr" {
  description = "CIDR block for public App subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "db_subnet_cidr" {
  description = "CIDR block for private DB subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "ssh_allowed_cidr" {
  description = "Trusted CIDR block allowed for SSH access"
  type        = string
}

variable "app_instance_type" {
  description = "EC2 instance type for App server"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_type" {
  description = "EC2 instance type for DB server"
  type        = string
  default     = "t3.micro"
}

variable "public_key_path" {
  description = "Path to public SSH key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "private_key_path" {
  description = "Path to private SSH key for Ansible"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "db_volume_gb" {
  description = "Size of EBS data volume in GB"
  type        = number
  default     = 10
}


