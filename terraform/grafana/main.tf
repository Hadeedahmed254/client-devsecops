
# Link directly to the SonarQube VPC and Subnet
data "aws_vpc" "sonar_vpc" {
  filter {
    name   = "tag:Name"
    values = ["sonar-vpc"]
  }
}

data "aws_subnet" "sonar_subnet" {
  filter {
    name   = "tag:Name"
    values = ["sonar-subnet"]
  }
}

resource "aws_security_group" "grafana_sg" {
  name        = "grafana-security-dashboard-sg"
  description = "Allow Grafana traffic"
  vpc_id      = data.aws_vpc.sonar_vpc.id

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
  subnet_id     = data.aws_subnet.sonar_subnet.id
  
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
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              echo "🚀 Starting Grafana Setup..."
              
              sudo apt-get update
              sudo apt-get install -y docker.io
              sudo systemctl start docker
              sudo systemctl enable docker
              
              # Create provisioning directories
              mkdir -p /home/ubuntu/grafana/provisioning/datasources
              mkdir -p /home/ubuntu/grafana/provisioning/dashboards
              mkdir -p /home/ubuntu/grafana/dashboards

              # 1. Provision Athena Data Source
              cat > /home/ubuntu/grafana/provisioning/datasources/athena.yaml <<DS_EOF
              apiVersion: 1
              datasources:
                - name: Amazon Athena
                  type: grafana-athena-datasource
                  access: proxy
                  jsonData:
                    authType: ec2_iam_role
                    defaultRegion: us-east-1
                    catalog: AwsDataCatalog
                    database: security_analytics
                    workgroup: primary
              DS_EOF

              # 2. Provision Dashboard Config
              cat > /home/ubuntu/grafana/provisioning/dashboards/dashboards.yaml <<DB_EOF
              apiVersion: 1
              providers:
                - name: 'SecurityDashboards'
                  orgId: 1
                  folder: ''
                  type: file
                  disableDeletion: false
                  editable: true
                  options:
                    path: /etc/grafana/dashboards
              DB_EOF

              # 3. Create the Actual Dashboard JSON
              cat > /home/ubuntu/grafana/dashboards/security_trends.json <<JSON_EOF
              {
                "annotations": { "list": [] },
                "editable": true,
                "panels": [
                  {
                    "title": "Vulnerability Trends (30 Days)",
                    "type": "timeseries",
                    "gridPos": { "h": 12, "w": 24, "x": 0, "y": 0 },
                    "targets": [
                      {
                        "datasource": { "type": "grafana-athena-datasource", "uid": "Amazon Athena" },
                        "format": "time_series",
                        "rawSql": "SELECT CAST(CONCAT(year, '-', month, '-', day) AS TIMESTAMP) as time, COUNT(*) as value FROM security_analytics.trivy_scans GROUP BY year, month, day ORDER BY time",
                        "refId": "A"
                      }
                    ]
                  }
                ],
                "schemaVersion": 36,
                "style": "dark",
                "time": { "from": "now-30d", "to": "now" },
                "title": "Security Intelligence Dashboard"
              }
              JSON_EOF

              # Fix permissions for the Grafana container user (ID 472)
              chmod -R 777 /home/ubuntu/grafana
              chown -R 472:472 /home/ubuntu/grafana

              echo "🐳 Starting Grafana Container..."
              docker run -d \
                -p 3000:3000 \
                --name=grafana \
                --restart always \
                -v /home/ubuntu/grafana/provisioning:/etc/grafana/provisioning \
                -v /home/ubuntu/grafana/dashboards:/etc/grafana/dashboards \
                -e "GF_INSTALL_PLUGINS=grafana-athena-datasource" \
                -e "GF_AUTH_ANONYMOUS_ENABLED=true" \
                -e "GF_AUTH_ANONYMOUS_ORG_ROLE=Admin" \
                grafana/grafana:latest

              echo "✅ Setup Script Finished."
              EOF

  tags = {
    Name = "Security-Dashboard-Grafana"
    Project = "DevSecOps-Demo"
  }
}

output "grafana_url" {
  value = "http://${aws_instance.grafana_server.public_ip}:3000"
}
