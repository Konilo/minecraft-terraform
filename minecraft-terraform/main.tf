# AWS configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.33"
    }
  }
}

provider "aws" {
  region = var.region
}


# VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  instance_tenancy     = "default"

  tags = {
    Name = "MinecraftVpc"
  }
}


# Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subnet_public_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true // Enables automatic IP allocation for the subnet. This makes the subnet PUBLIC
  tags = {
    Name = "MinecraftPublicSubnet"
  }
}


# Internet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "MinecraftInternetGateway"
  }
}


# Route Table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  # This configuration routes all the packets which have a destination address outside the VPC to the internet gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  tags = {
    Name = "MAIN"
  }
}

resource "aws_route_table_association" "public_route_table_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}


# Security group
resource "aws_security_group" "minecraft" {
  name        = "minecraft_security_group"
  vpc_id      = aws_vpc.vpc.id
  description = "Minecraft server traffic"

  # Allow Minecraft connections from anywhere
  ingress {
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH Protocol
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ec2_ssh_cidr]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "MinecraftSecurityGroup"
  }
}


# EC2
resource "aws_instance" "minecraft" {
  ami                         = var.minecraft_ami
  subnet_id                   = aws_subnet.public_subnet.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.minecraft.id]
  associate_public_ip_address = true
  key_name                    = "minecraft-ec2-ssh-key"
  user_data                   = file("mc_ec2_bootstrap.sh")
  tags = {
    Name = "MinecraftServer"
  }
}
