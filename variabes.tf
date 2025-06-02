variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (e.g., dev, prod)"
  type        = string
}

variable "sops_user_arn" {
  description = "ARN of the IAM user for SOPS decryption"
  type        = string
  default     = "arn:aws:iam::764678966183:user/github-actions-user"
}
