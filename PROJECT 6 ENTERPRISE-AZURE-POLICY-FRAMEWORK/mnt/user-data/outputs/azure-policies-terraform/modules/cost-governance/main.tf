
# ============================================================
# Module: Cost Governance Policies
# Scope: Root Management Group
# ============================================================

variable "management_group_id" {}
variable "allowed_vm_skus"    { default = [] }
variable "allowed_locations"  { default = [] }
variable "mandatory_tags"     { default = [] }
variable "location"           { default = "uksouth" }
variable "tags"               { default = {} }

# ------------------------------------------------------------
# POLICY 1: Require Mandatory Tags on Resource Groups (Deny)
# ------------------------------------------------------------

resource "azurerm_policy_definition" "require_tags_rg" {
  name         = "require-mandatory-tags-rg"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Require mandatory tags on Resource Groups"
  description  = "Denies creation of Resource Groups missing mandatory enterprise tags"

  metadata = jsonencode({
    category = "Cost Governance"
    version  = "1.0.0"
  })

  parameters = jsonencode({
    mandatoryTagNames = {
      type = "Array"
      metadata = {
        displayName = "Mandatory Tag Names"
        description = "List of tag names that must be present on all resource groups"
      }
    }
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Resources/subscriptions/resourceGroups"
        },
        {
          count = {
            value = "[parameters('mandatoryTagNames')]"
            name  = "tagName"
            where = {
              field    = "[concat('tags[', current('tagName'), ']')]"
              exists   = "false"
            }
          }
          greater = 0
        }
      ]
    }
    then = {
      effect = "Deny"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "require_tags_rg" {
  name                 = "require-tags-rg"
  display_name         = "Require Mandatory Tags on Resource Groups"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.require_tags_rg.id

  parameters = jsonencode({
    mandatoryTagNames = {
      value = var.mandatory_tags
    }
  })
}

# ------------------------------------------------------------
# POLICY 2: Inherit Tags from Resource Group (Modify)
# ------------------------------------------------------------

resource "azurerm_policy_definition" "inherit_tags_from_rg" {
  name         = "inherit-environment-tag-from-rg"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Inherit Environment tag from Resource Group"
  description  = "Automatically adds or overwrites the Environment tag on resources using the parent Resource Group value"

  metadata = jsonencode({
    category = "Cost Governance"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "tags['Environment']"
          exists = "false"
        },
        {
          value  = "[resourceGroup().tags['Environment']]"
          exists = "true"
        }
      ]
    }
    then = {
      effect = "Modify"
      details = {
        roleDefinitionIds = [
          "/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
        ]
        operations = [
          {
            operation = "AddOrReplace"
            field     = "tags['Environment']"
            value     = "[resourceGroup().tags['Environment']]"
          }
        ]
      }
    }
  })
}

resource "azurerm_management_group_policy_assignment" "inherit_tags_from_rg" {
  name                 = "inherit-env-tag-rg"
  display_name         = "Inherit Environment Tag from Resource Group"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.inherit_tags_from_rg.id
  location             = var.location

  identity {
    type = "SystemAssigned"
  }
}

# ------------------------------------------------------------
# POLICY 3: Allowed VM SKUs (Deny unapproved sizes)
# ------------------------------------------------------------

resource "azurerm_policy_definition" "allowed_vm_skus" {
  name         = "allowed-vm-skus"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Allowed Virtual Machine SKUs"
  description  = "Restricts VM deployment to approved SKUs only — prevents costly oversized VMs"

  metadata = jsonencode({
    category = "Cost Governance"
    version  = "1.0.0"
  })

  parameters = jsonencode({
    allowedSkus = {
      type = "Array"
      metadata = {
        displayName = "Allowed VM SKUs"
        description = "List of approved VM sizes"
        strongType  = "vmSKUs"
      }
    }
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Compute/virtualMachines"
        },
        {
          field    = "Microsoft.Compute/virtualMachines/sku.name"
          notIn    = "[parameters('allowedSkus')]"
        }
      ]
    }
    then = {
      effect = "Deny"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "allowed_vm_skus" {
  name                 = "allowed-vm-skus"
  display_name         = "Allowed VM SKUs"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.allowed_vm_skus.id

  parameters = jsonencode({
    allowedSkus = {
      value = var.allowed_vm_skus
    }
  })
}

# ------------------------------------------------------------
# POLICY 4: Deny Untagged Resources (Append CostCenter)
# ------------------------------------------------------------

resource "azurerm_policy_definition" "append_costcenter_tag" {
  name         = "append-default-costcenter-tag"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Append default CostCenter tag if missing"
  description  = "Appends a default CostCenter tag value if not specified — ensures all resources have cost attribution"

  metadata = jsonencode({
    category = "Cost Governance"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      field  = "tags['CostCenter']"
      exists = "false"
    }
    then = {
      effect = "Append"
      details = [
        {
          field = "tags['CostCenter']"
          value = "UNASSIGNED-REVIEW-REQUIRED"
        }
      ]
    }
  })
}

resource "azurerm_management_group_policy_assignment" "append_costcenter_tag" {
  name                 = "append-costcenter"
  display_name         = "Append Default CostCenter Tag"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.append_costcenter_tag.id
}

# ------------------------------------------------------------
# POLICY 5: Audit Resources Without Owner Tag
# ------------------------------------------------------------

resource "azurerm_policy_definition" "audit_missing_owner_tag" {
  name         = "audit-missing-owner-tag"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Audit resources missing Owner tag"
  description  = "Flags resources that do not have an Owner tag for accountability"

  metadata = jsonencode({
    category = "Cost Governance"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      field  = "tags['Owner']"
      exists = "false"
    }
    then = {
      effect = "Audit"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "audit_missing_owner_tag" {
  name                 = "audit-owner-tag"
  display_name         = "Audit Missing Owner Tag"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.audit_missing_owner_tag.id
}

# ------------------------------------------------------------
# POLICY 6: Deny Dev/Test Resources in Production MG
# ------------------------------------------------------------

resource "azurerm_policy_definition" "deny_dev_in_prod" {
  name         = "deny-dev-environment-tag-in-prod"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Deny resources tagged as dev/test in Production scope"
  description  = "Prevents dev or test tagged workloads from being deployed in production landing zones"

  metadata = jsonencode({
    category = "Cost Governance"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      field  = "tags['Environment']"
      in     = ["dev", "test", "sandbox", "development"]
    }
    then = {
      effect = "Deny"
    }
  })
}

# Note: Assign only to Production MG, not Root
resource "azurerm_management_group_policy_assignment" "deny_dev_in_prod" {
  name                 = "deny-dev-in-prod"
  display_name         = "Deny Dev Resources in Production"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.deny_dev_in_prod.id
}

# ------------------------------------------------------------
# OUTPUTS
# ------------------------------------------------------------

output "require_tags_policy_id" {
  value = azurerm_policy_definition.require_tags_rg.id
}

output "allowed_vm_skus_policy_id" {
  value = azurerm_policy_definition.allowed_vm_skus.id
}
