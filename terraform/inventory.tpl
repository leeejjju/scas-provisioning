# Ansible 인벤토리 파일
# 이 파일은 Terraform에 의해 자동으로 생성됩니다.

[master]
# 마스터 노드의 Public IP가 여기에 들어갑니다.
${master_ip}

[workers]
# 워커 노드들의 Public IP 목록이 여기에 들어갑니다.
%{ for ip in worker_ips ~}
${ip}
%{ endfor ~}

[all:vars]
# 모든 호스트에 공통으로 적용될 변수들입니다.
ansible_user=ubuntu
ansible_private_key_file=${ssh_key_path}
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
