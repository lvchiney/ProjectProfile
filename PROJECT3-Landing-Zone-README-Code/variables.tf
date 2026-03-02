variable "location" {
  description = "Primary Azure region for platform resources"
  type        = string
  default     = "eastus"
}

variable "secondary_location" {
  description = "Secondary Azure region for DR resources"
  type        = string
  default     = "westus2"
}

variable "allowed_regions" {
  description = "List of Azure regions where resources are allowed"
  type        = list(string)
  default     = ["eastus", "westeurope"]
}

variable "root_management_group_id" {
  description = "Root management group ID (your Azure AD tenant ID)"
  type        = string
}

variable "prod_subscription_id" {
  description = "Production subscription ID"
  type        = string
}

variable "nonprod_subscription_id" {
  description = "Non-production subscription ID"
  type        = string
}

variable "connectivity_subscription_id" {
  description = "Connectivity subscription ID (Hub VNet, Firewall)"
  type        = string
}

variable "management_subscription_id" {
  description = "Management subscription ID (Log Analytics, Security)"
  type        = string
}

variable "security_team_object_id" {
  description = "Azure AD object ID for the security team group"
  type        = string
}

variable "platform_team_object_id" {
  description = "Azure AD object ID for platform/ops team group"
  type        = string
}

variable "dev_team_object_id" {
  description = "Azure AD object ID for developer team group"
  type        = string
}

variable "hub_vnet_address_space" {
  description = "Address space for hub VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "prod_spoke_address_space" {
  description = "Address space for production spoke VNet"
  type        = string
  default     = "10.1.0.0/16"
}

variable "nonprod_spoke_address_space" {
  description = "Address space for non-production spoke VNet"
  type        = string
  default     = "10.2.0.0/16"
}

variable "budget_amount" {
  description = "Monthly budget alert threshold in USD"
  type        = number
  default     = 1000
}

variable "alert_email" {
  description = "Email address for budget and policy alerts"
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
