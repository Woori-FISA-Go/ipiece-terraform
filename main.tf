terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws    = { source = "hashicorp/aws",    version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "aws" {
  region = var.region
}

locals {
  tags = merge({
    Project     = "infracost-demo"
    CostCenter  = "cc-001"
    Environment = var.environment
  }, var.extra_tags)
}

# ───────────────────────────────────────────────────────────────────────────
# Networking (VPC + Public Subnet + IGW)  — NAT GW는 옵션(enable_nat_gateway)
# ───────────────────────────────────────────────────────────────────────────
resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(local.tags, { Name = "demo-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "demo-igw" })
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = var.az
  tags = merge(local.tags, { Name = "demo-public-a" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(local.tags, { Name = "demo-public-rt" })
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway (시간당 + 처리량 비용) — Diff 확인용으로 매우 효과적
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"
  tags   = merge(local.tags, { Name = "demo-nat-eip" })
}

resource "aws_nat_gateway" "this" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public_a.id
  tags          = merge(local.tags, { Name = "demo-nat-gw" })
}

# ───────────────────────────────────────────────────────────────────────────
# Compute (EC2) — 소형 인스턴스 1대.
# ───────────────────────────────────────────────────────────────────────────
data "aws_ssm_parameter" "al2023" {
  # 최신 Amazon Linux 2023 (x86_64)
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

resource "aws_security_group" "web" {
  name        = "demo-sg-web"
  description = "Allow HTTP"
  vpc_id      = aws_vpc.this.id
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.tags, { Name = "demo-sg-web" })
}

resource "aws_instance" "web" {
  count                       = var.enable_ec2 ? 1 : 0
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true
  tags                        = merge(local.tags, { Name = "demo-ec2" })
}

# ───────────────────────────────────────────────────────────────────────────
# Storage (S3) — 사용량 가정(infracost-usage.yml)으로 정확도 ↑
# ───────────────────────────────────────────────────────────────────────────
resource "random_id" "suffix" {
  byte_length = 3
}

resource "aws_s3_bucket" "logs" {
  bucket = "tf-costdemo-${random_id.suffix.hex}"
  tags   = merge(local.tags, { Name = "demo-logs" })
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration { status = "Enabled" }
}

# ───────────────────────────────────────────────────────────────────────────
# Database (DynamoDB) — PROVISIONED으로 고정비 발생 → Diff에 명확
# ───────────────────────────────────────────────────────────────────────────
resource "aws_dynamodb_table" "orders" {
  name           = "demo-orders"
  billing_mode   = "PROVISIONED"
  read_capacity  = var.dynamodb_read_capacity
  write_capacity = var.dynamodb_write_capacity

  hash_key = "id"
  attribute {
    name = "id"
    type = "S"
  }

  tags = merge(local.tags, { Name = "demo-dynamodb" })
}
