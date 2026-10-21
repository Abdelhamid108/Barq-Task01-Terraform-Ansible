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

locals {
  private_key = pathexpand(var.private_key_path)
  ssh_opts    = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../Ansible/inventory/hosts.ini"
  content  = <<-EOT
    [app]
    app01 ansible_host=${module.compute.app_instance_public_ip} private_ip=${module.compute.app_instance_private_ip}

    [db]
    db01 ansible_host=${module.compute.db_instance_private_ip} private_ip=${module.compute.db_instance_private_ip} data_volume_id=${module.compute.db_data_volume_id}

    [all:vars]
    ansible_user=ubuntu
    ansible_ssh_private_key_file=${local.private_key}
    ansible_ssh_common_args='${local.ssh_opts}'

    [db:vars]
    ansible_ssh_common_args='${local.ssh_opts} -o ProxyCommand="ssh -i ${local.private_key} ${local.ssh_opts} -W %h:%p -q ubuntu@${module.compute.app_instance_public_ip}"'
  EOT
}