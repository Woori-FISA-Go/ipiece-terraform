variable "name" {
  type = string
}

variable "customer_gateway_ip" {
  type = string
}

variable "customer_bgp_asn" {
  type    = number
  default = 65000
}

variable "vpn_gateway_id" {
  type = string
}

variable "remote_ipv4_cidr" {
  description = "AWS VPC CIDR, e.g. 10.0.0.0/16"
  type        = string
}

variable "onprem_supernet" {
  description = "Customer (on-prem+WG) supernet, e.g. 172.16.0.0/16"
  type        = string
}

variable "onprem_prefixes" {
  description = "Individual on-prem prefixes routed over VPN, e.g. [\"172.16.4.0/24\", \"172.16.60.0/24\"]"
  type        = list(string)
}

variable "tunnel1_preshared_key" {
  type      = string
  sensitive = true
}

variable "tunnel2_preshared_key" {
  type      = string
  sensitive = true
}

variable "private_route_table_ids" {
  description = "Private route tables from network module"
  type        = list(string)
}
