provider "aws" {
  region = "us-east-1"
}

# 1. Fetch Existing VPC & Subnets created by EKS-Terraform
data "aws_vpc" "eks_vpc" {
  filter {
    name   = "tag:Name"
    values = ["EKS-VPC"]
  }
}

data "aws_subnets" "private_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.eks_vpc.id]
  }
  filter {
    name   = "tag:kubernetes.io/role/internal-elb"
    values = ["1"]
  }
}

data "aws_security_group" "eks_sg" {
  filter {
    name   = "tag:Name"
    values = ["EKS-SG"]
  }
}

# 2. RDS Subnet Group (Required for RDS in a VPC)
resource "aws_db_subnet_group" "bankapp_db_group" {
  name       = "bankapp-db-subnet-group"
  subnet_ids = data.aws_subnets.private_subnets.ids

  tags = {
    Name = "BankApp-DB-Subnet-Group"
  }
}

# 3. Security Group for RDS (Locked to EKS Cluster)
resource "aws_security_group" "rds_sg" {
  name        = "bankapp-rds-sg"
  description = "Allows EKS Worker Nodes to connect to MySQL"
  vpc_id      = data.aws_vpc.eks_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [data.aws_security_group.eks_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "BankApp-RDS-SG"
  }
}

# 4. RDS Instance (GOD LEVEL - FREE TIER EDITION)
resource "aws_db_instance" "bankapp_db" {
  allocated_storage      = 20
  db_name                = "bankapp"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro" # FREE TIER
  username               = "admin"
  password               = "BankAppPassword2024" # Should be in Secrets Manager later!
  parameter_group_name   = "default.mysql8.0"
  db_subnet_group_name   = aws_db_subnet_group.bankapp_db_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  # GOD LEVEL SETTINGS FOR FREE TIER
  publicly_accessible    = false
  skip_final_snapshot    = true # Careful for real prod, but good for learning/destroying
  multi_az               = false # PROTECTING YOUR WALLET 🆓
  storage_type           = "gp2"
  
  tags = {
    Name = "BankApp-RDS-MySQL"
  }
}

# Outputs for our App Config
output "rds_endpoint" {
  value = aws_db_instance.bankapp_db.endpoint
}
