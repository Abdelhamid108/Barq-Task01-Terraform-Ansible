# Application & Container Stack Documentation

This document summarizes the containerized application build specifications, Nginx proxy configuration, and Docker Compose orchestration templates used in the stack.

---

## 1. Application Reference & Dockerfile

* **Upstream Codebase**: [spring-projects/spring-petclinic](https://github.com/spring-projects/spring-petclinic) (Spring Boot, Spring Data JPA, PostgreSQL)
* **Image Registry**: `abdelhameed208/spring-petclinic`
* **Pinned Digest**: `sha256:0f7855aa67618347805cc8335d222a3b70223adfa451d373598d36fcb1438c3f`
* **Ansible Configuration**: Configured in `Ansible/roles/app_stack/defaults/main.yml` using digest pinning (`image@sha256:...`) to ensure immutable, deterministic deployments.

### Dockerfile Specification Used to Build the Image

```dockerfile
FROM eclipse-temurin:17-jre-alpine

# Upgrade OS packages to get latest security patches and install dependencies
RUN apk update --no-cache && \
    apk upgrade --no-cache && \
    apk add --no-cache curl tzdata expat && \
    addgroup -S appgroup -g 1001 && \
    adduser -S appuser -u 1001 -G appgroup

WORKDIR /app

# Copy pre-built JAR from CI pipeline
ARG JAR_FILE=target/*.jar
COPY --chown=appuser:appgroup ${JAR_FILE} app.jar

USER appuser:appgroup

EXPOSE 8080

# JVM container ergonomics for Kubernetes and containerized resource limits
ENV JAVA_TOOL_OPTIONS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=50.0 -Djava.security.egd=file:/dev/./urandom"

# Health check against Spring Boot Actuator
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
```

#### Key Highlights:
* **Minimal Base**: `eclipse-temurin:17-jre-alpine` reduces image size and attack surface.
* **Non-Root User**: Runs as `appuser:appgroup` (UID 1001) for container security.
* **JVM Container Limits**: `-XX:+UseContainerSupport` and `-XX:MaxRAMPercentage=75.0` allocate memory dynamically based on container limits while avoiding OOM kills.
* **Container Healthcheck**: Uses Spring Boot Actuator (`/actuator/health`) with a 40s grace period.

---

## 2. Nginx Reverse Proxy Configuration

* **File Path**: `Ansible/roles/app_stack/templates/nginx.conf.j2`
* **Role**: Acts as the single ingress point on the App host, terminating port `80` traffic and reverse proxying to the Spring application.

### Key Highlights:
* **Dual-Stack Binding**: Listens on both `80` (IPv4) and `[::]:80` (IPv6) to prevent Alpine Linux DNS resolution issues.
* **Header Forwarding**: Passes `Host`, `X-Real-IP`, `X-Forwarded-For`, and `X-Forwarded-Proto` to preserve client identity in Spring logs.
* **Mount Security**: Mounted into the Nginx container as read-only (`:ro`).

---

## 3. Docker Compose Orchestration

### App Stack
* **File Path**: `Ansible/roles/app_stack/templates/docker-compose.yml.j2`
* **Port Isolation**: Port `8080` is only `exposed` internally to the Docker bridge network. Only Nginx publishes port `80` to the host.
* **Dependency Health Gate**: `nginx` container defines `depends_on: app` with `condition: service_healthy`, preventing reverse proxy 502 errors while Spring Boot boots.
* **Secret Isolation**: Loads environment variables from `.env` instead of hardcoding credentials in the Compose file.

### Database Stack
* **File Path**: `Ansible/roles/db_stack/templates/docker-compose.yml.j2`
* **Persistent Storage**: Mounts the attached EBS volume from `/data/postgres` to `/var/lib/postgresql/data`.
* **Mountpoint Collision Fix (`PGDATA`)**: Configured with `PGDATA=/var/lib/postgresql/data/pgdata` to avoid `initdb` failures caused by `ext4`'s default `lost+found` directory.
* **Access Control**: Port `5432` is bound to the DB host, protected at the network layer by the AWS Security Group (accepting connections only from the App host).
* **Health Check**: Probes database readiness using `pg_isready -h 127.0.0.1 -U "$$POSTGRES_USER" -d postgres`.

---

## 4. Environment Templates (`.env.j2`)

* **App Environment**: `Ansible/roles/app_stack/templates/.env.j2`
  * Injects `SPRING_PROFILES_ACTIVE=postgres` and dynamic JDBC datasource credentials (`SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`).
* **DB Environment**: `Ansible/roles/db_stack/templates/.env.j2`
  * Injects `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `PGDATA`.
* **Security**: Both files are deployed to `/opt/<stack>/.env` with `owner: root`, `group: root`, and `mode: 0600` via Ansible with `no_log: true` enabled.
