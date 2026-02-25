provider "aws" {
  region = "us-east-1"
}

# ----------------------------
# IAM Role for EKS Cluster
# ----------------------------
resource "aws_iam_role" "master" {
  name = "hadeed-eks-master1"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.master.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.master.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.master.name
}

# ----------------------------
# IAM Role for Worker Nodes
# ----------------------------
resource "aws_iam_role" "worker" {
  name = "hadeed-eks-worker1"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "autoscaler" {
  name = "hadeed-eks-autoscaler-policy1"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeTags",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup",
        "ec2:DescribeLaunchTemplateVersions"
      ],
      Effect   = "Allow",
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.worker.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.worker.name
}

resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.worker.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.worker.name
}

resource "aws_iam_role_policy_attachment" "S3ReadOnlyAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  role       = aws_iam_role.worker.name
}

# 🔒 DAY 19: Secrets Manager Access for ESO
resource "aws_iam_policy" "secrets_manager_read" {
  name        = "hadeed-eks-secrets-read"
  description = "Allows EKS to read from Secrets Manager"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      Effect   = "Allow",
      Resource = "*" # In strict prod, limit to specific secret ARNs
    }]
  })
}

resource "aws_iam_role_policy_attachment" "secrets_manager_read" {
  policy_arn = aws_iam_policy.secrets_manager_read.arn
  role       = aws_iam_role.worker.name
}

resource "aws_iam_role_policy_attachment" "autoscaler" {
  policy_arn = aws_iam_policy.autoscaler.arn
  role       = aws_iam_role.worker.name
}

resource "aws_iam_instance_profile" "worker" {
  depends_on = [aws_iam_role.worker]
  name       = "hadeed-eks-worker-profile1"
  role       = aws_iam_role.worker.name
}

# ----------------------------
# VPC and Networking Resources
# ----------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name                                = "EKS-VPC"
    "kubernetes.io/cluster/project-eks" = "shared"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "EKS-IGW"
  }
}

# --- PUBLIC SUBNETS (The Lobby) ---
resource "aws_subnet" "public-1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name                                = "Public-Subnet-1"
    "kubernetes.io/cluster/project-eks" = "shared"
    "kubernetes.io/role/elb"            = "1" # Important for Public Load Balancers
  }
}

resource "aws_subnet" "public-2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name                                = "Public-Subnet-2"
    "kubernetes.io/cluster/project-eks" = "shared"
    "kubernetes.io/role/elb"            = "1"
  }
}

# --- PRIVATE SUBNETS (The Vault) ---
resource "aws_subnet" "private-1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false # No Public IPs!

  tags = {
    Name                                = "Private-Subnet-1"
    "kubernetes.io/cluster/project-eks" = "shared"
    "kubernetes.io/role/internal-elb"   = "1" # Important for Private Load Balancers
  }
}

resource "aws_subnet" "private-2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name                                = "Private-Subnet-2"
    "kubernetes.io/cluster/project-eks" = "shared"
    "kubernetes.io/role/internal-elb"   = "1"
  }
}

# --- NAT GATEWAYS (The Security Guards - Multi-AZ HA) ---

# NAT Gateway 1 (AZ-1)
resource "aws_eip" "nat1" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat1" {
  allocation_id = aws_eip.nat1.id
  subnet_id     = aws_subnet.public-1.id

  tags = {
    Name = "EKS-NAT-Gateway-1"
  }

  depends_on = [aws_internet_gateway.igw]
}

# NAT Gateway 2 (AZ-2 - God Level Redundancy)
resource "aws_eip" "nat2" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat2" {
  allocation_id = aws_eip.nat2.id
  subnet_id     = aws_subnet.public-2.id

  tags = {
    Name = "EKS-NAT-Gateway-2"
  }

  depends_on = [aws_internet_gateway.igw]
}

# --- ROUTE TABLES (The Maps) ---

# Public Map: Go to IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public-RT"
  }
}

# Private Map 1 (AZ-1): Uses NAT 1
resource "aws_route_table" "private1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat1.id
  }

  tags = {
    Name = "Private-RT-1"
  }
}

# Private Map 2 (AZ-2): Uses NAT 2
resource "aws_route_table" "private2" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat2.id
  }

  tags = {
    Name = "Private-RT-2"
  }
}

# --- ASSOCIATIONS ---

resource "aws_route_table_association" "public-1" {
  subnet_id      = aws_subnet.public-1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public-2" {
  subnet_id      = aws_subnet.public-2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private-1" {
  subnet_id      = aws_subnet.private-1.id
  route_table_id = aws_route_table.private1.id
}

resource "aws_route_table_association" "private-2" {
  subnet_id      = aws_subnet.private-2.id
  route_table_id = aws_route_table.private2.id
}

resource "aws_security_group" "eks_sg" {
  name        = "eks-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.main.id

  # SSH Access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP Access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS Access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all internal traffic within the VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "EKS-SG"
  }
}

# ----------------------------
# 📺 DAY 21: CloudWatch Log Group for EKS Audit Logs
# ----------------------------
# AWS automatically sends EKS logs to this exact path.
# By defining it here in Terraform:
# 1. We control the retention period (90 days = compliance requirement)
# 2. We can add tags for cost tracking
# 3. Terraform manages it - it won't be orphaned if cluster is destroyed
resource "aws_cloudwatch_log_group" "eks_audit_logs" {
  name              = "/aws/eks/project-eks/cluster"
  retention_in_days = 90  # Keep logs for 90 days (PCI-DSS requirement)

  tags = {
    Name        = "eks-audit-logs"
    Environment = "dev"
    Purpose     = "security-compliance"
  }
}

# ----------------------------
# EKS Cluster (The Brain)
# ----------------------------
resource "aws_eks_cluster" "eks" {
  name     = "project-eks"
  role_arn = aws_iam_role.master.arn

  # 🔒 DAY 21: Enable EKS Control Plane Audit Logging
  # Logs stream to CloudWatch Log Group: /aws/eks/project-eks/cluster
  enabled_cluster_log_types = [
    "api",           # Every kubectl API call (reads, writes)
    "audit",         # Security decisions - WHO accessed WHAT secret/pod
    "authenticator"  # Every login attempt to the cluster
  ]

  vpc_config {
    # Connected to ALL subnets (Public & Private)
    subnet_ids         = [aws_subnet.public-1.id, aws_subnet.public-2.id, aws_subnet.private-1.id, aws_subnet.private-2.id]
    security_group_ids = [aws_security_group.eks_sg.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  tags = {
    Name        = "hadeed-eks-cluster"
    Environment = "dev"
    Terraform   = "true"
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEKSServicePolicy,
    aws_iam_role_policy_attachment.AmazonEKSVPCResourceController,
    aws_cloudwatch_log_group.eks_audit_logs,  # Log group must exist first!
  ]
}


# ----------------------------
# EKS Node Group (The Workers)
# ----------------------------
resource "aws_eks_node_group" "node-grp" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.worker.arn
  
  # GOD LEVEL: Nodes deployed in PRIVATE Subnets
  subnet_ids      = [aws_subnet.private-1.id, aws_subnet.private-2.id]
  
  capacity_type   = "ON_DEMAND"
  disk_size       = 20
  instance_types  = ["c7i-flex.large"]

  labels = {
    env = "dev"
  }

  tags = {
    Name = "project-eks-node-group"
  }

  scaling_config {
    desired_size = 3
    max_size     = 10
    min_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.AmazonSSMManagedInstanceCore,
    aws_iam_role_policy_attachment.autoscaler,
  ]
}

# ----------------------------
# OIDC Provider for ServiceAccount IAM Roles
# ----------------------------
data "aws_eks_cluster" "eks_oidc" {
  name = aws_eks_cluster.eks.name
}

data "tls_certificate" "oidc_thumbprint" {
  url = data.aws_eks_cluster.eks_oidc.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc_thumbprint.certificates[0].sha1_fingerprint]
  url             = data.aws_eks_cluster.eks_oidc.identity[0].oidc[0].issuer
}
# ----------------------------
# ArgoCD Installation (Automatic God Level Setup)
# ----------------------------

# 1. Fetch Auth Token from AWS for EKS
data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.eks.name
}

# 2. Configure Helm Provider to talk to your new Cluster
provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# 3. Install ArgoCD via Helm
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  create_namespace = true
  version    = "5.46.7" # Stable Version

  # This gives you a Public URL to access the ArgoCD UI!
  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  # Disables HTTPS for easier initial learning (can be enabled with certificates later)
  set {
    name  = "server.extraArgs"
    value = "{--insecure}"
  }

  depends_on = [aws_eks_node_group.node-grp]
}

# Output the ArgoCD URL so you know where to go!
output "argocd_loadbalancer_url" {
  value = "Wait for LB to provision, then check AWS Console or kubectl get svc -n argocd"
}

# ----------------------------
# Argo Rollouts Installation (The Canary Engine)
# ----------------------------
resource "helm_release" "argo_rollouts" {
  name       = "argo-rollouts"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-rollouts"
  namespace  = "argo-rollouts"
  create_namespace = true
  version    = "2.32.0" # Stable Version

  # Enable the Dashboard for visualization
  set {
    name  = "dashboard.enabled"
    value = "true"
  }

  depends_on = [aws_eks_node_group.node-grp]
}

# ----------------------------
# External Secrets Operator (The Secret Bridge)
# ----------------------------
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = "external-secrets"
  create_namespace = true
  version    = "0.9.11" # Stable Version

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [aws_eks_node_group.node-grp]
}

# ----------------------------
# 🛡️ DAY 20: AWS WAF (Web Application Firewall)
# ----------------------------
resource "aws_wafv2_web_acl" "main" {
  name        = "bankapp-waf"
  description = "Protect EKS from SQLi, XSS, and common exploits"
  scope       = "REGIONAL" # Required for ALBs in EKS

  default_action {
    allow {}
  }

  # Rule 1: AWS Managed - Common Rule Set (OWASP Top 10)
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "bankapp-waf-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: SQL Injection Protection
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "bankapp-waf-sqli-rules"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "bankapp-waf-main"
    sampled_requests_enabled   = true
  }
}

output "waf_web_acl_arn" {
  value = aws_wafv2_web_acl.main.arn
}
