terraform {
  required_version = ">= 1.6.0"
  backend "local" {}
}

provider "aws" {
  region = "ap-northeast-2"
}

data "terraform_remote_state" "network" {
  backend = "local"
  config = {
    path = "${path.module}/../network/terraform.tfstate"
  }
}

module "db_ha" {
  source = "../../../modules/db"

  name = "cloud-ha-lab-dev"

  # 네트워크 모듈에서 만든 값 가져오기
  vpc_id               = data.terraform_remote_state.network.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids

  # 🔥 여기 중요: tfvars에서 넣어준 값 사용
  ami_id         = var.ami_id
  ssh_key_name  = var.ssh_key_name
  # 🔽 'private_ips' 변수를 모듈에 전달하도록 추가
  private_ips    = var.private_ips

  # 온프레 & WireGuard 대역에서 DB 접근 허용
  allowed_onprem_cidrs = [
    "172.16.60.0/24",
    "172.16.4.0/24",
  ]

  # AZ 2개에 각각 1대씩
  instance_type = "t3.medium"

  # 나중에 Patroni/etcd 셋업하면 여기 user_data에 스크립트 넣으면 됨
  user_data = ""
}