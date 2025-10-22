variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "az" {
  type    = string
  default = "ap-northeast-2a"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}

variable "enable_nat_gateway" {
  type    = bool
  default = false
}

variable "enable_ec2" {
  type    = bool
  default = false
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "dynamodb_read_capacity" {
  type    = number
  default = 5
}

variable "dynamodb_write_capacity" {
  type    = number
  default = 5
}