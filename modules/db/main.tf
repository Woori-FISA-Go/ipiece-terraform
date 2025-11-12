resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "DB HA SG (Patroni/etcd/Postgres)"
  vpc_id      = var.vpc_id

  # etcd Client
  ingress {
    from_port   = 2379
    to_port     = 2379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "etcd Client Port (Patroni)"
  }

  # etcd Peer
  ingress {
    from_port   = 2380
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "etcd Peer Port"
  }

  # Patroni API
  ingress {
    from_port   = 8008
    to_port     = 8008
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Patroni API"
  }

  # PostgreSQL
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Postgres from VPC"
  }

  # SSH from on-prem/WG
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_onprem_cidrs
    description = "SSH from on-prem/WG"
  }

  # ICMP from on-prem/WG
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = var.allowed_onprem_cidrs
    description = "Ping from on-prem/WG"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-db-sg"
  }
}

# EC2 2대: 각 AZ의 private subnet 하나씩
# private_subnet_ids[0], private_subnet_ids[1] 기준

resource "aws_instance" "db" {
  count = 2

  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_ids[count.index]
  vpc_security_group_ids = [aws_security_group.db.id]
  key_name               = var.ssh_key_name
  associate_public_ip_address = false

  user_data = var.user_data

  tags = {
    Name = "${var.name}-db-${count.index + 1}"
    Role = "db-ha-node"
  }
}
