terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # Remote State — Azure Blob Storage
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    # key is passed dynamically per environment:
    # env/dev/main.tfstate  OR  env/prod/main.tfstate
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  # Service Connection credentials are injected by Azure DevOps
  # via environment variables: ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID
}

# ── Resource Group ─────────────────────────────────────────────
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.environment}-${var.project_name}"
  location = var.location

  tags = local.common_tags
}

locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}
