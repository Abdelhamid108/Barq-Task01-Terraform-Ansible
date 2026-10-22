# Ansible Configuration Specification

This document details the Ansible playbook structure, roles, container orchestration, persistent volume management, secrets vaulting, and database disaster recovery workflows.

---

## 1. Complete Directory & Role Architecture

```text
Ansible/
├── ansible.cfg             # Inventory path, default connection settings, vault password file
├── requirements.yml        # Galaxy collections (community.docker, community.general, ansible.posix)
├── site.yml               # Main execution playbook
├── group_vars/
│   └── all/
│       ├── vars.yml        # Shared variables & credential mappings
│       └── vault.yml       # Encrypted database credentials
├── inventory/
│   └── hosts.ini.example   # Sample inventory template
├── vault/
│   └── vault.example.yml   # Sample unencrypted vault template
└── roles/
    ├── app_stack/
    │   ├── defaults/
    │   │   └── main.yml    # Application container default variables
    │   ├── tasks/
    │   │   └── main.yml    # Nginx configuration templating & Compose deployment
    │   └── templates/
    │       ├── docker-compose.yml.j2 # App & Nginx multi-container Compose template
    │       ├── nginx.conf.j2         # Reverse proxy configuration template
    │       └── .env.j2               # App environment variables template
    ├── db_backup/
    │   ├── defaults/
    │   │   └── main.yml    # Backup path & retention policy default variables
    │   ├── tasks/
    │   │   └── main.yml    # Script deployment (pg_backup/restore) & cron scheduling
    │   └── templates/
    │       ├── pg_backup.sh.j2       # Automated database backup script template
    │       └── pg_restore.sh.j2      # Disaster recovery restore script template
    ├── db_stack/
    │   ├── defaults/
    │   │   └── main.yml    # PostgreSQL container default variables
    │   ├── tasks/
    │   │   └── main.yml    # EBS ext4 formatting, /data/postgres mount, Compose deploy
    │   └── templates/
    │       ├── docker-compose.yml.j2 # PostgreSQL 16 Compose template
    │       └── .env.j2               # Database environment variables template
    └── docker/
        ├── defaults/
        │   └── main.yml    # Docker engine default configuration
        ├── handlers/
        │   └── main.yml    # Systemd docker service start/enable handlers
        ├── tasks/
        │   └── main.yml    # Official Docker GPG key, APT repo setup, package install
        └── vars/
            └── main.yml    # Required OS prerequisite package list
```

---

## 2. Role Explanations

### `docker`
* Waits for cloud-init completion and installs base system requirements (`ca-certificates`, `curl`, `gnupg`, `apt-transport-https`, `git`).
* Configures official Docker GPG keyrings and APT repositories.
* Installs `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, and `docker-compose-plugin`.
* Appends `ubuntu` to the `docker` user group for non-root execution.
* Enables and starts `docker.service` on system boot.

### `db_stack`
* Formats `/dev/nvme1n1` (attached EBS volume) with `ext4` filesystem idempotently via `community.general.filesystem`.
* Mounts the EBS volume to `/data/postgres` using `ansible.posix.mount` (persisted in `/etc/fstab`).
* Deploys PostgreSQL 16 Alpine container with `restart: unless-stopped`, volume `/data/postgres:/var/lib/postgresql/data`, `.env` file configuration, and `pg_isready` health check probe.

### `app_stack`
* Templates Nginx proxy configuration (`nginx.conf.j2`) forwarding external port `80` to internal service `app:8080`.
* Deploys Spring Petclinic container (unpublished host port) and Nginx proxy container on a shared Docker bridge network.
* Exposes `/health` endpoint returning `200 healthy`.

### `db_backup`
* Installs and enables the `cron` system service.
* Deploys `/usr/local/sbin/pg_backup.sh` executing `pg_dump -Fc` directly from the active PostgreSQL container.
* Stores compressed `.dump` files in `/var/backups/postgresql/` with `0700` directory permissions and automated 7-day retention pruning.
* Deploys `/usr/local/sbin/pg_restore.sh` executing `pg_restore --clean --if-exists` for data recovery testing.
* Schedules a daily cron task running at `02:00 UTC` protected by `/usr/bin/flock` to prevent execution overlap.

---

## 3. Secrets & Vault Management

Sensitive credentials (`POSTGRES_PASSWORD`, `POSTGRES_USER`, `POSTGRES_DB`) are encrypted inside `Ansible/group_vars/all/vault.yml`.

Ansible automatically decrypts variables during playbook runs via `ansible.cfg`:
```ini
[defaults]
inventory = ./inventory/hosts.ini
remote_user = ubuntu
vault_password_file = ./vault/.vault.txt
roles_path = ./roles
```

---

## 4. Playbook Execution Order

The main playbook `Ansible/site.yml` coordinates host configuration in five sequential plays:

1. **Wait for SSH**: Uses `ansible.builtin.wait_for_connection` across all target hosts.
2. **Install Docker**: Executes `docker` role on all hosts.
3. **Deploy Database**: Executes `db_stack` role on `db` host.
4. **Deploy Application**: Executes `app_stack` role on `app` host.
5. **Backup Setup**: Executes `db_backup` role on `db` host.