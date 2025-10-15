
// # 1. Provider 설정
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

// # 2. SSH 키 등록
resource "aws_key_pair" "k8s_key" {
  key_name   = "k8s-key"
  public_key = file("~/.ssh/k8s-key.pub")
}

// # 3. 보안 그룹
resource "aws_security_group" "k8s_sg" {
  name        = "k8s-security-group"
  description = "Allow traffic for K8s cluster"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

// # 4. IAM Role (ECR 접근용)
resource "aws_iam_role" "node_role" {
  name = "k8s-node-ecr-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ecr_access" {
  name = "k8s-ecr-policy"
  role = aws_iam_role.node_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "node_profile" {
  name = "k8s-node-profile"
  role = aws_iam_role.node_role.name
}

// # 5. 마스터 노드
resource "aws_instance" "k8s-master" {
  ami           = "ami-0c9c942bd7bf113a2"
  instance_type = "t3.small"

  key_name         = aws_key_pair.k8s_key.key_name
  security_groups  = [aws_security_group.k8s_sg.name]
  iam_instance_profile = aws_iam_instance_profile.node_profile.name

  associate_public_ip_address = true  # ✅ 퍼블릭 IP 자동 연결

  tags = {
    Name = "k8s-master"
  }

  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname master
              EOF
}

// # 6. 워커 노드
resource "aws_instance" "k8s-worker" {
  count         = 2
  ami           = "ami-0c9c942bd7bf113a2"
  instance_type = "t3.small"

  key_name         = aws_key_pair.k8s_key.key_name
  security_groups  = [aws_security_group.k8s_sg.name]
  iam_instance_profile = aws_iam_instance_profile.node_profile.name

  associate_public_ip_address = true  # ✅ 퍼블릭 IP 자동 연결

  tags = {
    Name = "k8s-worker-${count.index + 1}"
  }

  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname worker${count.index + 1}
              EOF
}

// # 7. 출력
output "master_public_ip" {
  value = aws_instance.k8s-master.public_ip
}

output "worker_public_ips" {
  value = aws_instance.k8s-worker.*.public_ip
}

// # 8. Ansible 인벤토리 파일 생성
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    master_ip    = aws_instance.k8s-master.public_ip
    worker_ips   = aws_instance.k8s-worker.*.public_ip
    ssh_key_path = "~/.ssh/k8s-key"
  })
  filename = "${path.module}/../ansible/inventory.ini"
}
