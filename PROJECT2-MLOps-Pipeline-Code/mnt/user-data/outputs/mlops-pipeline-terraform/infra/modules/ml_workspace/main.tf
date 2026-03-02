resource "azurerm_machine_learning_workspace" "mlw" {
  name                    = var.ml_workspace_name
  location                = var.location
  resource_group_name     = var.resource_group_name
  application_insights_id = var.app_insights_id
  key_vault_id            = var.keyvault_id
  storage_account_id      = var.storage_account_id
  container_registry_id   = var.container_registry_id

  # System-assigned managed identity
  # — Azure ML uses this to access storage, ACR, Key Vault
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Grant Azure ML workspace access to Storage Account
resource "azurerm_role_assignment" "mlw_storage" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_machine_learning_workspace.mlw.identity[0].principal_id
}

# Grant Azure ML workspace access to Container Registry (pull/push model images)
resource "azurerm_role_assignment" "mlw_acr" {
  scope                = var.container_registry_id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_machine_learning_workspace.mlw.identity[0].principal_id
}

# Grant Azure ML workspace access to Key Vault (read secrets)
resource "azurerm_role_assignment" "mlw_keyvault" {
  scope                = var.keyvault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_machine_learning_workspace.mlw.identity[0].principal_id
}

# Azure ML compute cluster for training jobs
resource "azurerm_machine_learning_compute_cluster" "training_cluster" {
  name                          = "cpu-cluster-${var.environment}"
  location                      = var.location
  machine_learning_workspace_id = azurerm_machine_learning_workspace.mlw.id
  vm_priority                   = "Dedicated"
  vm_size                       = "Standard_DS3_v2"

  scale_settings {
    min_node_count                       = 0   # Scale to zero when idle — saves cost
    max_node_count                       = 4
    scale_down_nodes_after_idle_duration = "PT2M"
  }

  identity {
    type = "SystemAssigned"
  }
}
