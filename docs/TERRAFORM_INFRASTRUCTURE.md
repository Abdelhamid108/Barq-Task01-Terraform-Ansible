# Terraform Infrastructure Documentation

This document outlines the Terraform architecture, module hierarchy, network topology, security model, and automated inventory integration for the project.

---

## 1. Complete Directory & Module Structure

```text
Terraform/
├── main.tf                 # Root module wiring network, compute, and inventory generation
├── outputs.tf              # Active IP endpoints and application URLs
├── providers.tf            # AWS provider (~> 6.70.0), Local provider (~> 2.9), S3 state backend
├── terraform.auto.tfvars   # Automatically generated operator IP tfvars (Git-ignored)
├── terraform.tfvars        # Active variable overrides (Git-ignored)
├── terraform.tfvars.example # Sample variable configuration template
├── variables.tf            # Input variable declarations
└── modules/
    ├── compute/
    │   ├── main.tf         # EC2 instances, SSH Key Pair, EBS data volume attachment
    │   ├── outputs.tf      # Instance public/private IPs and data volume ID
    │   └── variables.tf    # Compute module variables & validation rules
    └── network/
        ├── main.tf         # VPC, Subnets, IGW, NAT Gateway, Route Tables, SGs
        ├── outputs.tf      # Subnet IDs, VPC ID, Security Group IDs
        └── variables.tf    # Network module variables
```

---

## 2. Infrastructure Resources & Security Model

### Network Module (`modules/network/`)
* **VPC**: Dedicated `10.0.0.0/16` CIDR block with DNS hostnames enabled.
* **Public Subnet**: `10.0.1.0/24` hosting the App server with Internet Gateway (`IGW`) routing and `map_public_ip_on_launch = true`.
* **Private Subnet**: `10.0.2.0/24` hosting the DB server (`map_public_ip_on_launch = false`), routed through an Elastic IP NAT Gateway for outbound updates and Docker image pulls without direct internet exposure.
* **Security Groups**:
  * `sg-app`: Exposes HTTP port `80` publicly (`0.0.0.0/0`) and SSH port `22` restricted to `var.ssh_allowed_cidr`.
  * `sg-db`: Exposes PostgreSQL port `5432` strictly to `sg-app`. Exposes SSH port `22` strictly to `sg-app` (enabling SSH ProxyJump access).

### Compute Module (`modules/compute/`)
* **App Host**: Ubuntu 24.04 LTS (`t3.micro`) in the Public Subnet with IMDSv2 enforced (`http_tokens = "required"`) and 12GB encrypted root block device.
* **DB Host**: Ubuntu 24.04 LTS (`t3.micro`) in the Private Subnet with IMDSv2 enforced and 12GB encrypted root block device.
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
    db01 ansible_host=${module.compute.db_instance_private_ip} private_ip=${module.compute.db_instance_private_ip} data_volume_id=${module.compute.db_data_volume_id}

    [all:vars]
    ansible_user=ubuntu
    ansible_ssh_private_key_file=${local.private_key}
    ansible_ssh_common_args='${local.ssh_opts}'

    [db:vars]
    ansible_ssh_common_args='${local.ssh_opts} -o ProxyCommand="ssh -i ${local.private_key} ${local.ssh_opts} -W %h:%p -q ubuntu@${module.compute.app_instance_public_ip}"'
  EOT
}
```