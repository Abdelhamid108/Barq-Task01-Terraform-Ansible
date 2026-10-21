## modules/netwrok/variables.tf

variable "project_name" {
  description = "Name prefix for all infrastructure resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "app_subnet_cidr" {
  description = "CIDR block for the public App subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "db_subnet_cidr" {
  description = "CIDR block for the private DB subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "ssh_allowed_cidr" {
  description = "Trusted CIDR block allowed to SSH into the App host"
  type        = string
}
