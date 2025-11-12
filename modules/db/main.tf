resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "DB HA SG (Patroni/etcd/Postgres)"
  vpc_id      = var.vpc_id

  # etcd Client
  ingress {
    from_port   = 2379
    to_port     = 2379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # (참고: 앱 서버 등 VPC 내부의 다른 리소스용)
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

# 🔽 [수정 완료] 핑(Ping) 및 내부 통신을 위한 규칙을 별도 리소스로 분리
resource "aws_security_group_rule" "db_self_ingress" {
  type                      = "ingress"
  from_port                 = 0
  to_port                   = 0
  protocol                  = "-1" # 모든 프로토콜
  security_group_id         = aws_security_group.db.id # 이 규칙을 적용할 대상 SG
  source_security_group_id  = aws_security_group.db.id # "자기 자신"의 ID를 소스로 지정
  description               = "Allow all internal cluster traffic (Patroni, etcd, Ping)"
}


# EC2 리소스 (변경 없음)
resource "aws_instance" "db" {
  # 리스트의 길이만큼 (2개) 생성
  count = length(var.private_subnet_ids)

  ami                   = var.ami_id
  instance_type         = var.instance_type
  key_name              = var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.db.id]
  associate_public_ip_address = false

  # Subnet ID를 리스트에서 하나씩 가져와 적용
  subnet_id             = var.private_subnet_ids[count.index]

  # Private IP를 리스트에서 하나씩 가져와 적용
  private_ip            = var.private_ips[count.index]

  user_data = var.user_data

  tags = {
    # 태그가 'db-1', 'db-2'로 생성되도록 count.index 사용
    Name = "${var.name}-db-${count.index + 1}"
    Role = "db-ha-node"
  }
}