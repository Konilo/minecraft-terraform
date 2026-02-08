# Region
variable "region" {
  type        = string
  default     = "eu-west-3"
  description = "AWS region to deploy to"
}

variable "availability_zone" {
  description = "Subnets availability zone"
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
  # Amazon Linux 2023 AMI (64-bit (x86), uefi-preferred)
  default = "ami-03b82db05dca8118d"
}

variable "instance_type" {
  type        = string
  # Requires x86 architecture
  # Charges apply for this instance type
  default     = "t3a.large"
  description = "EC2 instance type"
}

variable "ec2_ssh_cidr" {
  type        = string
  # Replace with your IP address https://whatismyipaddress.com/
  # Leave the "/32" at the end
  # Or use `terraform apply -var 'ec2_ssh_cidr=YOUR_IP_ADDRESS/32'`
  default     = "xx.xx.xx.xx/32"
  description = "CIDR block to access the EC2 via SSH."
}
