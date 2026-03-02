output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.main.name
}

output "openai_endpoint" {
  description = "Azure OpenAI endpoint URL"
  value       = module.openai.endpoint
}

output "search_endpoint" {
  description = "Azure AI Search endpoint URL"
  value       = module.ai_search.endpoint
}

output "app_service_url" {
  description = "App Service URL (Node.js API)"
  value       = module.app_service.app_service_url
}

output "apim_gateway_url" {
  description = "API Management Gateway URL"
  value       = module.apim.gateway_url
}

output "keyvault_uri" {
  description = "Key Vault URI"
  value       = module.keyvault.keyvault_uri
}

output "app_insights_instrumentation_key" {
  description = "App Insights instrumentation key"
  value       = module.monitoring.instrumentation_key
  sensitive   = true
}
