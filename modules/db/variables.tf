variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  description = "Private subnets from network module"
  type        = list(string)
}

variable "ami_id" {
  description = "Ubuntu 24.04 AMI ID in ap-northeast-2"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "ssh_key_name" {
  type = string
}

variable "allowed_onprem_cidrs" {
  description = "CIDRs allowed for SSH/ICMP (e.g. [\"172.16.60.0/24\", \"172.16.4.0/24\"])"
  type        = list(string)
}

variable "user_data" {
  type    = string
  default = ""
}
