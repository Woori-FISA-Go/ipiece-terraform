variable "name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  description = "List of AZs, ex: [\"ap-northeast-2a\", \"ap-northeast-2c\"]"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "One public subnet CIDR per AZ"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "One private subnet CIDR per AZ"
  type        = list(string)
}

variable "enable_vpn_gateway" {
  type    = bool
  default = true
}

variable "enable_nat_gateway" {
  type    = bool
  default = true
}
