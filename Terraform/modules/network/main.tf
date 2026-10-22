## modules/network/main.tf

# --- VPC & Networking ---

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name      = "${var.project_name}-vpc"
    ManagedBy = "terraform"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Public Subnet for App Host
resource "aws_subnet" "app" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.app_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name      = "${var.project_name}-app-public-subnet"
    ManagedBy = "terraform"
  }
}

# Private Subnet for DB Host (No Public IP)
resource "aws_subnet" "db" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.db_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name      = "${var.project_name}-db-private-subnet"
    ManagedBy = "terraform"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name      = "${var.project_name}-igw"
    ManagedBy = "terraform"
  }
}

# Public Route Table (App Subnet -> Internet Gateway)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name      = "${var.project_name}-public-rt"
    ManagedBy = "terraform"
  }
}

resource "aws_route_table_association" "app_public" {
  subnet_id      = aws_subnet.app.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name      = "${var.project_name}-nat-eip"
    ManagedBy = "terraform"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.app.id

  tags = {
    Name      = "${var.project_name}-nat-gw"
    ManagedBy = "terraform"
  }

  depends_on = [aws_internet_gateway.main]
}

# Private Route Table for DB Subnet (Outbound via NAT Gateway)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name      = "${var.project_name}-private-rt"
    ManagedBy = "terraform"
  }
}

resource "aws_route_table_association" "db_private" {
  subnet_id      = aws_subnet.db.id
  route_table_id = aws_route_table.private.id
}

# --- Security Groups ---

resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Security group for App host"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name      = "${var.project_name}-app-sg"
    ManagedBy = "terraform"
  }
}

resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Security group for DB host"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name      = "${var.project_name}-db-sg"
    ManagedBy = "terraform"
  }
}

# --- Standalone Security Group Rules ---

# App SG: Allow HTTP (80) from anywhere
resource "aws_vpc_security_group_ingress_rule" "app_http" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

# App SG: Allow SSH (22) only from trusted CIDR
resource "aws_vpc_security_group_ingress_rule" "app_ssh" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = var.ssh_allowed_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

# DB SG: Allow SSH (22) from the App Host (Jump Server / Bastion)
resource "aws_vpc_security_group_ingress_rule" "db_ssh" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

# DB SG: Allow PostgreSQL (5432) ONLY from the App Security Group
resource "aws_vpc_security_group_ingress_rule" "db_postgres" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# App SG: Outbound internet access
resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# DB SG: Outbound internet access
resource "aws_vpc_security_group_egress_rule" "db_all" {
  security_group_id = aws_security_group.db.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
