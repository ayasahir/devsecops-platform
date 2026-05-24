###############################################
# outputs.tf
###############################################

output "jenkins_public_ip"    { value = aws_instance.jenkins.public_ip }
output "tools_public_ip"      { value = aws_instance.tools.public_ip }
output "monitoring_public_ip" { value = aws_instance.monitoring.public_ip }
output "k8s_master_public_ip" { value = aws_instance.k8s_master.public_ip }
output "k8s_worker_public_ips" {
  value = aws_instance.k8s_worker[*].public_ip
}

output "jenkins_url"    { value = "http://${aws_instance.jenkins.public_ip}:8080" }
output "sonarqube_url"  { value = "http://${aws_instance.tools.public_ip}:9000" }
output "nexus_url"      { value = "http://${aws_instance.tools.public_ip}:8081" }
output "grafana_url"    { value = "http://${aws_instance.monitoring.public_ip}:3000" }
output "prometheus_url" { value = "http://${aws_instance.monitoring.public_ip}:9090" }

output "ssh_jenkins"    { value = "ssh -i ~/.ssh/devsecops-key ubuntu@${aws_instance.jenkins.public_ip}" }
output "ssh_tools"      { value = "ssh -i ~/.ssh/devsecops-key ubuntu@${aws_instance.tools.public_ip}" }
output "ssh_monitoring" { value = "ssh -i ~/.ssh/devsecops-key ubuntu@${aws_instance.monitoring.public_ip}" }
output "ssh_k8s_master" { value = "ssh -i ~/.ssh/devsecops-key ubuntu@${aws_instance.k8s_master.public_ip}" }

output "vpc_id"             { value = aws_vpc.main.id }
output "public_subnet_id"   { value = aws_subnet.public.id }
