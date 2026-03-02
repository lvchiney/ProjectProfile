resource "azurerm_search_service" "search" {
  name                = "srch-rag-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku

  # Enable semantic search
  semantic_search_sku = "free"

  tags = var.tags
}

# Store admin key in Key Vault
resource "azurerm_key_vault_secret" "search_key" {
  name         = "search-admin-key"
  value        = azurerm_search_service.search.primary_key
  key_vault_id = var.keyvault_id
}
