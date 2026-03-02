resource "azurerm_container_registry" "acr" {
  name                = var.container_registry_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"

  # Admin account disabled — use managed identity instead
  admin_enabled = false

  tags = var.tags
}
