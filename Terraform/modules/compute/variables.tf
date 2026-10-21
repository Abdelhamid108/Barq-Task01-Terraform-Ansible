variable "app_instance_type" {
  description = "Instance type for the app server"
  type        = string
}

variable "db_instance_type" {
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

  validation {
    condition     = var.db_volume_gb >= 1
    error_message = "db_volume_gb must be at least 1 GiB."
  }
}

variable "project_name" {
  description = "Project name for tagging resources"
  type        = string
}

variable "public_key_path" {
  description = "Path to the public SSH key registered for the instances"
  type        = string
}
