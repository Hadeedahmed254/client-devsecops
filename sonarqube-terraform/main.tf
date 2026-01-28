terraform {
  backend "s3" {}
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "sonar_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "sonar-vpc" }
}

resource "aws_internet_gateway" "sonar_igw" {
  vpc_id = aws_vpc.sonar_vpc.id
  tags = { Name = "sonar-igw" }
}

resource "aws_subnet" "sonar_subnet" {
  vpc_id                  = aws_vpc.sonar_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = { Name = "sonar-subnet" }
}

resource "aws_route_table" "sonar_rt" {
  vpc_id = aws_vpc.sonar_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sonar_igw.id
  }
}

resource "aws_route_table_association" "sonar_rta" {
  subnet_id      = aws_subnet.sonar_subnet.id
  route_table_id = aws_route_table.sonar_rt.id
}

resource "aws_security_group" "sonar_sg" {
  name        = "sonar-sg"
  description = "Allow SonarQube and SSH"
  vpc_id      = aws_vpc.sonar_vpc.id

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "sonar_server" {
  ami           = "ami-0b6c6ebed2801a5cb" 
  instance_type = "c7i-flex.large"
  subnet_id     = aws_subnet.sonar_subnet.id
  vpc_security_group_ids = [aws_security_group.sonar_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y docker.io
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -aG docker ubuntu
              sudo chmod 666 /var/run/docker.sock
              
              # SonarQube requirement for ElasticSearch
              sudo sysctl -w vm.max_map_count=262144
              echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
              
              sudo docker run -d --name sonarqube -p 9000:9000 sonarqube:lts-community
              EOF

  tags = {
    Name = "SonarQube-Server"
  }
}

output "sonarqube_url" {
  value = "http://${aws_instance.sonar_server.public_ip}:9000"
}
