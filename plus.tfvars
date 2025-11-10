project_name = "ipiece-plus"
aws_region   = "ap-northeast-2"
azs          = ["ap-northeast-2a", "ap-northeast-2c"]

vpc_cidr             = "10.20.0.0/16"
public_subnet_cidrs  = ["10.20.0.0/24", "10.20.1.0/24"]
private_subnet_cidrs = ["10.20.10.0/24", "10.20.11.0/24"]
db_subnet_cidrs      = ["10.20.20.0/24", "10.20.21.0/24"]

node_instance_type = "m6i.xlarge"
node_disk_size     = 150

rds_instance_class    = "db.m6i.xlarge"
rds_allocated_storage = 200
rds_backup_retention  = 15
db_password           = "CHANGE-ME-PLUS"

redis_node_type    = "cache.m6g.large"
redis_num_replicas = 1

enable_route53    = true
route53_zone_name = "example.com"
