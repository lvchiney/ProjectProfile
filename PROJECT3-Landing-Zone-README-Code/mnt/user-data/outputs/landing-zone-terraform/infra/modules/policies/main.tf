# ─────────────────────────────────────────────────────
# POLICY 1: Allowed Regions
# Deny resources outside allowed regions
# ─────────────────────────────────────────────────────
resource "azurerm_policy_definition" "allowed_regions" {
  name         = "custom-allowed-regions"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Allowed Azure Regions"
  description  = "Deny resources created outside approved regions"

  policy_rule = jsonencode({
    if = {
      not = {
        field = "location"
        in    = var.allowed_regions
      }
    }
    then = {
      effect = "Deny"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "allowed_regions" {
  name                 = "allowed-regions"
  display_name         = "Allowed Azure Regions"
  policy_definition_id = azurerm_policy_definition.allowed_regions.id
  management_group_id  = var.root_management_group_id
}

# ─────────────────────────────────────────────────────
# POLICY 2: Required Tags
# Deny resources without mandatory tags
# ─────────────────────────────────────────────────────
resource "azurerm_policy_definition" "required_tags" {
  name         = "custom-required-tags"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Required Tags on All Resources"
  description  = "Enforce Environment, CostCenter, and Owner tags"

  policy_rule = jsonencode({
    if = {
      anyOf = [
        { field = "tags['Environment']", exists = "false" },
        { field = "tags['CostCenter']",  exists = "false" },
        { field = "tags['Owner']",       exists = "false" }
      ]
    }
    then = {
      effect = "Deny"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "required_tags" {
  name                 = "required-tags"
  display_name         = "Required Tags"
  policy_definition_id = azurerm_policy_definition.required_tags.id
  management_group_id  = var.root_management_group_id
}

# ─────────────────────────────────────────────────────
# POLICY 3: No Public IPs on VMs
# ─────────────────────────────────────────────────────
resource "azurerm_policy_definition" "no_public_ip" {
  name         = "custom-no-public-ip-vm"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "No Public IP on Virtual Machines"
  description  = "Deny VM deployments with public IP addresses"

  policy_rule = jsonencode({
    if = {
      allOf = [
        { field = "type", equals = "Microsoft.Network/networkInterfaces" },
        {
          not = {
            field = "Microsoft.Network/networkInterfaces/ipconfigurations[*].publicIpAddress.id"
            exists = "false"
          }
        }
      ]
    }
    then = {
      effect = "Deny"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "no_public_ip" {
  name                 = "no-public-ip-vm"
  display_name         = "No Public IP on VMs"
  policy_definition_id = azurerm_policy_definition.no_public_ip.id
  management_group_id  = var.landing_zones_mg_id
}

# ─────────────────────────────────────────────────────
# POLICY 4: Storage HTTPS Only
# ─────────────────────────────────────────────────────
resource "azurerm_policy_assignment" "storage_https_only" {
  name                 = "storage-https-only"
  display_name         = "Storage HTTPS Only"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9"
  scope                = var.root_management_group_id
}

# ─────────────────────────────────────────────────────
# POLICY 5: Key Vault Soft Delete
# ─────────────────────────────────────────────────────
resource "azurerm_policy_assignment" "keyvault_soft_delete" {
  name                 = "keyvault-soft-delete"
  display_name         = "Key Vault Soft Delete Must Be Enabled"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d"
  scope                = var.root_management_group_id
}

# ─────────────────────────────────────────────────────
# POLICY 6: Diagnostic Logs to Log Analytics
# Auto-deploy diagnostic settings on all supported resources
# ─────────────────────────────────────────────────────
resource "azurerm_policy_definition" "diagnostic_logs" {
  name         = "custom-diagnostic-logs"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Diagnostic Logs Must Go to Log Analytics"
  description  = "Ensure all resources send diagnostic logs to centralized Log Analytics"

  policy_rule = jsonencode({
    if = {
      field = "type"
      in = [
        "Microsoft.Web/sites",
        "Microsoft.Sql/servers/databases",
        "Microsoft.Storage/storageAccounts",
        "Microsoft.KeyVault/vaults"
      ]
    }
    then = {
      effect = "DeployIfNotExists"
      details = {
        type = "Microsoft.Insights/diagnosticSettings"
        existenceCondition = {
          field  = "Microsoft.Insights/diagnosticSettings/workspaceId"
          equals = var.log_analytics_workspace_id
        }
      }
    }
  })
}

resource "azurerm_management_group_policy_assignment" "diagnostic_logs" {
  name                 = "diagnostic-logs-law"
  display_name         = "Send Diagnostic Logs to Log Analytics"
  policy_definition_id = azurerm_policy_definition.diagnostic_logs.id
  management_group_id  = var.root_management_group_id

  identity {
    type = "SystemAssigned"
  }

  location = "eastus"
}
