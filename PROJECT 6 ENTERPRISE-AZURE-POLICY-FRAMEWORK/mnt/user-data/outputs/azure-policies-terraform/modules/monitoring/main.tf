
# ============================================================
# Module: Monitoring & Logging Policies
# Scope: Root Management Group
# ============================================================

variable "management_group_id" {}
variable "log_analytics_workspace_id" {}
variable "location" { default = "uksouth" }
variable "tags" { default = {} }

# ------------------------------------------------------------
# POLICY 1: Deploy Defender for Cloud (DeployIfNotExists)
# ------------------------------------------------------------

resource "azurerm_policy_definition" "deploy_defender" {
  name         = "deploy-defender-for-cloud"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Deploy Microsoft Defender for Cloud — All Plans"
  description  = "Automatically enables all Defender for Cloud plans on subscriptions"

  metadata = jsonencode({
    category = "Monitoring & Security"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      field  = "type"
      equals = "Microsoft.Resources/subscriptions"
    }
    then = {
      effect = "DeployIfNotExists"
      details = {
        type = "Microsoft.Security/pricings"
        deploymentScope = "subscription"
        existenceScope  = "subscription"
        roleDefinitionIds = [
          "/providers/Microsoft.Authorization/roleDefinitions/fb1c8493-542b-48eb-b624-b4c8fea62acd"
        ]
        existenceCondition = {
          allOf = [
            {
              field  = "Microsoft.Security/pricings/pricingTier"
              equals = "Standard"
            }
          ]
        }
        deployment = {
          location   = "uksouth"
          properties = {
            mode     = "incremental"
            template = {
              "$schema"      = "https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#"
              contentVersion = "1.0.0.0"
              resources = [
                {
                  type       = "Microsoft.Security/pricings"
                  apiVersion = "2022-03-01"
                  name       = "VirtualMachines"
                  properties = { pricingTier = "Standard" }
                },
                {
                  type       = "Microsoft.Security/pricings"
                  apiVersion = "2022-03-01"
                  name       = "StorageAccounts"
                  properties = { pricingTier = "Standard" }
                },
                {
                  type       = "Microsoft.Security/pricings"
                  apiVersion = "2022-03-01"
                  name       = "Containers"
                  properties = { pricingTier = "Standard" }
                },
                {
                  type       = "Microsoft.Security/pricings"
                  apiVersion = "2022-03-01"
                  name       = "SqlServers"
                  properties = { pricingTier = "Standard" }
                },
                {
                  type       = "Microsoft.Security/pricings"
                  apiVersion = "2022-03-01"
                  name       = "AppServices"
                  properties = { pricingTier = "Standard" }
                },
                {
                  type       = "Microsoft.Security/pricings"
                  apiVersion = "2022-03-01"
                  name       = "KeyVaults"
                  properties = { pricingTier = "Standard" }
                }
              ]
            }
          }
        }
      }
    }
  })
}

resource "azurerm_management_group_policy_assignment" "deploy_defender" {
  name                 = "deploy-defender-cloud"
  display_name         = "Deploy Defender for Cloud — All Plans"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.deploy_defender.id
  location             = var.location

  identity {
    type = "SystemAssigned"
  }
}

# ------------------------------------------------------------
# POLICY 2: Deploy Diagnostic Settings — Key Vault (DINE)
# ------------------------------------------------------------

resource "azurerm_policy_definition" "deploy_diag_keyvault" {
  name         = "deploy-diag-keyvault"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Deploy diagnostic settings for Key Vault to Log Analytics"
  description  = "Automatically deploys diagnostic settings to send Key Vault logs to central Log Analytics"

  metadata = jsonencode({
    category = "Monitoring & Logging"
    version  = "1.0.0"
  })

  parameters = jsonencode({
    logAnalyticsWorkspaceId = {
      type = "String"
      metadata = {
        displayName = "Log Analytics Workspace ID"
        strongType  = "omsWorkspace"
      }
    }
    effect = {
      type         = "String"
      defaultValue = "DeployIfNotExists"
      allowedValues = ["DeployIfNotExists", "Disabled"]
    }
  })

  policy_rule = jsonencode({
    if = {
      field  = "type"
      equals = "Microsoft.KeyVault/vaults"
    }
    then = {
      effect = "[parameters('effect')]"
      details = {
        type = "Microsoft.Insights/diagnosticSettings"
        roleDefinitionIds = [
          "/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
        ]
        existenceCondition = {
          allOf = [
            {
              field  = "Microsoft.Insights/diagnosticSettings/logs.enabled"
              equals = "true"
            },
            {
              field  = "Microsoft.Insights/diagnosticSettings/workspaceId"
              equals = "[parameters('logAnalyticsWorkspaceId')]"
            }
          ]
        }
        deployment = {
          properties = {
            mode     = "incremental"
            template = {
              "$schema"      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
              contentVersion = "1.0.0.0"
              parameters = {
                resourceName            = { type = "string" }
                logAnalyticsWorkspaceId = { type = "string" }
                location                = { type = "string" }
              }
              resources = [
                {
                  type       = "Microsoft.KeyVault/vaults/providers/diagnosticSettings"
                  apiVersion = "2021-05-01-preview"
                  name       = "[concat(parameters('resourceName'), '/Microsoft.Insights/setByPolicy')]"
                  location   = "[parameters('location')]"
                  properties = {
                    workspaceId = "[parameters('logAnalyticsWorkspaceId')]"
                    logs = [
                      { category = "AuditEvent",        enabled = true }
                      { category = "AzurePolicyEvaluationDetails", enabled = true }
                    ]
                    metrics = [
                      { category = "AllMetrics", enabled = true }
                    ]
                  }
                }
              ]
            }
            parameters = {
              resourceName            = { value = "[field('name')]" }
              logAnalyticsWorkspaceId = { value = "[parameters('logAnalyticsWorkspaceId')]" }
              location                = { value = "[field('location')]" }
            }
          }
        }
      }
    }
  })
}

resource "azurerm_management_group_policy_assignment" "deploy_diag_keyvault" {
  name                 = "deploy-diag-kv"
  display_name         = "Deploy Diagnostics for Key Vault"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.deploy_diag_keyvault.id
  location             = var.location

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    logAnalyticsWorkspaceId = {
      value = var.log_analytics_workspace_id
    }
    effect = {
      value = "DeployIfNotExists"
    }
  })
}

# ------------------------------------------------------------
# POLICY 3: Audit Missing Activity Log Alert for Policy Operations
# ------------------------------------------------------------

resource "azurerm_policy_definition" "audit_activity_log_alert" {
  name         = "audit-activity-log-policy-ops"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Audit Activity Log Alert for Policy Write Operations"
  description  = "Ensures an activity log alert exists for policy write/delete operations"

  metadata = jsonencode({
    category = "Monitoring & Logging"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "microsoft.insights/activityLogAlerts"
        },
        {
          field    = "Microsoft.Insights/ActivityLogAlerts/condition.allOf[*].equals"
          notContains = "Microsoft.Authorization/policyAssignments/write"
        }
      ]
    }
    then = {
      effect = "Audit"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "audit_activity_log_alert" {
  name                 = "audit-actlog-policy"
  display_name         = "Audit Activity Log Alert for Policy Ops"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.audit_activity_log_alert.id
}

# ------------------------------------------------------------
# POLICY 4: Require Log Analytics Agent on VMs (Built-in DINE)
# ------------------------------------------------------------

resource "azurerm_management_group_policy_assignment" "deploy_log_analytics_vm" {
  name                 = "deploy-law-agent-vm"
  display_name         = "Deploy Log Analytics Agent on Linux VMs"
  management_group_id  = var.management_group_id
  # Built-in: Deploy Log Analytics agent for Linux VMs
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/053d3325-282c-4e5c-b944-24faffd30d77"
  location             = var.location

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    logAnalyticsWorkspaceId = {
      value = var.log_analytics_workspace_id
    }
  })
}

# ------------------------------------------------------------
# OUTPUTS
# ------------------------------------------------------------

output "deploy_defender_policy_id" {
  value = azurerm_policy_definition.deploy_defender.id
}
