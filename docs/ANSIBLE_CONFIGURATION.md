# Ansible Configuration & Deployment Documentation

This document details the Ansible roles, playbooks, directory layout, Vault encryption, and disaster recovery orchestration used across the stack.

---

## 1. Role Architecture & Layout

```
Ansible/
├── ansible.cfg             # Inventory path, default connection settings, vault password file
├── requirements.yml        # Galaxy collections (community.docker, community.general, ansible.posix)
├── site.yml               # Main execution playbook with readiness gate
├── group_vars/
│   └── all/
│       ├── vars.yml        # Shared variables & credential mappings
│       └── vault.yml       # Encrypted database credentials
├── vault/
│   └── .vault.txt          # Decryption password file (Git-ignored)
└── roles/
    ├── common/             # OS package prerequisites, curl, git, ca-certificates
    ├── docker/             # Docker CE Engine, Compose plugin, gpg keyrings, service enable
    ├── db_stack/           # EBS ext4 filesystem, /data/postgres mount, PostgreSQL 16 Compose
    ├── db_backup/          # Backup script (pg_backup.sh), restore script (pg_restore.sh), nightly cron
    └── app_stack/          # Spring Petclinic container, Nginx reverse proxy, proxy headers
```

---

## 2. Role Explanations

### `common`
* Enforces Debian/Ubuntu OS check.
* Installs base system requirements (`curl`, `gnupg`, `apt-transport-https`, `ca-certificates`, `git`).

### `docker`
* Adds official Docker GPG keyrings and APT repositories dynamically.
* Installs `docker-ce`, `docker-ce-cli`, `containerd.io`, and `docker-compose-plugin`.
* Grants non-root execution by appending `ubuntu` to the `docker` user group.
* Starts and enables the Docker systemd daemon.

### `db_stack`
* Formats `/dev/nvme1n1` (attached EBS volume) with `ext4` filesystem idempotently via `community.general.filesystem`.
* Mounts the EBS volume to `/data/postgres` with `opts: defaults,nofail` using `ansible.posix.mount` (persisted in `/etc/fstab`).
* Deploys PostgreSQL 16 Alpine container with `restart: unless-stopped`, volume `/data/postgres:/var/lib/postgresql/data`, and health probe.

### `app_stack`
* Templates Nginx proxy configuration (`nginx.conf.j2`) forwarding port `80` to internal application service `app:8080`.
* Deploys Spring Petclinic container (unpublished port) and Nginx container on a shared Docker bridge network.
* Exposes `/health` endpoint returning `200 healthy`.

### `db_backup`
* Deploys `/usr/local/sbin/pg_backup.sh` executing `pg_dump -Fc` from the active PostgreSQL container.
* Stores `.dump` files in `/var/backups/postgresql/` with `0750` permissions and automated 7-day retention pruning.
* Deploys `/usr/local/sbin/pg_restore.sh` executing `pg_restore --clean --if-exists` for data recovery.
* Schedules a daily cron task running at `02:00 UTC` protected by `flock`.

---

## 3. Secrets & Vault Management

Sensitive credentials (`POSTGRES_PASSWORD`, `POSTGRES_USER`, `POSTGRES_DB`) are encrypted inside `Ansible/group_vars/all/vault.yml`.

Ansible automatically decrypts variables during playbook runs via `ansible.cfg`:
```ini
[defaults]
vault_password_file = ./vault/.vault.txt
```

---

## 4. Playbook Execution & Readiness Gate

The main playbook `Ansible/site.yml` prevents race conditions by enforcing a database readiness check prior to starting the application stack:

1. Executes `common` and `docker` roles on all hosts.
2. Deploys `db_stack` and `db_backup` roles on the `db` host.
3. **Readiness Gate**: `ansible.builtin.wait_for` probes port `5432` on `db01`'s private IP from `app01` until PostgreSQL is ready.
4. Deploys `app_stack` role on the `app` host.