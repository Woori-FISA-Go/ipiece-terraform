terraform {
  required_version = ">= 1.6.0"
  backend "local" {}
}

provider "aws" {
  region = "ap-northeast-2"
}

module "network" {
  source = "../../../modules/network"

  name     = "cloud-ha-lab-dev"
  vpc_cidr = "10.0.0.0/16"

  azs = [
    "ap-northeast-2a",
    "ap-northeast-2c",
  ]

  public_subnet_cidrs = [
    "10.0.0.0/24",  # a
    "10.0.1.0/24",  # c
  ]

  private_subnet_cidrs = [
    "10.0.128.0/20", # a
    "10.0.144.0/20", # c (여기 EC2 10.0.144.x 이미 쓰는거 맞춰둠)
  ]

  enable_vpn_gateway = true
  enable_nat_gateway = true
}
