
# ============================================================
# Module: Network Security Policies
# Scope: Landing Zones Management Group
# ============================================================

# ------------------------------------------------------------
# POLICY 1: Deny Public IP Addresses
# ------------------------------------------------------------

resource "azurerm_policy_definition" "deny_public_ip" {
  name         = "deny-public-ip-addresses"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Deny creation of Public IP Addresses"
  description  = "Prevents creation of public IP addresses to enforce private-only connectivity"

  metadata = jsonencode({
    category = "Network Security"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      field  = "type"
      equals = "Microsoft.Network/publicIPAddresses"
    }
    then = {
      effect = "Deny"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "deny_public_ip" {
  name                 = "deny-public-ip"
  display_name         = "Deny Public IP Addresses"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.deny_public_ip.id
  description          = "Enforces private-only connectivity across all landing zones"
}

# ------------------------------------------------------------
# POLICY 2: Require NSG on Every Subnet
# ------------------------------------------------------------

resource "azurerm_policy_definition" "require_nsg" {
  name         = "require-nsg-on-subnet"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Require NSG on every subnet"
  description  = "Audits subnets that do not have a Network Security Group attached"

  metadata = jsonencode({
    category = "Network Security"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Network/virtualNetworks/subnets"
        },
        {
          field  = "name"
          notIn  = ["AzureFirewallSubnet", "GatewaySubnet", "AzureBastionSubnet", "AzureFirewallManagementSubnet"]
        },
        {
          field  = "Microsoft.Network/virtualNetworks/subnets/networkSecurityGroup.id"
          exists = "false"
        }
      ]
    }
    then = {
      effect = "Deny"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "require_nsg" {
  name                 = "require-nsg-subnet"
  display_name         = "Require NSG on Subnets"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.require_nsg.id
}

# ------------------------------------------------------------
# POLICY 3: Deny Inbound RDP from Internet (Port 3389)
# ------------------------------------------------------------

resource "azurerm_policy_definition" "deny_rdp_internet" {
  name         = "deny-rdp-from-internet"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Deny RDP access from Internet"
  description  = "Blocks NSG rules that allow inbound RDP (3389) from the internet"

  metadata = jsonencode({
    category = "Network Security"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Network/networkSecurityGroups/securityRules"
        },
        {
          allOf = [
            {
              field  = "Microsoft.Network/networkSecurityGroups/securityRules/access"
              equals = "Allow"
            },
            {
              field  = "Microsoft.Network/networkSecurityGroups/securityRules/direction"
              equals = "Inbound"
            },
            {
              anyOf = [
                {
                  field  = "Microsoft.Network/networkSecurityGroups/securityRules/destinationPortRange"
                  equals = "3389"
                },
                {
                  field  = "Microsoft.Network/networkSecurityGroups/securityRules/destinationPortRange"
                  equals = "*"
                }
              ]
            },
            {
              anyOf = [
                {
                  field  = "Microsoft.Network/networkSecurityGroups/securityRules/sourceAddressPrefix"
                  equals = "*"
                },
                {
                  field  = "Microsoft.Network/networkSecurityGroups/securityRules/sourceAddressPrefix"
                  equals = "Internet"
                }
              ]
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

resource "azurerm_management_group_policy_assignment" "deny_rdp_internet" {
  name                 = "deny-rdp-internet"
  display_name         = "Deny RDP from Internet"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.deny_rdp_internet.id
}

# ------------------------------------------------------------
# POLICY 4: Deny Inbound SSH from Internet (Port 22)
# ------------------------------------------------------------

resource "azurerm_policy_definition" "deny_ssh_internet" {
  name         = "deny-ssh-from-internet"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Deny SSH access from Internet"
  description  = "Blocks NSG rules that allow inbound SSH (22) from the internet"

  metadata = jsonencode({
    category = "Network Security"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Network/networkSecurityGroups/securityRules"
        },
        {
          allOf = [
            {
              field  = "Microsoft.Network/networkSecurityGroups/securityRules/access"
              equals = "Allow"
            },
            {
              field  = "Microsoft.Network/networkSecurityGroups/securityRules/direction"
              equals = "Inbound"
            },
            {
              field  = "Microsoft.Network/networkSecurityGroups/securityRules/destinationPortRange"
              equals = "22"
            },
            {
              anyOf = [
                {
                  field  = "Microsoft.Network/networkSecurityGroups/securityRules/sourceAddressPrefix"
                  equals = "*"
                },
                {
                  field  = "Microsoft.Network/networkSecurityGroups/securityRules/sourceAddressPrefix"
                  equals = "Internet"
                }
              ]
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

resource "azurerm_management_group_policy_assignment" "deny_ssh_internet" {
  name                 = "deny-ssh-internet"
  display_name         = "Deny SSH from Internet"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.deny_ssh_internet.id
}

# ------------------------------------------------------------
# POLICY 5: Allowed Locations (Data Residency)
# ------------------------------------------------------------

resource "azurerm_policy_definition" "allowed_locations" {
  name         = "allowed-resource-locations"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Allowed Azure Regions for Resource Deployment"
  description  = "Restricts resource deployment to approved Azure regions only"

  metadata = jsonencode({
    category = "Network Security"
    version  = "1.0.0"
  })

  parameters = jsonencode({
    allowedLocations = {
      type = "Array"
      metadata = {
        displayName = "Allowed Locations"
        description = "List of approved Azure regions"
        strongType  = "location"
      }
    }
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field = "location"
          notIn = "[parameters('allowedLocations')]"
        },
        {
          field    = "location"
          notEquals = "global"
        }
      ]
    }
    then = {
      effect = "Deny"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  display_name         = "Allowed Azure Regions"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.allowed_locations.id

  parameters = jsonencode({
    allowedLocations = {
      value = var.allowed_locations
    }
  })
}

# ------------------------------------------------------------
# OUTPUTS
# ------------------------------------------------------------

output "deny_public_ip_policy_id" {
  value = azurerm_policy_definition.deny_public_ip.id
}

output "require_nsg_policy_id" {
  value = azurerm_policy_definition.require_nsg.id
}
