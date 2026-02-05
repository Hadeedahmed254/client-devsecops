
resource "aws_security_group" "grafana_sg" {
  name        = "grafana-security-dashboard-sg"
  description = "Allow Grafana traffic"

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # In a real production, restrict this to your IP
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

resource "aws_iam_role" "grafana_role" {
  name = "grafana-athena-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach policies so Grafana can query Athena and read S3
resource "aws_iam_role_policy_attachment" "athena_access" {
  role       = aws_iam_role.grafana_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonAthenaFullAccess"
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.grafana_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "grafana_profile" {
  name = "grafana-instance-profile"
  role = aws_iam_role.grafana_role.name
}

# Using SonarQube's AMI for consistency

resource "aws_instance" "grafana_server" {
  ami           = "ami-0b6c6ebed2801a5cb" 
  instance_type = "c7i-flex.large" # Matching SonarQube exactly
  
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }
  
  vpc_security_group_ids = [aws_security_group.grafana_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.grafana_profile.name
  key_name               = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y docker.io
              sudo systemctl start docker
              sudo systemctl enable docker
              
              # Run Grafana with Athena plugin pre-installed
              docker run -d \
                -p 3000:3000 \
                --name=grafana \
                -e "GF_INSTALL_PLUGINS=grafana-athena-datasource" \
                grafana/grafana:latest
              EOF

  tags = {
    Name = "Security-Dashboard-Grafana"
    Project = "DevSecOps-Demo"
  }
}

output "grafana_url" {
  value = "http://${aws_instance.grafana_server.public_ip}:3000"
}
