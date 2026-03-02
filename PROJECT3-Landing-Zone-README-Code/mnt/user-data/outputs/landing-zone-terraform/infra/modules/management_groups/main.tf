# ─────────────────────────────────────────────────────
# Management Group Hierarchy
#
# Root (Tenant)
# ├── Platform
# │   ├── Connectivity
# │   └── Management
# └── Landing Zones
#     ├── Production
#     └── Non-Production
# ─────────────────────────────────────────────────────

resource "azurerm_management_group" "platform" {
  display_name               = "Platform"
  parent_management_group_id = "/providers/Microsoft.Management/managementGroups/${var.root_management_group_id}"
}

resource "azurerm_management_group" "connectivity" {
  display_name               = "Connectivity"
  parent_management_group_id = azurerm_management_group.platform.id
}

resource "azurerm_management_group" "management" {
  display_name               = "Management"
  parent_management_group_id = azurerm_management_group.platform.id
}

resource "azurerm_management_group" "landing_zones" {
  display_name               = "Landing Zones"
  parent_management_group_id = "/providers/Microsoft.Management/managementGroups/${var.root_management_group_id}"
}

resource "azurerm_management_group" "production" {
  display_name               = "Production"
  parent_management_group_id = azurerm_management_group.landing_zones.id
}

resource "azurerm_management_group" "non_production" {
  display_name               = "Non-Production"
  parent_management_group_id = azurerm_management_group.landing_zones.id
}

# Associate subscriptions to management groups
resource "azurerm_management_group_subscription_association" "prod" {
  management_group_id = azurerm_management_group.production.id
  subscription_id     = "/subscriptions/${var.prod_subscription_id}"
}

resource "azurerm_management_group_subscription_association" "nonprod" {
  management_group_id = azurerm_management_group.non_production.id
  subscription_id     = "/subscriptions/${var.nonprod_subscription_id}"
}

resource "azurerm_management_group_subscription_association" "connectivity" {
  management_group_id = azurerm_management_group.connectivity.id
  subscription_id     = "/subscriptions/${var.connectivity_subscription_id}"
}

resource "azurerm_management_group_subscription_association" "management" {
  management_group_id = azurerm_management_group.management.id
  subscription_id     = "/subscriptions/${var.management_subscription_id}"
}
