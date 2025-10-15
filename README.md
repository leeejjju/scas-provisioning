# scas-provisioning

IaC codes for make k8s cluster on AWS EC2 using Terraform and Ansible. 

<br>


## 1. ssh keygen and AWS credential setting 
-> https://leeejjju.tistory.com/13 

<br>

## 2. Run Terraform to make EC2
```
cd terraform 

terraform init

terraform apply
```
the commands makes 1 master node and 2 worker node on your EC2 instances.

<br>

## 3. Run Ansible to provisioning EC2 
```
cd ../ansible

ansible -i inventory.ini all -m ping

ansible-playbook -i inventory.ini playbook.yaml
```
ths commands make EC2 instances to k8s cluster includes ArgoCD and MetalLB .



<br>
Good luck! 

<br>



---
any question: leeejjju@gmail.com 