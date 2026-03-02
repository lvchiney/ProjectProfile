resource "azurerm_service_plan" "plan" {
  name                = "asp-rag-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = var.sku

  tags = var.tags
}

resource "azurerm_linux_web_app" "api" {
  name                = "app-rag-api-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.plan.id

  # Enable managed identity — used to pull secrets from Key Vault
  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      node_version = "18-lts"
    }
    always_on = true
  }

  app_settings = {
    # Endpoints injected as env vars — no hardcoded keys
    "AZURE_OPENAI_ENDPOINT"     = var.openai_endpoint
    "AZURE_SEARCH_ENDPOINT"     = var.search_endpoint
    "KEY_VAULT_URI"             = var.keyvault_id
    "WEBSITE_NODE_DEFAULT_VERSION" = "~18"
    "NODE_ENV"                  = var.environment
  }

  tags = var.tags
}

# Staging slot for Blue/Green deployments
resource "azurerm_linux_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.api.id

  site_config {
    application_stack {
      node_version = "18-lts"
    }
  }

  identity {
    type = "SystemAssigned"
  }
}

# Grant App Service managed identity access to Key Vault secrets
resource "azurerm_role_assignment" "app_kv_secrets" {
  scope                = var.keyvault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.api.identity[0].principal_id
}
