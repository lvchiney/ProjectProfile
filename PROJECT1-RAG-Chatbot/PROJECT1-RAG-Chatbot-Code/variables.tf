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

variable "openai_sku" {
  description = "SKU for Azure OpenAI"
  type        = string
  default     = "S0"
}

variable "search_sku" {
  description = "SKU for Azure AI Search"
  type        = string
  default     = "standard"
}

variable "app_service_sku" {
  description = "SKU for Azure App Service Plan"
  type        = string
  default     = "B2"
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
