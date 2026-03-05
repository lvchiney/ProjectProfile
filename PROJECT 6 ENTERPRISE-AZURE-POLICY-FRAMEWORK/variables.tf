
# ============================================================
# Enterprise Azure Policy Framework — Variables
# ============================================================

variable "root_management_group_name" {
  description = "Name of the Root Management Group"
  type        = string
  default     = "enterprise-root"
}

variable "landing_zones_management_group_name" {
  description = "Name of the Landing Zones Management Group"
  type        = string
  default     = "enterprise-landing-zones"
}

variable "platform_management_group_name" {
  description = "Name of the Platform Management Group"
  type        = string
  default     = "enterprise-platform"
}

variable "location" {
  description = "Azure region for policy assignments"
  type        = string
  default     = "uksouth"
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of the central Log Analytics Workspace"
  type        = string
}

variable "allowed_vm_skus" {
  description = "List of allowed VM SKUs across enterprise"
  type        = list(string)
  default = [
    "Standard_D2s_v5",
    "Standard_D4s_v5",
    "Standard_D8s_v5",
    "Standard_D16s_v5",
    "Standard_E2s_v5",
    "Standard_E4s_v5",
    "Standard_F2s_v2",
    "Standard_F4s_v2"
  ]
}

variable "allowed_locations" {
  description = "List of allowed Azure regions for resource deployment"
  type        = list(string)
  default     = ["uksouth", "ukwest", "northeurope", "westeurope"]
}

variable "mandatory_tags" {
  description = "List of mandatory tags required on all resources"
  type        = list(string)
  default     = ["Environment", "CostCenter", "Owner", "Application", "Criticality"]
}

variable "tags" {
  description = "Tags to apply to policy resources"
  type        = map(string)
  default = {
    ManagedBy   = "Terraform"
    Framework   = "Enterprise-DevSecOps"
    Environment = "platform"
  }
}
