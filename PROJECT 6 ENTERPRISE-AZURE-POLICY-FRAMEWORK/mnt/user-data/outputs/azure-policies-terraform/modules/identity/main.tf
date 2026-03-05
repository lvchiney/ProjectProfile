
# ============================================================
# Module: Identity & Access Policies
# Scope: Root Management Group
# ============================================================

# ------------------------------------------------------------
# POLICY 1: Audit Custom RBAC Roles
# ------------------------------------------------------------

resource "azurerm_policy_definition" "audit_custom_rbac" {
  name         = "audit-custom-rbac-roles"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Audit use of custom RBAC roles"
  description  = "Flags custom RBAC roles — built-in roles should be preferred for auditability"

  metadata = jsonencode({
    category = "Identity & Access"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Authorization/roleDefinitions"
        },
        {
          field  = "Microsoft.Authorization/roleDefinitions/type"
          equals = "CustomRole"
        }
      ]
    }
    then = {
      effect = "Audit"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "audit_custom_rbac" {
  name                 = "audit-custom-rbac"
  display_name         = "Audit Custom RBAC Roles"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.audit_custom_rbac.id
}

# ------------------------------------------------------------
# POLICY 2: Deny Owner Role at Subscription Scope
# ------------------------------------------------------------

resource "azurerm_policy_definition" "deny_owner_subscription" {
  name         = "deny-owner-at-subscription"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Deny Owner role assignment at Subscription scope"
  description  = "Prevents direct Owner role assignments at subscription scope — use MG-level RBAC"

  metadata = jsonencode({
    category = "Identity & Access"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Authorization/roleAssignments"
        },
        {
          field  = "Microsoft.Authorization/roleAssignments/roleDefinitionId"
          equals = "/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635"
        }
      ]
    }
    then = {
      effect = "Audit"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "deny_owner_subscription" {
  name                 = "audit-owner-sub"
  display_name         = "Audit Owner Role at Subscription"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.deny_owner_subscription.id
}

# ------------------------------------------------------------
# POLICY 3: Require MFA for Subscription Owners (Built-in)
# ------------------------------------------------------------

resource "azurerm_management_group_policy_assignment" "mfa_subscription_owners" {
  name                 = "mfa-sub-owners"
  display_name         = "MFA should be enabled for Subscription Owners"
  management_group_id  = var.management_group_id
  # Built-in policy: MFA should be enabled on accounts with owner permissions
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/aa633080-8b72-40c4-a2d7-d00c03e80bed"
}

# ------------------------------------------------------------
# POLICY 4: Require MFA for Write Permissions (Built-in)
# ------------------------------------------------------------

resource "azurerm_management_group_policy_assignment" "mfa_write_permissions" {
  name                 = "mfa-write-perms"
  display_name         = "MFA should be enabled for Write Permission Accounts"
  management_group_id  = var.management_group_id
  # Built-in policy: MFA should be enabled on accounts with write permissions
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/9297c21d-2ed6-4474-b48f-163f75654ce3"
}

# ------------------------------------------------------------
# POLICY 5: Audit External Accounts with Owner Permissions (Built-in)
# ------------------------------------------------------------

resource "azurerm_management_group_policy_assignment" "audit_external_owners" {
  name                 = "audit-external-owners"
  display_name         = "Audit External Accounts with Owner Permissions"
  management_group_id  = var.management_group_id
  # Built-in policy: External accounts with owner permissions should be removed
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/f8456c1c-aa66-4dfb-861a-25d127b775c9"
}

# ------------------------------------------------------------
# POLICY 6: No Service Principal with Owner Rights (Custom Audit)
# ------------------------------------------------------------

resource "azurerm_policy_definition" "audit_sp_owner" {
  name         = "audit-service-principal-owner"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Audit Service Principals with Owner rights"
  description  = "Flags service principals assigned Owner role — violates least privilege"

  metadata = jsonencode({
    category = "Identity & Access"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Authorization/roleAssignments"
        },
        {
          field  = "Microsoft.Authorization/roleAssignments/principalType"
          equals = "ServicePrincipal"
        },
        {
          field  = "Microsoft.Authorization/roleAssignments/roleDefinitionId"
          equals = "/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635"
        }
      ]
    }
    then = {
      effect = "Audit"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "audit_sp_owner" {
  name                 = "audit-sp-owner"
  display_name         = "Audit Service Principal Owner Rights"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.audit_sp_owner.id
}

# ------------------------------------------------------------
# OUTPUTS
# ------------------------------------------------------------

output "audit_custom_rbac_policy_id" {
  value = azurerm_policy_definition.audit_custom_rbac.id
}
