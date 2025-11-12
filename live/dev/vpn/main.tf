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

module "vpn" {
  source = "../../../modules/vpn"

  name = "cloud-ha-lab-dev-vpn"

  customer_gateway_ip  = "118.131.63.236"      # pfSense 공인 IP
  customer_bgp_asn     = 65000
  vpn_gateway_id       = data.terraform_remote_state.network.outputs.vpn_gateway_id
  remote_ipv4_cidr     = "10.0.0.0/16"         # AWS VPC
  onprem_supernet      = "172.16.0.0/16"       # 172.16.4.0/24 + 172.16.60.0/24 포함
  onprem_prefixes      = ["172.16.4.0/24", "172.16.60.0/24"]
  private_route_table_ids = data.terraform_remote_state.network.outputs.private_route_table_ids

  tunnel1_preshared_key = var.tunnel1_psk
  tunnel2_preshared_key = var.tunnel2_psk
}
