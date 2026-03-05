
# ============================================================
# Module: Data Protection Policies
# Scope: Landing Zones Management Group
# ============================================================

# ------------------------------------------------------------
# POLICY 1: Deny HTTP (Require HTTPS) on Web Apps
# ------------------------------------------------------------

resource "azurerm_policy_definition" "deny_http" {
  name         = "deny-http-web-apps"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Deny HTTP — Enforce HTTPS on Web Apps"
  description  = "Ensures all App Services enforce HTTPS-only traffic"

  metadata = jsonencode({
    category = "Data Protection"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Web/sites"
        },
        {
          anyOf = [
            {
              field    = "Microsoft.Web/sites/httpsOnly"
              exists   = "false"
            },
            {
              field  = "Microsoft.Web/sites/httpsOnly"
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

resource "azurerm_management_group_policy_assignment" "deny_http" {
  name                 = "deny-http-webapps"
  display_name         = "Enforce HTTPS on Web Apps"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.deny_http.id
}

# ------------------------------------------------------------
# POLICY 2: Require Encryption at Rest on Storage Accounts
# ------------------------------------------------------------

resource "azurerm_policy_definition" "require_encryption" {
  name         = "require-storage-encryption"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Require encryption at rest on Storage Accounts"
  description  = "Ensures all storage accounts have encryption at rest enabled"

  metadata = jsonencode({
    category = "Data Protection"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Storage/storageAccounts"
        },
        {
          anyOf = [
            {
              field    = "Microsoft.Storage/storageAccounts/encryption.services.blob.enabled"
              notEquals = "true"
            },
            {
              field    = "Microsoft.Storage/storageAccounts/encryption.services.file.enabled"
              notEquals = "true"
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

resource "azurerm_management_group_policy_assignment" "require_encryption" {
  name                 = "require-storage-enc"
  display_name         = "Require Storage Encryption at Rest"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.require_encryption.id
}

# ------------------------------------------------------------
# POLICY 3: Deny Storage Account Public Blob Access
# ------------------------------------------------------------

resource "azurerm_policy_definition" "deny_storage_public_access" {
  name         = "deny-storage-public-access"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Deny public blob access on Storage Accounts"
  description  = "Prevents storage accounts from allowing anonymous/public blob access"

  metadata = jsonencode({
    category = "Data Protection"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Storage/storageAccounts"
        },
        {
          field  = "Microsoft.Storage/storageAccounts/allowBlobPublicAccess"
          equals = "true"
        }
      ]
    }
    then = {
      effect = "Deny"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "deny_storage_public_access" {
  name                 = "deny-storage-pub-access"
  display_name         = "Deny Storage Public Blob Access"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.deny_storage_public_access.id
}

# ------------------------------------------------------------
# POLICY 4: Require Key Vault Soft Delete
# ------------------------------------------------------------

resource "azurerm_policy_definition" "require_kv_soft_delete" {
  name         = "require-keyvault-soft-delete"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Require soft delete on Key Vaults"
  description  = "Ensures Key Vaults have soft delete enabled to prevent accidental deletion"

  metadata = jsonencode({
    category = "Data Protection"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.KeyVault/vaults"
        },
        {
          anyOf = [
            {
              field    = "Microsoft.KeyVault/vaults/enableSoftDelete"
              exists   = "false"
            },
            {
              field  = "Microsoft.KeyVault/vaults/enableSoftDelete"
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

resource "azurerm_management_group_policy_assignment" "require_kv_soft_delete" {
  name                 = "require-kv-soft-delete"
  display_name         = "Require Key Vault Soft Delete"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.require_kv_soft_delete.id
}

# ------------------------------------------------------------
# POLICY 5: Require Key Vault Purge Protection
# ------------------------------------------------------------

resource "azurerm_policy_definition" "require_kv_purge_protection" {
  name         = "require-keyvault-purge-protection"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Require purge protection on Key Vaults"
  description  = "Ensures Key Vaults have purge protection enabled"

  metadata = jsonencode({
    category = "Data Protection"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.KeyVault/vaults"
        },
        {
          anyOf = [
            {
              field    = "Microsoft.KeyVault/vaults/enablePurgeProtection"
              exists   = "false"
            },
            {
              field  = "Microsoft.KeyVault/vaults/enablePurgeProtection"
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

resource "azurerm_management_group_policy_assignment" "require_kv_purge_protection" {
  name                 = "require-kv-purge"
  display_name         = "Require Key Vault Purge Protection"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.require_kv_purge_protection.id
}

# ------------------------------------------------------------
# POLICY 6: Require Minimum TLS 1.2 on Storage
# ------------------------------------------------------------

resource "azurerm_policy_definition" "require_tls12_storage" {
  name         = "require-tls12-storage"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Require minimum TLS 1.2 on Storage Accounts"
  description  = "Enforces TLS 1.2 as minimum version for storage account connections"

  metadata = jsonencode({
    category = "Data Protection"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Storage/storageAccounts"
        },
        {
          field    = "Microsoft.Storage/storageAccounts/minimumTlsVersion"
          notEquals = "TLS1_2"
        }
      ]
    }
    then = {
      effect = "Deny"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "require_tls12_storage" {
  name                 = "require-tls12-storage"
  display_name         = "Require TLS 1.2 on Storage"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.require_tls12_storage.id
}

# ------------------------------------------------------------
# OUTPUTS
# ------------------------------------------------------------

output "deny_http_policy_id" {
  value = azurerm_policy_definition.deny_http.id
}

output "require_encryption_policy_id" {
  value = azurerm_policy_definition.require_encryption.id
}
