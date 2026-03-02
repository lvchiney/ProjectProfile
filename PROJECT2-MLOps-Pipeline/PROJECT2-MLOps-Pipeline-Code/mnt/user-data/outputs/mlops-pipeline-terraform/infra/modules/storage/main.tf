resource "azurerm_storage_account" "training" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  # Versioning — recover accidentally overwritten training data
  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }

  tags = var.tags
}

# Container for incoming training data — blob upload triggers pipeline
resource "azurerm_storage_container" "training_data" {
  name                  = "training-data"
  storage_account_name  = azurerm_storage_account.training.name
  container_access_type = "private"
}

# Container for model artifacts output by Azure ML
resource "azurerm_storage_container" "model_artifacts" {
  name                  = "model-artifacts"
  storage_account_name  = azurerm_storage_account.training.name
  container_access_type = "private"
}

# Container for evaluation results and accuracy reports
resource "azurerm_storage_container" "evaluation_results" {
  name                  = "evaluation-results"
  storage_account_name  = azurerm_storage_account.training.name
  container_access_type = "private"
}
