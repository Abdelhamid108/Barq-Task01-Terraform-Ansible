## modules/compute/variables.tf

variable "app_instance_type" {
  description = "Instance type for the app server"
  type        = string
}

varible "db_instance_type" {
  description = "Instance type for the db server"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for the app server"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet ID for the db server"
  type        = string
}

variable "app_sg_id" {
  description = "Security group ID for the app server"
  type        = string
}

variable "db_sg_id" {
  description = "Security group ID for the db server"
  type        = string
}

variable "db_volume_gb" {
  description = "Size of the EBS volume for the db server in GB"
  type        = number
}

variable "project_name" {
  description = "Project name for tagging resources"
  type        = string
}
