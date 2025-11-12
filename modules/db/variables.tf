variable "name" {
  description = "DB 인스턴스의 기본 이름 (예: cloud-ha-lab-dev)"
  type        = string
}

variable "vpc_id" {
  type = string
}

# 🔽 'list(string)'로 다시 변경 (님의 원본 코드)
variable "private_subnet_ids" {
  description = "DB 인스턴스 2대가 생성될 Private Subnet ID 리스트"
  type        = list(string)
}

# 🔽 'private_ips' 리스트 변수를 새로 추가
variable "private_ips" {
  description = "EC2 인스턴스에 고정 할당할 프라이빗 IP 주소 리스트"
  type        = list(string)
}

variable "ami_id" {
  description = "Ubuntu 24.04 AMI ID in ap-northeast-2"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "ssh_key_name" {
  type = string
}

variable "allowed_onprem_cidrs" {
  description = "SSH/ICMP를 허용할 온프레미스 CIDR 대역"
  type        = list(string)
}

variable "user_data" {
  type    = string
  default = ""
}