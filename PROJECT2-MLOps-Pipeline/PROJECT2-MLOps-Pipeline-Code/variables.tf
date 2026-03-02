variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "ml_workspace_name" {
  description = "Azure ML workspace name"
  type        = string
}

variable "accuracy_threshold" {
  description = "Minimum model accuracy required to deploy (0.0 to 1.0)"
  type        = number
  default     = 0.85
}

variable "storage_account_name" {
  description = "Name of storage account for training data"
  type        = string
}

variable "container_registry_name" {
  description = "Name of Azure Container Registry for model images"
  type        = string
}

variable "keyvault_name" {
  description = "Name of the Key Vault"
  type        = string
}

variable "app_service_sku" {
  description = "SKU for Angular dashboard App Service"
  type        = string
  default     = "B1"
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
