resource "azurerm_api_management" "apim" {
  name                = "apim-rag-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = "RAG Chatbot Team"
  publisher_email     = "admin@example.com"
  sku_name            = "Developer_1"   # Use "Standard_1" for production

  tags = var.tags
}

# API definition pointing to App Service backend
resource "azurerm_api_management_api" "chat_api" {
  name                = "chat-api"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "RAG Chat API"
  path                = "chat"
  protocols           = ["https"]
  subscription_required = false
}

# Backend pointing to App Service
resource "azurerm_api_management_backend" "app_service" {
  name                = "app-service-backend"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.apim.name
  protocol            = "http"
  url                 = var.app_service_url
}

# Rate limiting policy — 100 calls per minute per IP
resource "azurerm_api_management_api_policy" "rate_limit" {
  api_name            = azurerm_api_management_api.chat_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = var.resource_group_name

  xml_content = <<XML
<policies>
  <inbound>
    <rate-limit-by-key calls="100" renewal-period="60" counter-key="@(context.Request.IpAddress)" />
    <base />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
</policies>
XML
}
