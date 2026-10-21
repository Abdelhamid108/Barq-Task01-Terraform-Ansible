## main.tf

module "network" {
  source           = "./modules/network"
  project_name     = var.project_name
  vpc_cidr         = var.vpc_cidr
  app_subnet_cidr  = var.app_subnet_cidr
  db_subnet_cidr   = var.db_subnet_cidr
  ssh_allowed_cidr = var.ssh_allowed_cidr
}

module "compute" {
  source            = "./modules/compute"
  project_name      = var.project_name
  public_subnet_id  = module.network.app_subnet_id
  private_subnet_id = module.network.db_subnet_id
  app_sg_id         = module.network.app_sg_id
  db_sg_id          = module.network.db_sg_id
  app_instance_type = var.app_instance_type
  db_instance_type  = var.db_instance_type
  public_key_path   = var.public_key_path
  db_volume_gb      = var.db_volume_gb
}

# Dynamic Ansible Inventory Generator
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../Ansible/inventory/hosts.ini"
  content  = <<-EOT
    [app]
    app01 ansible_host=${module.compute.app_instance_public_ip} private_ip=${module.compute.app_instance_private_ip}

    [db]
    db01 ansible_host=${module.compute.db_instance_private_ip} private_ip=${module.compute.db_instance_private_ip}

    [all:vars]
    ansible_user=ubuntu
    ansible_ssh_private_key_file=${var.private_key_path}
    ansible_ssh_common_args='-o StrictHostKeyChecking=no'

    [db:vars]
    ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyCommand="ssh -i ${var.private_key_path} -W %h:%p -q ubuntu@${module.compute.app_instance_public_ip}"'
  EOT
}