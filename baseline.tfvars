project_name = "ipiece"
aws_region   = "ap-northeast-2"
azs          = ["ap-northeast-2a", "ap-northeast-2c"]

vpc_cidr              = "10.10.0.0/16"
public_subnet_cidrs   = ["10.10.0.0/24", "10.10.1.0/24"]
private_subnet_cidrs  = ["10.10.10.0/24", "10.10.11.0/24"]
db_subnet_cidrs       = ["10.10.20.0/24", "10.10.21.0/24"]

eks_version       = "1.30"
node_instance_type = "m6i.large"
node_disk_size     = 100

rds_engine            = "mysql"
rds_engine_version    = "8.0"
rds_instance_class    = "db.m6i.large"
rds_allocated_storage = 100
rds_backup_retention  = 7
db_username           = "admin"
db_password           = "CHANGE-ME"

redis_node_type    = "cache.t3.medium"
redis_num_replicas = 0

enable_route53    = false
route53_zone_name = ""
