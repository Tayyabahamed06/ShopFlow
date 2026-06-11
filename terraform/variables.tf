variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for tagging"
  type        = string
  default     = "shopflow"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
}
