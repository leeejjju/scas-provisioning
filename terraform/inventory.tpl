# Ansible 인벤토리 파일
# 이 파일은 Terraform에 의해 자동으로 생성됩니다.

[master]
master ansible_host=${master_ip}

[workers]
%{ for index, ip in worker_ips ~}
worker-${index} ansible_host=${ip}
%{ endfor ~}

[all:vars]
ansible_user=ubuntu
ansible_private_key_file=${ssh_key_path}
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
