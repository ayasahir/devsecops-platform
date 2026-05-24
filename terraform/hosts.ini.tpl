# hosts.ini.tpl

[jenkins]
jenkins-server ansible_host=${jenkins_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/devsecops-key

[tools]
tools-server ansible_host=${tools_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/devsecops-key

[monitoring]
monitoring-server ansible_host=${monitoring_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/devsecops-key

[k8s_master]
k8s-master ansible_host=${k8s_master_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/devsecops-key

[k8s_workers]
%{ for index, ip in k8s_worker_ips ~}
k8s-worker-${index + 1} ansible_host=${ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/devsecops-key
%{ endfor ~}

[k8s:children]
k8s_master
k8s_workers

[all:vars]
ansible_python_interpreter=/usr/bin/python3