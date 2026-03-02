# ─────────────────────────────────────────────────────
# Centralized Monitoring — Management Subscription
# ─────────────────────────────────────────────────────

resource "azurerm_resource_group" "monitoring" {
  provider = azurerm.management
  name     = "rg-monitoring"
  location = var.location
  tags     = var.tags
}

# ── Centralized Log Analytics Workspace ──────────────
resource "azurerm_log_analytics_workspace" "central" {
  provider            = azurerm.management
  name                = "law-central"
  location            = var.location
  resource_group_name = azurerm_resource_group.monitoring.name
  sku                 = "PerGB2018"
  retention_in_days   = 90   # 90 days for compliance

  tags = var.tags
}

# ── Microsoft Defender for Cloud (all subscriptions) ─
resource "azurerm_security_center_subscription_pricing" "prod_defender" {
  provider      = azurerm.production
  tier          = "Standard"
  resource_type = "VirtualMachines"
}

resource "azurerm_security_center_subscription_pricing" "prod_defender_sql" {
  provider      = azurerm.production
  tier          = "Standard"
  resource_type = "SqlServers"
}

resource "azurerm_security_center_workspace" "prod" {
  provider     = azurerm.production
  scope        = "/subscriptions/${var.prod_subscription_id}"
  workspace_id = azurerm_log_analytics_workspace.central.id
}

resource "azurerm_security_center_workspace" "nonprod" {
  provider     = azurerm.nonproduction
  scope        = "/subscriptions/${var.nonprod_subscription_id}"
  workspace_id = azurerm_log_analytics_workspace.central.id
}

# ── Action Group for Alerts ───────────────────────────
resource "azurerm_monitor_action_group" "platform_alerts" {
  provider            = azurerm.management
  name                = "ag-platform-alerts"
  resource_group_name = azurerm_resource_group.monitoring.name
  short_name          = "pltalerts"

  email_receiver {
    name          = "Platform Team"
    email_address = var.alert_email
  }
}

# ── Budget Alert — Production Subscription ────────────
resource "azurerm_consumption_budget_subscription" "prod_budget" {
  provider        = azurerm.production
  name            = "budget-prod-monthly"
  subscription_id = "/subscriptions/${var.prod_subscription_id}"
  amount          = var.budget_amount
  time_grain      = "Monthly"

  time_period {
    start_date = "2025-01-01T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold      = 80    # Alert at 80% of budget
    operator       = "GreaterThan"
    threshold_type = "Actual"

    contact_emails = [var.alert_email]
  }

  notification {
    enabled        = true
    threshold      = 100   # Alert at 100% of budget
    operator       = "GreaterThan"
    threshold_type = "Actual"

    contact_emails = [var.alert_email]
  }
}

# ── Budget Alert — Non-Production Subscription ────────
resource "azurerm_consumption_budget_subscription" "nonprod_budget" {
  provider        = azurerm.nonproduction
  name            = "budget-nonprod-monthly"
  subscription_id = "/subscriptions/${var.nonprod_subscription_id}"
  amount          = var.budget_amount / 2   # Non-prod gets half the budget
  time_grain      = "Monthly"

  time_period {
    start_date = "2025-01-01T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    threshold_type = "Actual"

    contact_emails = [var.alert_email]
  }
}
