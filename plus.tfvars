environment = "prod"
enable_nat_gateway = true
enable_ec2 = true
instance_type = "t3.small"

# 프로비저닝 용량도 키워서 고정비 증가를 명확히
dynamodb_read_capacity  = 100
dynamodb_write_capacity = 100
