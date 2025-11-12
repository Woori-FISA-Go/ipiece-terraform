resource "aws_customer_gateway" "this" {
  bgp_asn    = var.customer_bgp_asn
  ip_address = var.customer_gateway_ip
  type       = "ipsec.1"

  tags = {
    Name = "${var.name}-cgw"
  }
}

resource "aws_vpn_connection" "this" {
  vpn_gateway_id      = var.vpn_gateway_id
  customer_gateway_id = aws_customer_gateway.this.id
  type                = "ipsec.1"

  static_routes_only = true

  # AWS 기준: local=온프레, remote=VPC (콘솔 설정과 동일하게 맞춤)
  local_ipv4_network_cidr  = var.onprem_supernet   # e.g. 172.16.0.0/16
  remote_ipv4_network_cidr = var.remote_ipv4_cidr  # e.g. 10.0.0.0/16

  tunnel1_preshared_key = var.tunnel1_preshared_key
  tunnel2_preshared_key = var.tunnel2_preshared_key

  tags = {
    Name = var.name
  }
}

# Static routes for each on-prem prefix
resource "aws_vpn_connection_route" "onprem" {
  for_each = toset(var.onprem_prefixes)

  vpn_connection_id      = aws_vpn_connection.this.id
  destination_cidr_block = each.value
}

# Add on-prem routes into each private route table (more specific than 0.0.0.0/0 via NAT)
locals {
  rt_onprem_pairs = flatten([
    for rt_id in var.private_route_table_ids : [
      for cidr in var.onprem_prefixes : {
        key  = "${rt_id}-${cidr}"
        rt   = rt_id
        cidr = cidr
      }
    ]
  ])
}

resource "aws_route" "to_onprem" {
  for_each = {
    for p in local.rt_onprem_pairs :
    p.key => p
  }

  route_table_id         = each.value.rt
  destination_cidr_block = each.value.cidr
  gateway_id             = var.vpn_gateway_id
}
