output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = var.vpc_cidr
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}

output "private_route_table_ids" {
  value = [for rt in aws_route_table.private : rt.id]
}

output "vpn_gateway_id" {
  value = length(aws_vpn_gateway.this) > 0 ? aws_vpn_gateway.this[0].id : null
}

output "nat_gateway_ids" {
  value = var.enable_nat_gateway ? [for n in aws_nat_gateway.this : n.id] : []
}
