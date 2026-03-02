resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-mlops-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

resource "azurerm_application_insights" "appi" {
  name                = "appi-mlops-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.law.id
  application_type    = "other"

  tags = var.tags
}

# Alert — model accuracy dropped below threshold in production
resource "azurerm_monitor_metric_alert" "model_accuracy_drop" {
  name                = "alert-mlops-accuracy-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.appi.id]
  description         = "Alert when model accuracy drops below baseline"
  severity            = 1   # Critical
  frequency           = "PT15M"
  window_size         = "PT1H"

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "customMetrics/model_accuracy"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 0.80
  }
}

# Alert — model endpoint latency high
resource "azurerm_monitor_metric_alert" "endpoint_latency" {
  name                = "alert-mlops-latency-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.appi.id]
  description         = "Alert when model endpoint P95 latency exceeds 2 seconds"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/duration"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 2000  # milliseconds
  }
}
