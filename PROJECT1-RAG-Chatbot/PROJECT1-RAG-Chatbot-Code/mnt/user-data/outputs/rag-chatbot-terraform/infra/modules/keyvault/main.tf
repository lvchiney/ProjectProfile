resource "azurerm_key_vault" "kv" {
  name                        = "kv-rag-${var.environment}-${random_string.suffix.result}"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = var.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 30
  purge_protection_enabled    = true
  enable_rbac_authorization   = true

  tags = var.tags
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Grant the deploying identity (you / service principal) access
resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.object_id
}
