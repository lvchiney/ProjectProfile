resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-rag-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

resource "azurerm_application_insights" "appi" {
  name                = "appi-rag-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.law.id
  application_type    = "Node.JS"

  tags = var.tags
}

# Alert — App Service HTTP 5xx errors
resource "azurerm_monitor_metric_alert" "http_errors" {
  name                = "alert-rag-http5xx-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [var.app_service_id]
  description         = "Alert when HTTP 5xx errors exceed threshold"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 10
  }
}

# Availability test — ping the API every 5 minutes
resource "azurerm_application_insights_standard_web_test" "availability" {
  name                    = "webtest-rag-${var.environment}"
  resource_group_name     = var.resource_group_name
  location                = var.location
  application_insights_id = azurerm_application_insights.appi.id
  geo_locations           = ["us-va-ash-azr", "us-tx-sn1-azr"]
  frequency               = 300  # Every 5 minutes

  request {
    url = "https://app-rag-api-${var.environment}.azurewebsites.net/health"
  }

  tags = var.tags
}
