terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.61"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

############################################
# 1) VPC (2AZ, Pub/Priv/DB + NAT per AZ)
############################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.5"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs              = var.azs
  public_subnets   = var.public_subnet_cidrs
  private_subnets  = var.private_subnet_cidrs
  database_subnets = var.db_subnet_cidrs

  enable_nat_gateway   = true
  single_nat_gateway   = false
  one_nat_gateway_per_az = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Project = var.project_name }
}

############################################
# 2) EKS (NodeGroup: AZ별 2대)
############################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name    = "${var.project_name}-eks"
  cluster_version = var.eks_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = false # 🚨 'apply'가 로컬 PC이면 실패합니다.
  cluster_endpoint_private_access = true

  eks_managed_node_groups = {
    az1 = {
      name           = "mng-az1"
      subnet_ids     = [module.vpc.private_subnets[0]]
      instance_types = [var.node_instance_type]
      min_size       = 2
      desired_size   = 2
      max_size       = 6
      disk_size      = var.node_disk_size
    }
    az2 = {
      name           = "mng-az2"
      subnet_ids     = [module.vpc.private_subnets[1]]
      instance_types = [var.node_instance_type]
      min_size       = 2
      desired_size   = 2
      max_size       = 6
      disk_size      = var.node_disk_size
    }
  }

  tags = { Project = var.project_name }
}

############################################
# 2b) ✅ EKS -> RDS/Redis 접근용 보안 그룹
############################################

# [신규] RDS(MySQL) 보안 그룹
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow EKS nodes to access RDS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "EKS Nodes to MySQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    # EKS 모듈이 생성한 '노드 보안 그룹' ID를 참조합니다.
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Project = var.project_name }
}

# [신규] ElastiCache(Redis) 보안 그룹
resource "aws_security_group" "redis" {
  name        = "${var.project_name}-redis-sg"
  description = "Allow EKS nodes to access Redis"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "EKS Nodes to Redis"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    # EKS 모듈이 생성한 '노드 보안 그룹' ID를 참조합니다.
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Project = var.project_name }
}


############################################
# 3) RDS (MySQL, Multi-AZ)
############################################
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.13.1"

  identifier           = "${var.project_name}-rds"
  engine               = var.rds_engine
  engine_version       = var.rds_engine_version
  major_engine_version = "8.0"
  instance_class       = var.rds_instance_class
  allocated_storage    = var.rds_allocated_storage
  multi_az             = true
  storage_encrypted    = true
  skip_final_snapshot  = true
  backup_retention_period = var.rds_backup_retention
  username             = var.db_username
  password             = var.db_password
  db_name              = "appdb"
  port                 = 3306
  subnet_ids           = module.vpc.database_subnets

  # ✅ [수정] Plan 오류 해결을 위해 'family' 명시
  family = "mysql8.0"

  # ✅ [수정] Default SG 대신 위에서 생성한 'rds' 전용 SG 사용
  vpc_security_group_ids = [aws_security_group.rds.id]

  tags = { Project = var.project_name }
}

############################################
# 4) ElastiCache Redis
############################################
resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.project_name}-redis-subnets"
  subnet_ids = module.vpc.private_subnets # Redis는 DB Subnet이 아닌 Private Subnet 권장
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id     = "${var.project_name}-redis"
  description              = "Redis for ${var.project_name}"
  engine                   = "redis"
  engine_version           = "7.1"
  node_type                = var.redis_node_type
  automatic_failover_enabled = var.redis_num_replicas > 0 ? true : false
  num_node_groups          = 1
  replicas_per_node_group  = var.redis_num_replicas
  port                     = 6379
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  subnet_group_name        = aws_elasticache_subnet_group.this.name
  apply_immediately        = true

  # ✅ [수정] Default SG 대신 위에서 생성한 'redis' 전용 SG 사용
  security_group_ids = [aws_security_group.redis.id]

  tags = { Project = var.project_name }
}

############################################
# 5) Route53 퍼블릭 호스트존 (옵션)
############################################
resource "aws_route53_zone" "public" {
  count = var.enable_route53 ? 1 : 0
  name  = var.route53_zone_name
}