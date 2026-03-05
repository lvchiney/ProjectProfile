
# ============================================================
# Enterprise Azure Policy Framework
# Scope: Management Group Level (Multi-Subscription)
# Author: Enterprise DevSecOps | KPMG
# ============================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate001"
    container_name       = "tfstate"
    key                  = "enterprise/policies.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# ============================================================
# DATA SOURCES — Management Groups
# ============================================================

data "azurerm_management_group" "root" {
  name = var.root_management_group_name
}

data "azurerm_management_group" "landing_zones" {
  name = var.landing_zones_management_group_name
}

data "azurerm_management_group" "platform" {
  name = var.platform_management_group_name
}

# ============================================================
# MODULE CALLS — All Policy Categories
# ============================================================

module "network_policies" {
  source              = "./modules/network"
  management_group_id = data.azurerm_management_group.landing_zones.id
  tags                = var.tags
}

module "identity_policies" {
  source              = "./modules/identity"
  management_group_id = data.azurerm_management_group.root.id
  tags                = var.tags
}

module "data_protection_policies" {
  source              = "./modules/data-protection"
  management_group_id = data.azurerm_management_group.landing_zones.id
  tags                = var.tags
}

module "container_policies" {
  source              = "./modules/containers"
  management_group_id = data.azurerm_management_group.landing_zones.id
  tags                = var.tags
}

module "monitoring_policies" {
  source                     = "./modules/monitoring"
  management_group_id        = data.azurerm_management_group.root.id
  log_analytics_workspace_id = var.log_analytics_workspace_id
  tags                       = var.tags
}

module "cost_governance_policies" {
  source              = "./modules/cost-governance"
  management_group_id = data.azurerm_management_group.root.id
  allowed_vm_skus     = var.allowed_vm_skus
  allowed_locations   = var.allowed_locations
  mandatory_tags      = var.mandatory_tags
  tags                = var.tags
}

# ============================================================
# ENTERPRISE INITIATIVE — Master Security Baseline
# ============================================================

resource "azurerm_policy_set_definition" "enterprise_security_baseline" {
  name         = "enterprise-security-baseline"
  policy_type  = "Custom"
  display_name = "Enterprise Security Baseline Initiative"
  description  = "Comprehensive security baseline for all enterprise landing zones"

  metadata = jsonencode({
    category = "Enterprise Security"
    version  = "1.0.0"
  })

  # Network policies
  policy_definition_reference {
    policy_definition_id = module.network_policies.deny_public_ip_policy_id
    reference_id         = "deny-public-ip"
  }

  policy_definition_reference {
    policy_definition_id = module.network_policies.require_nsg_policy_id
    reference_id         = "require-nsg"
  }

  # Data protection policies
  policy_definition_reference {
    policy_definition_id = module.data_protection_policies.deny_http_policy_id
    reference_id         = "deny-http"
  }

  policy_definition_reference {
    policy_definition_id = module.data_protection_policies.require_encryption_policy_id
    reference_id         = "require-encryption"
  }

  # Monitoring policies
  policy_definition_reference {
    policy_definition_id = module.monitoring_policies.deploy_defender_policy_id
    reference_id         = "deploy-defender"
  }

  # Cost governance
  policy_definition_reference {
    policy_definition_id = module.cost_governance_policies.require_tags_policy_id
    reference_id         = "require-tags"
  }
}

# Assign master initiative to Root MG
resource "azurerm_management_group_policy_assignment" "enterprise_security_baseline" {
  name                 = "enterprise-sec-baseline"
  display_name         = "Enterprise Security Baseline"
  management_group_id  = data.azurerm_management_group.root.id
  policy_definition_id = azurerm_policy_set_definition.enterprise_security_baseline.id

  identity {
    type = "SystemAssigned"
  }

  location = var.location
}
