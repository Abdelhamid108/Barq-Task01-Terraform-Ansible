#!/usr/bin/env bash
set -euo pipefail

HEADER_BORDER="=================================================="

echo "${HEADER_BORDER}"
echo " Starting End-to-End AWS & Ansible Deployment"
echo "${HEADER_BORDER}"

# 1. Check required tools
echo "==> [1/5] Verifying local CLI prerequisites..."
command -v terraform >/dev/null 2>&1 || { echo "[ERROR] terraform is required but not installed." >&2; exit 1; }
command -v ansible-playbook >/dev/null 2>&1 || { echo "[ERROR] ansible-playbook is required but not installed." >&2; exit 1; }

# 2. Detect operator public IP for SSH ingress rule
echo "==> [2/5] Detecting current public IP for SSH security rule..."
MY_IP=$(curl -s https://checkip.amazonaws.com || curl -s https://ifconfig.me)
if [[ -z "$MY_IP" ]]; then
  echo "[ERROR] Could not detect public IP address." >&2
  exit 1
fi
echo "Detected Public IP: ${MY_IP}"
ALLOWED_CIDR="${MY_IP}/32"

# 3. Apply Terraform Infrastructure
echo "==> [3/5] Initializing and applying Terraform infrastructure..."
cd Terraform
terraform init
terraform apply -auto-approve -var="ssh_allowed_cidr=${ALLOWED_CIDR}"
APP_PUBLIC_IP=$(terraform output -raw app_public_ip)
cd ..

# 4. Wait for SSH availability & cloud-init completion
echo "==> [4/5] Waiting for SSH access on App server (${APP_PUBLIC_IP})..."
until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i ~/.ssh/id_rsa ubuntu@"${APP_PUBLIC_IP}" "echo SSH Ready" >/dev/null 2>&1; do
  echo "    Waiting for EC2 instance initialization..."
  sleep 5
done

# 5. Install Ansible collections and run site playbook
echo "==> [5/5] Installing Ansible requirements and executing playbook..."
cd Ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook site.yml
cd ..

echo "${HEADER_BORDER}"
echo " Deployment Successfully Completed!"
echo " Access Spring Petclinic at port 80: ${APP_PUBLIC_IP}"
echo "${HEADER_BORDER}"