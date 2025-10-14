
// # 1. Provider 설정 (AWS, 서울 리전)
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


// # 2. SSH 키 페어 리소스
// 1단계에서 만든 공개키(k8s-key.pub) 파일을 읽어서 AWS에 등록합니다.
// 이렇게 등록된 키를 EC2 인스턴스에 주입하여 접속을 허용합니다.
resource "aws_key_pair" "k8s_key" {
  key_name   = "k8s-key"
  public_key = file("~/.ssh/k8s-key.pub")
}

// # 3. 보안 그룹(Security Group) 리소스
// EC2 인스턴스의 가상 방화벽입니다. 어떤 트래픽을 허용할지 규칙을 정의합니다.
resource "aws_security_group" "k8s_sg" {
  name        = "k8s-security-group"
  description = "Allow traffic for K8s cluster"

  // ingress(인바운드) 규칙
  ingress {
    from_port   = 22 // SSH 접속 포트
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] // 모든 IP에서 SSH 접속 허용 (학습용)
  }

  ingress {
    from_port   = 0 // 모든 포트
    to_port     = 0
    protocol    = "-1" // 모든 프로토콜
    self        = true // 이 보안 그룹에 속한 인스턴스끼리는 모든 통신 허용 (매우 중요!)
  }

  // egress(아웃바운드) 규칙
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] // 외부로 나가는 모든 통신 허용
  }
}

// # 4. 마스터 노드 EC2 인스턴스
resource "aws_instance" "k8s-master" {
  ami           = "ami-0c9c942bd7bf113a2" // Ubuntu 22.04 LTS (서울 리전)
  instance_type = "t3.small"              // K8s 권장 최소 사양

  key_name      = aws_key_pair.k8s_key.key_name
  security_groups = [aws_security_group.k8s_sg.name]

  tags = {
    Name = "k8s-master"
  }

  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname master
              EOF
}

// # 5. 워커 노드 EC2 인스턴스 (2개)
// 'count = 2'를 사용하여 동일한 구성의 리소스를 2개 만듭니다.
resource "aws_instance" "k8s-worker" {
  count         = 2 // 이 리소스 블록을 2번 실행!

  ami           = "ami-0c9c942bd7bf113a2"
  instance_type = "t3.small"

  key_name      = aws_key_pair.k8s_key.key_name
  security_groups = [aws_security_group.k8s_sg.name]

  tags = {
    // count.index는 0부터 시작하므로 +1을 해줘서 k8s-worker-1, k8s-worker-2로 만듭니다.
    Name = "k8s-worker-${count.index + 1}"
  }

  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname worker${count.index + 1}
              EOF
}

// # 6. 출력(Output) 설정
// Terraform 실행이 끝난 후, 생성된 인스턴스들의 Public IP 주소를 화면에 출력해줍니다.
output "master_public_ip" {
  value = aws_instance.k8s-master.public_ip
}

output "worker_public_ips" {
  value = aws_instance.k8s-worker.*.public_ip
}


// # 7. Ansible 인벤토리 파일 생성
// local_file 리소스는 Terraform을 실행하는 로컬 머신에 파일을 생성합니다.
resource "local_file" "ansible_inventory" {
  // content는 파일의 내용을 의미합니다.
  // templatefile 함수는 템플릿 파일을 읽어서 변수를 채워넣은 후 결과 텍스트를 반환합니다.
  content = templatefile("${path.module}/inventory.tpl", {
    master_ip    = aws_instance.k8s-master.public_ip
    worker_ips   = aws_instance.k8s-worker.*.public_ip
    ssh_key_path = "~/.ssh/k8s-key"
  })

  // 로컬에 저장될 파일의 이름입니다.
  filename = "${path.module}/../ansible/inventory.ini"
}
