# ─────────────────────────────────────────────────────
# RBAC Design — Least Privilege
#
# Security Team → Security Admin  (MG root level — read all, write policies)
# Platform Team → Contributor     (Connectivity + Management subscriptions)
# Dev Team      → Contributor     (Non-prod subscription only)
# Dev Team      → Reader          (Prod subscription — read only)
# ─────────────────────────────────────────────────────

# Security team — Security Admin at root MG level
resource "azurerm_role_assignment" "security_admin_root" {
  scope                = var.root_management_group_id
  role_definition_name = "Security Admin"
  principal_id         = var.security_team_object_id
}

# Security team — Reader at root MG level (see all resources)
resource "azurerm_role_assignment" "security_reader_root" {
  scope                = var.root_management_group_id
  role_definition_name = "Reader"
  principal_id         = var.security_team_object_id
}

# Platform team — Contributor on connectivity subscription
resource "azurerm_role_assignment" "platform_connectivity" {
  scope                = "/subscriptions/${var.connectivity_subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = var.platform_team_object_id
}

# Platform team — Reader on all landing zones MG
resource "azurerm_role_assignment" "platform_landing_zones_reader" {
  scope                = var.landing_zones_mg_id
  role_definition_name = "Reader"
  principal_id         = var.platform_team_object_id
}

# Dev team — Contributor on non-prod subscription
resource "azurerm_role_assignment" "dev_nonprod_contributor" {
  scope                = "/subscriptions/${var.nonprod_subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = var.dev_team_object_id
}

# Dev team — Reader on prod subscription (view but not touch)
resource "azurerm_role_assignment" "dev_prod_reader" {
  scope                = "/subscriptions/${var.prod_subscription_id}"
  role_definition_name = "Reader"
  principal_id         = var.dev_team_object_id
}
