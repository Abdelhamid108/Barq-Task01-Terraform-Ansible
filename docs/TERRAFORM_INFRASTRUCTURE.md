# Terraform Infrastructure Documentation

This document outlines the Terraform architecture, module hierarchy, network topology, and automated inventory integration for the project.

---

## 1. Directory Structure & Module Split

The configuration uses a modular architecture with clear separation of network and compute resources:

```
Terraform/
├── main.tf                 # Root module wiring network, compute, and inventory generation
├── providers.tf            # AWS provider (~> 5.0), Local provider (~> 2.4), S3 backend configuration
├── variables.tf            # Input variable declarations
├── outputs.tf              # Infrastructure endpoints and IP outputs
├── terraform.tfvars        # Active variable values (Git-ignored)
└── modules/
    ├── network/            # VPC, Subnets, Gateways, Route Tables, Security Groups
    └── compute/            # EC2 instances, SSH Key Pair, EBS data volume attachment
```

---

## 2. Infrastructure Resources

### Network Module (`modules/network/`)
* **VPC**: Dedicated `10.0.0.0/16` CIDR block with DNS hostnames enabled.
* **Public Subnet**: `10.0.1.0/24` hosting the App server with Internet Gateway (`IGW`) routing.
* **Private Subnet**: `10.0.2.0/24` hosting the DB server routed through a NAT Gateway for outbound updates and Docker image pulls.
* **Security Groups**:
  * `sg-app`: Exposes HTTP port `80` publicly (`0.0.0.0/0`) and SSH port `22` restricted to `var.ssh_allowed_cidr`.
  * `sg-db`: Exposes PostgreSQL port `5432` strictly to instances associated with `sg-app`. Exposes SSH port `22` strictly to `sg-app` (enabling SSH ProxyJump access).

### Compute Module (`modules/compute/`)
* **App Host**: Ubuntu 24.04 LTS (`t3.small` / `t3.micro`) in the Public Subnet.
* **DB Host**: Ubuntu 24.04 LTS (`t3.small` / `t3.micro`) in the Private Subnet.
* **EBS Data Volume**: 10GB `gp3` encrypted volume attached to the DB host at `/dev/sdf` (maps to `/dev/nvme1n1` on Nitro instances).
* **AMI Lookup**: Canonical Ubuntu 24.04 LTS pinned with `lifecycle { ignore_changes = [ami] }` to maintain plan idempotency.

---

## 3. Dynamic Ansible Inventory Generator

The root `main.tf` defines a `local_file` resource (`ansible_inventory`) that automatically renders `Ansible/inventory/hosts.ini` upon running `terraform apply`:

```hcl
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
```