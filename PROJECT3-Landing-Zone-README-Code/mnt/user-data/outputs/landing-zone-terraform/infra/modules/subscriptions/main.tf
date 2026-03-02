# ─────────────────────────────────────────────────────
# Subscription-level configuration
# Applied to both Production and Non-Production
# ─────────────────────────────────────────────────────

# ── Production Subscription Resource Groups ───────────
resource "azurerm_resource_group" "prod_workloads" {
  provider = azurerm.production
  name     = "rg-workloads-prod"
  location = "eastus"
  tags     = merge(var.tags, { Environment = "prod" })
}

resource "azurerm_resource_group" "prod_security" {
  provider = azurerm.production
  name     = "rg-security-prod"
  location = "eastus"
  tags     = merge(var.tags, { Environment = "prod" })
}

# ── Non-Production Subscription Resource Groups ───────
resource "azurerm_resource_group" "nonprod_workloads" {
  provider = azurerm.nonproduction
  name     = "rg-workloads-nonprod"
  location = "eastus"
  tags     = merge(var.tags, { Environment = "nonprod" })
}

# ── Diagnostic Settings → Central Log Analytics ───────
# Send prod subscription activity log to central Log Analytics
resource "azurerm_monitor_diagnostic_setting" "prod_activity_log" {
  provider                   = azurerm.production
  name                       = "diag-prod-activity-log"
  target_resource_id         = "/subscriptions/${var.prod_subscription_id}"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "Administrative"
  }
  enabled_log {
    category = "Security"
  }
  enabled_log {
    category = "Policy"
  }
  enabled_log {
    category = "Alert"
  }
}

resource "azurerm_monitor_diagnostic_setting" "nonprod_activity_log" {
  provider                   = azurerm.nonproduction
  name                       = "diag-nonprod-activity-log"
  target_resource_id         = "/subscriptions/${var.nonprod_subscription_id}"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "Administrative"
  }
  enabled_log {
    category = "Security"
  }
  enabled_log {
    category = "Policy"
  }
}
