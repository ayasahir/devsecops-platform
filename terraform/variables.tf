###############################################
# variables.tf
###############################################

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-3"
}

variable "my_ip" {
  description = "Your public IP in CIDR notation for SSH/UI access (e.g. 1.2.3.4/32)"
  type        = string
  # No default — never leave this open
}

variable "public_key_path" {
  description = "Path to your local SSH public key"
  type        = string
  default     = "~/.ssh/devsecops-key.pub"
}

variable "k8s_worker_count" {
  description = "Number of Kubernetes worker nodes"
  type        = number
  default     = 2
}
