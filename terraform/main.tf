###############################################
# main.tf — DevSecOps Infrastructure on AWS
###############################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────────
# 1. VPC
# ─────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "devsecops-vpc", Project = "devsecops" }
}

# ─────────────────────────────────────────────
# 2. Public Subnet
# ─────────────────────────────────────────────
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = { Name = "devsecops-public-subnet", Project = "devsecops" }
}

# ─────────────────────────────────────────────
# 3. Internet Gateway + Route Table
# ─────────────────────────────────────────────
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "devsecops-igw", Project = "devsecops" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "devsecops-public-rt", Project = "devsecops" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ─────────────────────────────────────────────
# 4. Security Groups (one per role — least privilege)
# ─────────────────────────────────────────────

# --- Jenkins SG ---
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Jenkins CI server"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  ingress {
    description = "Jenkins UI from my IP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]   # tighten in prod
  }
  # Node Exporter scraped by monitoring server only
  ingress {
    description     = "Node Exporter"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "jenkins-sg", Project = "devsecops" }
}

# --- Tools SG (SonarQube + Nexus) ---
resource "aws_security_group" "tools_sg" {
  name        = "tools-sg"
  description = "SonarQube + Nexus tools server"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  ingress {
    description     = "SonarQube from Jenkins"
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_sg.id]
    cidr_blocks     = [var.my_ip]
  }
  ingress {
    description     = "Nexus from Jenkins"
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_sg.id]
    cidr_blocks     = [var.my_ip]
  }
  ingress {
    description     = "Node Exporter"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "tools-sg", Project = "devsecops" }
}

# --- Monitoring SG ---
resource "aws_security_group" "monitoring_sg" {
  name        = "monitoring-sg"
  description = "Prometheus + Grafana monitoring"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  ingress {
    description = "Grafana from my IP"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  ingress {
    description = "Prometheus from my IP"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "monitoring-sg", Project = "devsecops" }
}

# --- Kubernetes nodes SG ---
resource "aws_security_group" "k8s_sg" {
  name        = "k8s-sg"
  description = "Kubernetes control-plane + workers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  # All intra-cluster traffic (kubeadm requirement)
  ingress {
    description = "Intra-cluster"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }
  # kubectl from my machine
  ingress {
    description = "K8s API server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  # Allow Jenkins to reach the API server
  ingress {
    description     = "K8s API from Jenkins"
    from_port       = 6443
    to_port         = 6443
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_sg.id]
  }
  # NodePort range
  ingress {
    description = "NodePort services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  ingress {
    description     = "Node Exporter"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "k8s-sg", Project = "devsecops" }
}

# ─────────────────────────────────────────────
# 5. Key Pair
# ─────────────────────────────────────────────
resource "aws_key_pair" "devsecops" {
  key_name   = "devsecops-key"
  public_key = file(var.public_key_path)
}

# ─────────────────────────────────────────────
# 6. Latest Ubuntu 22.04 LTS AMI (dynamic lookup)
# ─────────────────────────────────────────────
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ─────────────────────────────────────────────
# 7. EC2 — Jenkins Server (t3.medium, 30 GB)
# ─────────────────────────────────────────────
resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  key_name               = aws_key_pair.devsecops.key_name

  # Enforce IMDSv2 (security hardening)
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = { Name = "jenkins-server", Project = "devsecops", Role = "ci" }
}

# ─────────────────────────────────────────────
# 8. EC2 — Tools Server (SonarQube + Nexus) (t3.large, 30 GB)
# ─────────────────────────────────────────────
resource "aws_instance" "tools" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.large"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.tools_sg.id]
  key_name               = aws_key_pair.devsecops.key_name

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = { Name = "tools-server", Project = "devsecops", Role = "sonarqube-nexus" }
}

# ─────────────────────────────────────────────
# 9. EC2 — Monitoring Server (t3.small, 20 GB)
# ─────────────────────────────────────────────
resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]
  key_name               = aws_key_pair.devsecops.key_name

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = { Name = "monitoring-server", Project = "devsecops", Role = "monitoring" }
}

# ─────────────────────────────────────────────
# 10. EC2 — Kubernetes Control Plane (t3.medium, 20 GB)
# ─────────────────────────────────────────────
resource "aws_instance" "k8s_master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  key_name               = aws_key_pair.devsecops.key_name

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = { Name = "k8s-master", Project = "devsecops", Role = "k8s-control-plane" }
}

# ─────────────────────────────────────────────
# 11. EC2 — Kubernetes Workers (t3.medium, 20 GB) × var.k8s_worker_count
# ─────────────────────────────────────────────
resource "aws_instance" "k8s_worker" {
  count                  = var.k8s_worker_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  key_name               = aws_key_pair.devsecops.key_name

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name    = "k8s-worker-${count.index + 1}"
    Project = "devsecops"
    Role    = "k8s-worker"
  }
}


# ─────────────────────────────────────────────
# 12. Préparer le fichier d'inventaire pour Ansible
# ─────────────────────────────────────────────
resource "local_file" "ansible_inventory" {
  filename = "../ansible/inventory/hosts.ini"
  
  content = templatefile("./hosts.ini.tpl", {
    jenkins_ip     = aws_instance.jenkins.public_ip
    tools_ip       = aws_instance.tools.public_ip
    monitoring_ip  = aws_instance.monitoring.public_ip
    k8s_master_ip  = aws_instance.k8s_master.public_ip
    k8s_worker_ips = aws_instance.k8s_worker[*].public_ip
  })
}