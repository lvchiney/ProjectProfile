data "azurerm_client_config" "current" {}

# ─────────────────────────────────────────
# Resource Group
# ─────────────────────────────────────────
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ─────────────────────────────────────────
# Key Vault
# ─────────────────────────────────────────
module "keyvault" {
  source              = "./modules/keyvault"
  keyvault_name       = var.keyvault_name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  environment         = var.environment
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = data.azurerm_client_config.current.object_id
  tags                = var.tags
}

# ─────────────────────────────────────────
# Storage Account (training data)
# ─────────────────────────────────────────
module "storage" {
  source               = "./modules/storage"
  storage_account_name = var.storage_account_name
  resource_group_name  = azurerm_resource_group.main.name
  location             = var.location
  environment          = var.environment
  tags                 = var.tags
}

# ─────────────────────────────────────────
# Azure Container Registry
# ─────────────────────────────────────────
module "container_registry" {
  source                  = "./modules/container_registry"
  container_registry_name = var.container_registry_name
  resource_group_name     = azurerm_resource_group.main.name
  location                = var.location
  environment             = var.environment
  tags                    = var.tags
}

# ─────────────────────────────────────────
# Azure ML Workspace
# ─────────────────────────────────────────
module "ml_workspace" {
  source                  = "./modules/ml_workspace"
  ml_workspace_name       = var.ml_workspace_name
  resource_group_name     = azurerm_resource_group.main.name
  location                = var.location
  environment             = var.environment
  storage_account_id      = module.storage.storage_account_id
  container_registry_id   = module.container_registry.container_registry_id
  keyvault_id             = module.keyvault.keyvault_id
  app_insights_id         = module.monitoring.app_insights_id
  tags                    = var.tags
}

# ─────────────────────────────────────────
# Monitoring (Log Analytics + App Insights)
# ─────────────────────────────────────────
module "monitoring" {
  source              = "./modules/monitoring"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  environment         = var.environment
  tags                = var.tags
}

# ─────────────────────────────────────────
# Event Grid — triggers pipeline on new data
# ─────────────────────────────────────────
resource "azurerm_eventgrid_event_subscription" "blob_trigger" {
  name  = "evgs-training-data-${var.environment}"
  scope = module.storage.storage_account_id

  webhook_endpoint {
    url = "https://dev.azure.com/YOUR_ORG/YOUR_PROJECT/_apis/hooks/externalEvents"
  }

  included_event_types = [
    "Microsoft.Storage.BlobCreated"
  ]

  subject_filter {
    subject_begins_with = "/blobServices/default/containers/training-data/"
  }
}
