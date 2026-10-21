data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-key"
  public_key = file(var.public_key_path)
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.app_sg_id]
  key_name               = aws_key_pair.deployer.key_name

  root_block_device {
    volume_size = 12
    encrypted   = true
  }
  tags = { Name = "${var.project_name}-app" }
  lifecycle { ignore_changes = [ami] }
}

resource "aws_instance" "db" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.private_instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.db_sg_id]
  key_name               = aws_key_pair.deployer.key_name

  root_block_device {
    volume_size = 12
    encrypted   = true
  }
  tags = { Name = "${var.project_name}-db" }
  lifecycle { ignore_changes = [ami] }
}

resource "aws_ebs_volume" "db_data" {
  availability_zone = aws_instance.db.availability_zone
  size              = var.db_volume_gb
  type              = "gp3"
  encrypted         = true
  tags = { Name = "${var.project_name}-db-data" }
}

resource "aws_volume_attachment" "db_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.db_data.id
  instance_id = aws_instance.db.id
}