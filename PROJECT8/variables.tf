variable "environment" {
  description = "Deployment environment (dev | prod)"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be 'dev' or 'prod'."
  }
}

variable "project_name" {
  description = "Short project identifier used in resource naming"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

variable "subscription_id" {
  description = "Azure Subscription ID for the target environment"
  type        = string
  sensitive   = true
}
