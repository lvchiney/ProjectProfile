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
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  environment         = var.environment
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = data.azurerm_client_config.current.object_id
  tags                = var.tags
}

# ─────────────────────────────────────────
# Azure OpenAI
# ─────────────────────────────────────────
module "openai" {
  source              = "./modules/openai"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  environment         = var.environment
  sku                 = var.openai_sku
  keyvault_id         = module.keyvault.keyvault_id
  tags                = var.tags
}

# ─────────────────────────────────────────
# Azure AI Search
# ─────────────────────────────────────────
module "ai_search" {
  source              = "./modules/ai_search"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  environment         = var.environment
  sku                 = var.search_sku
  keyvault_id         = module.keyvault.keyvault_id
  tags                = var.tags
}

# ─────────────────────────────────────────
# App Service (Node.js API)
# ─────────────────────────────────────────
module "app_service" {
  source              = "./modules/app_service"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  environment         = var.environment
  sku                 = var.app_service_sku
  keyvault_id         = module.keyvault.keyvault_id
  openai_endpoint     = module.openai.endpoint
  search_endpoint     = module.ai_search.endpoint
  tags                = var.tags
}

# ─────────────────────────────────────────
# API Management
# ─────────────────────────────────────────
module "apim" {
  source              = "./modules/apim"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  environment         = var.environment
  app_service_url     = module.app_service.app_service_url
  tags                = var.tags
}

# ─────────────────────────────────────────
# Monitoring (App Insights + Log Analytics)
# ─────────────────────────────────────────
module "monitoring" {
  source              = "./modules/monitoring"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  environment         = var.environment
  app_service_id      = module.app_service.app_service_id
  tags                = var.tags
}
