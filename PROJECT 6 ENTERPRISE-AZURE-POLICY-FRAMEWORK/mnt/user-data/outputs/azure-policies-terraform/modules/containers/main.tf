
# ============================================================
# Module: Container Security Policies
# Scope: Landing Zones Management Group
# ============================================================

# ------------------------------------------------------------
# POLICY 1: Deny Privileged Containers in AKS
# ------------------------------------------------------------

resource "azurerm_policy_definition" "deny_privileged_containers" {
  name         = "deny-privileged-containers-aks"
  policy_type  = "Custom"
  mode         = "Microsoft.Kubernetes.Data"
  display_name = "Deny privileged containers in AKS"
  description  = "Prevents privileged containers from running in AKS clusters"

  metadata = jsonencode({
    category = "Container Security"
    version  = "1.0.0"
  })

  parameters = jsonencode({
    effect = {
      type = "String"
      defaultValue = "Deny"
      allowedValues = ["Audit", "Deny", "Disabled"]
      metadata = {
        displayName = "Effect"
      }
    }
    excludedNamespaces = {
      type = "Array"
      defaultValue = ["kube-system", "gatekeeper-system", "azure-arc"]
      metadata = {
        displayName = "Namespace exclusions"
      }
    }
  })

  policy_rule = jsonencode({
    if = {
      field  = "type"
      equals = "Microsoft.ContainerService/managedClusters"
    }
    then = {
      effect = "[parameters('effect')]"
      details = {
        templateInfo = {
          sourceType = "PublicURL"
          url        = "https://store.policy.core.windows.net/kubernetes/container-no-privilege/v2/template.yaml"
        }
        apiGroups          = [""]
        kinds              = ["Pod"]
        namespaces         = "[parameters('excludedNamespaces')]"
        excludedNamespaces = "[parameters('excludedNamespaces')]"
      }
    }
  })
}

resource "azurerm_management_group_policy_assignment" "deny_privileged_containers" {
  name                 = "deny-priv-containers"
  display_name         = "Deny Privileged Containers in AKS"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.deny_privileged_containers.id
  location             = var.location

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    effect = { value = "Deny" }
    excludedNamespaces = {
      value = ["kube-system", "gatekeeper-system", "azure-arc", "azure-extensions-usage-system"]
    }
  })
}

# ------------------------------------------------------------
# POLICY 2: Require AKS Private Cluster
# ------------------------------------------------------------

resource "azurerm_policy_definition" "require_aks_private" {
  name         = "require-aks-private-cluster"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Require AKS clusters to be private"
  description  = "Ensures AKS API server is not publicly accessible"

  metadata = jsonencode({
    category = "Container Security"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.ContainerService/managedClusters"
        },
        {
          anyOf = [
            {
              field    = "Microsoft.ContainerService/managedClusters/apiServerAccessProfile.enablePrivateCluster"
              exists   = "false"
            },
            {
              field  = "Microsoft.ContainerService/managedClusters/apiServerAccessProfile.enablePrivateCluster"
              equals = "false"
            }
          ]
        }
      ]
    }
    then = {
      effect = "Deny"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "require_aks_private" {
  name                 = "require-aks-private"
  display_name         = "Require AKS Private Cluster"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.require_aks_private.id
}

# ------------------------------------------------------------
# POLICY 3: Require Azure AD RBAC on AKS
# ------------------------------------------------------------

resource "azurerm_policy_definition" "require_aks_aad_rbac" {
  name         = "require-aks-aad-rbac"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Require Azure AD RBAC on AKS clusters"
  description  = "Ensures AKS clusters use Azure AD integration with Azure RBAC"

  metadata = jsonencode({
    category = "Container Security"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.ContainerService/managedClusters"
        },
        {
          anyOf = [
            {
              field    = "Microsoft.ContainerService/managedClusters/aadProfile"
              exists   = "false"
            },
            {
              field  = "Microsoft.ContainerService/managedClusters/aadProfile.enableAzureRBAC"
              equals = "false"
            }
          ]
        }
      ]
    }
    then = {
      effect = "Deny"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "require_aks_aad_rbac" {
  name                 = "require-aks-aad-rbac"
  display_name         = "Require AAD RBAC on AKS"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.require_aks_aad_rbac.id
}

# ------------------------------------------------------------
# POLICY 4: Deny ACR Public Network Access
# ------------------------------------------------------------

resource "azurerm_policy_definition" "deny_acr_public_access" {
  name         = "deny-acr-public-access"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Deny public network access on Azure Container Registry"
  description  = "Ensures ACR is only accessible via private endpoints"

  metadata = jsonencode({
    category = "Container Security"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.ContainerRegistry/registries"
        },
        {
          field  = "Microsoft.ContainerRegistry/registries/publicNetworkAccess"
          equals = "Enabled"
        }
      ]
    }
    then = {
      effect = "Deny"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "deny_acr_public_access" {
  name                 = "deny-acr-public"
  display_name         = "Deny ACR Public Network Access"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.deny_acr_public_access.id
}

# ------------------------------------------------------------
# POLICY 5: Require Defender for Containers (DeployIfNotExists)
# ------------------------------------------------------------

resource "azurerm_management_group_policy_assignment" "deploy_defender_containers" {
  name                 = "deploy-defender-containers"
  display_name         = "Deploy Microsoft Defender for Containers"
  management_group_id  = var.management_group_id
  # Built-in: Configure Microsoft Defender for Containers to be enabled
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/c9ddb292-b203-4738-aead-18e2716e858f"
  location             = var.location

  identity {
    type = "SystemAssigned"
  }
}

# ------------------------------------------------------------
# POLICY 6: Audit AKS Clusters Without Auto-Upgrade
# ------------------------------------------------------------

resource "azurerm_policy_definition" "audit_aks_auto_upgrade" {
  name         = "audit-aks-auto-upgrade"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Audit AKS clusters without auto-upgrade channel"
  description  = "Flags AKS clusters that do not have an auto-upgrade channel configured"

  metadata = jsonencode({
    category = "Container Security"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.ContainerService/managedClusters"
        },
        {
          anyOf = [
            {
              field    = "Microsoft.ContainerService/managedClusters/autoUpgradeProfile.upgradeChannel"
              exists   = "false"
            },
            {
              field  = "Microsoft.ContainerService/managedClusters/autoUpgradeProfile.upgradeChannel"
              equals = "none"
            }
          ]
        }
      ]
    }
    then = {
      effect = "Audit"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "audit_aks_auto_upgrade" {
  name                 = "audit-aks-upgrade"
  display_name         = "Audit AKS Auto-Upgrade Channel"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.audit_aks_auto_upgrade.id
}

# ------------------------------------------------------------
# OUTPUTS
# ------------------------------------------------------------

output "deny_privileged_containers_policy_id" {
  value = azurerm_policy_definition.deny_privileged_containers.id
}
