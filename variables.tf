variable "project_name" { type = string }
variable "aws_region" { type = string }
variable "azs" { type = list(string) }
variable "vpc_cidr" { type = string }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "db_subnet_cidrs" { type = list(string) }

variable "eks_version" { type = string }
variable "node_instance_type" { type = string }
variable "node_disk_size" { type = number }

variable "rds_engine" { type = string }
variable "rds_engine_version" { type = string }
variable "rds_instance_class" { type = string }
variable "rds_allocated_storage" { type = number }
variable "rds_backup_retention" { type = number }
variable "db_username" { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}

variable "redis_node_type" { type = string }
variable "redis_num_replicas" { type = number }

variable "enable_route53" { type = bool }
variable "route53_zone_name" { type = string }
