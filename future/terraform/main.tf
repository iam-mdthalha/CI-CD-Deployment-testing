# =============================================================================
# Terraform Configuration for E-Commerce Frontend
# =============================================================================
#
# ⚠️  THIS IS A TEMPLATE FILE - NOT ACTIVE
# ⚠️  Copy to main.tf and customize before use
#
# =============================================================================

# -----------------------------------------------------------------------------
# UNCOMMENT BELOW WHEN READY TO USE
# -----------------------------------------------------------------------------

# terraform {
#   required_version = ">= 1.0. 0"
#
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 5.0"
#     }
#   }
#
#   # Remote state (recommended for team use)
#   # backend "s3" {
#   #   bucket = "your-terraform-state-bucket"
#   #   key    = "ecommerce-frontend/terraform.tfstate"
#   #   region = "us-east-1"
#   # }
# }

# provider "aws" {
#   region = var. aws_region
#
#   default_tags {
#     tags = {
#       Project     = "ecommerce-frontend"
#       Environment = var.environment
#       ManagedBy   = "terraform"
#     }
#   }
# }

# -----------------------------------------------------------------------------
# VPC (Optional - use default VPC for simplicity)
# -----------------------------------------------------------------------------

# data "aws_vpc" "default" {
#   default = true
# }

# data "aws_subnets" "default" {
#   filter {
#     name   = "vpc-id"
#     values = [data. aws_vpc.default.id]
#   }
# }

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------

# resource "aws_security_group" "ecommerce" {
#   name        = "ecommerce-frontend-sg"
#   description = "Security group for E-Commerce Frontend"
#   vpc_id      = data.aws_vpc.default.id
#
#   # HTTP
#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   # HTTPS
#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   # Outbound
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   tags = {
#     Name = "ecommerce-frontend-sg"
#   }
# }

# -----------------------------------------------------------------------------
# IAM Role for EC2 (SSM Access)
# -----------------------------------------------------------------------------

# resource "aws_iam_role" "ec2_ssm" {
#   name = "ecommerce-ec2-ssm-role"
#
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         }
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "ssm" {
#   role       = aws_iam_role.ec2_ssm. name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }

# resource "aws_iam_instance_profile" "ec2" {
#   name = "ecommerce-ec2-profile"
#   role = aws_iam_role.ec2_ssm. name
# }

# -----------------------------------------------------------------------------
# EC2 Instance
# -----------------------------------------------------------------------------

# data "aws_ami" "ubuntu" {
#   most_recent = true
#   owners      = ["099720109477"] # Canonical
#
#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
#   }
# }

# resource "aws_instance" "ecommerce" {
#   ami                    = data.aws_ami.ubuntu. id
#   instance_type          = var.instance_type
#   key_name               = var.key_name
#   vpc_security_group_ids = [aws_security_group.ecommerce.id]
#   iam_instance_profile   = aws_iam_instance_profile. ec2.name
#
#   root_block_device {
#     volume_size = 20
#     volume_type = "gp3"
#   }
#
#   user_data = <<-EOF
#               #!/bin/bash
#               apt-get update
#               apt-get install -y docker.io nginx
#               systemctl enable docker
#               systemctl start docker
#               usermod -aG docker ubuntu
#               EOF
#
#   tags = {
#     Name = "ecommerce-frontend-${var.environment}"
#   }
# }

# -----------------------------------------------------------------------------
# Elastic IP (Optional)
# -----------------------------------------------------------------------------

# resource "aws_eip" "ecommerce" {
#   instance = aws_instance. ecommerce.id
#   domain   = "vpc"
#
#   tags = {
#     Name = "ecommerce-frontend-eip"
#   }
# }
