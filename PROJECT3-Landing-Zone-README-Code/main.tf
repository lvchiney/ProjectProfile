data "azurerm_client_config" "current" {}

# ─────────────────────────────────────────
# 1. Management Group Hierarchy
# ─────────────────────────────────────────
module "management_groups" {
  source                   = "./modules/management_groups"
  root_management_group_id = var.root_management_group_id
}

# ─────────────────────────────────────────
# 2. Azure Policies (assigned at MG level)
# ─────────────────────────────────────────
module "policies" {
  source                        = "./modules/policies"
  root_management_group_id      = var.root_management_group_id
  landing_zones_mg_id           = module.management_groups.landing_zones_mg_id
  platform_mg_id                = module.management_groups.platform_mg_id
  allowed_regions               = var.allowed_regions
  log_analytics_workspace_id    = module.monitoring.log_analytics_workspace_id

  depends_on = [module.management_groups]
}

# ─────────────────────────────────────────
# 3. RBAC — Role Assignments
# ─────────────────────────────────────────
module "rbac" {
  source                       = "./modules/rbac"
  root_management_group_id     = var.root_management_group_id
  landing_zones_mg_id          = module.management_groups.landing_zones_mg_id
  prod_subscription_id         = var.prod_subscription_id
  nonprod_subscription_id      = var.nonprod_subscription_id
  connectivity_subscription_id = var.connectivity_subscription_id
  security_team_object_id      = var.security_team_object_id
  platform_team_object_id      = var.platform_team_object_id
  dev_team_object_id           = var.dev_team_object_id

  depends_on = [module.management_groups]
}

# ─────────────────────────────────────────
# 4. Hub-Spoke Networking
# ─────────────────────────────────────────
module "networking" {
  source                      = "./modules/networking"
  location                    = var.location
  connectivity_subscription_id = var.connectivity_subscription_id
  prod_subscription_id        = var.prod_subscription_id
  nonprod_subscription_id     = var.nonprod_subscription_id
  hub_vnet_address_space      = var.hub_vnet_address_space
  prod_spoke_address_space    = var.prod_spoke_address_space
  nonprod_spoke_address_space = var.nonprod_spoke_address_space
  tags                        = var.tags
}

# ─────────────────────────────────────────
# 5. Centralized Monitoring
# ─────────────────────────────────────────
module "monitoring" {
  source                     = "./modules/monitoring"
  location                   = var.location
  management_subscription_id = var.management_subscription_id
  alert_email                = var.alert_email
  budget_amount              = var.budget_amount
  prod_subscription_id       = var.prod_subscription_id
  tags                       = var.tags
}

# ─────────────────────────────────────────
# 6. Subscription-level config
# ─────────────────────────────────────────
module "subscriptions" {
  source                     = "./modules/subscriptions"
  prod_subscription_id       = var.prod_subscription_id
  nonprod_subscription_id    = var.nonprod_subscription_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = var.tags

  depends_on = [module.monitoring]
}
