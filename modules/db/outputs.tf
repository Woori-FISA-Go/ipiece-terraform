output "db_sg_id" {
  value = aws_security_group.db.id
}

output "db_private_ips" {
  value = [for i in aws_instance.db : i.private_ip]
}
