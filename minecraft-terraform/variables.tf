# Region
variable "region" {
  type        = string
  default     = "eu-west-3"
  description = "AWS region to deploy to"
}

variable "availability_zone" {
  description = "Subnets Availability Zone"
  default     = "eu-west-3a"
}


# VPC
variable "vpc_cidr" {
  default     = "10.48.0.0/16"
  description = "CIDR block for the VPC"
}

variable "subnet_public_cidr" {
  default     = "10.48.50.0/24"
  description = "CIDR block for the public subnet"
}


# EC2
variable "ec2_instance_connect" {
  type        = bool
  default     = true
  description = "Keep SSH (port 22) open to allow connections via EC2 Instance Connect"
}

variable "minecraft_ami" {
  description = "AMI to use for the EC2"
  # Default is Amazon Linux 2023 AMI (34-bit, Arm)
  default = "ami-016e8ec7559ac3629"
}

variable "instance_type" {
  type        = string
  default     = "t4g.small"
  description = "EC2 instance type"
}

variable "ec2_ssh_cidr" {
  type        = string
  default     = "83.199.176.224/32"
  description = "CIDR block to access the EC2 via SSH"
}
