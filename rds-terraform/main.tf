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

# 4. Generate a Random Secure Password (NEVER IN GIT)
resource "random_password" "db_pass" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# 5. AWS Secrets Manager (The Vault)
resource "aws_secretsmanager_secret" "db_password" {
  name        = "bankapp/db/password-v2" # Changed name to avoid conflict
  description = "RDS Password for BankApp"
  recovery_window_in_days = 0 
}

resource "aws_secretsmanager_secret_version" "db_password_val" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.db_pass.result # 👈 USES THE RANDOM PASS
    engine   = "mysql"
    host     = aws_db_instance.bankapp_db.address
  })
}

# 6. RDS Instance (GOD LEVEL - SECURE EDITION)
resource "aws_db_instance" "bankapp_db" {
  allocated_storage      = 20
  db_name                = "bankapp"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro" 
  username               = "admin"
  password               = random_password.db_pass.result # 👈 USES THE RANDOM PASS
  parameter_group_name   = "default.mysql8.0"
  db_subnet_group_name   = aws_db_subnet_group.bankapp_db_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  publicly_accessible    = false
  skip_final_snapshot    = true 
  multi_az               = false 
  storage_type           = "gp2"
  
  tags = {
    Name = "BankApp-RDS-MySQL"
  }
}

# Outputs for our App Config
output "rds_endpoint" {
  value = aws_db_instance.bankapp_db.endpoint
}

output "secret_arn" {
  value = aws_secretsmanager_secret.db_password.arn
}
