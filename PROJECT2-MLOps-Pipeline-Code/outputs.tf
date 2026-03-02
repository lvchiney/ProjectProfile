output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.main.name
}

output "ml_workspace_name" {
  description = "Azure ML Workspace name"
  value       = module.ml_workspace.workspace_name
}

output "ml_workspace_id" {
  description = "Azure ML Workspace resource ID"
  value       = module.ml_workspace.workspace_id
}

output "storage_account_name" {
  description = "Training data storage account name"
  value       = module.storage.storage_account_name
}

output "training_container_name" {
  description = "Blob container for training data uploads"
  value       = module.storage.training_container_name
}

output "container_registry_login_server" {
  description = "ACR login server URL"
  value       = module.container_registry.login_server
}

output "keyvault_uri" {
  description = "Key Vault URI"
  value       = module.keyvault.keyvault_uri
}

output "app_insights_connection_string" {
  description = "App Insights connection string"
  value       = module.monitoring.connection_string
  sensitive   = true
}
