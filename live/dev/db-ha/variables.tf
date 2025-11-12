variable "ami_id" {
  description = "DB EC2 인스턴스에 사용할 AMI ID"
  type        = string
}

variable "ssh_key_name" {
  description = "EC2 인스턴스에 사용할 SSH 키 이름"
  type        = string
}

variable "private_ips" {
  description = "DB 인스턴스 2대에 고정 할당할 프라이빗 IP 리스트"
  type        = list(string)
}