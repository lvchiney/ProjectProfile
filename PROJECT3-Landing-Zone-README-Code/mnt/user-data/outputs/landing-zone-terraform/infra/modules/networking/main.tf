# ─────────────────────────────────────────────────────
# Hub-Spoke Network Topology
#
# Connectivity Subscription:
#   Hub VNet → Azure Firewall + Gateway Subnet
#
# Production Subscription:
#   Spoke VNet → peered to Hub
#
# Non-Production Subscription:
#   Spoke VNet → peered to Hub
# ─────────────────────────────────────────────────────

# ── Resource Group (Connectivity Subscription) ────────
resource "azurerm_resource_group" "connectivity" {
  provider = azurerm.connectivity
  name     = "rg-connectivity"
  location = var.location
  tags     = var.tags
}

# ── Hub VNet ──────────────────────────────────────────
resource "azurerm_virtual_network" "hub" {
  provider            = azurerm.connectivity
  name                = "vnet-hub"
  location            = var.location
  resource_group_name = azurerm_resource_group.connectivity.name
  address_space       = [var.hub_vnet_address_space]
  tags                = var.tags
}

# Subnet for Azure Firewall — name must be exactly "AzureFirewallSubnet"
resource "azurerm_subnet" "firewall" {
  provider             = azurerm.connectivity
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.connectivity.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Subnet for VPN / ExpressRoute Gateway
resource "azurerm_subnet" "gateway" {
  provider             = azurerm.connectivity
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.connectivity.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.2.0/24"]
}

# ── Azure Firewall ────────────────────────────────────
resource "azurerm_public_ip" "firewall" {
  provider            = azurerm.connectivity
  name                = "pip-firewall-hub"
  location            = var.location
  resource_group_name = azurerm_resource_group.connectivity.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall" "hub" {
  provider            = azurerm.connectivity
  name                = "fw-hub"
  location            = var.location
  resource_group_name = azurerm_resource_group.connectivity.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  ip_configuration {
    name                 = "fw-ip-config"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  tags = var.tags
}

# ── Production Spoke VNet ─────────────────────────────
resource "azurerm_resource_group" "prod_network" {
  provider = azurerm.production
  name     = "rg-network-prod"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "prod_spoke" {
  provider            = azurerm.production
  name                = "vnet-spoke-prod"
  location            = var.location
  resource_group_name = azurerm_resource_group.prod_network.name
  address_space       = [var.prod_spoke_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "prod_app" {
  provider             = azurerm.production
  name                 = "snet-app-prod"
  resource_group_name  = azurerm_resource_group.prod_network.name
  virtual_network_name = azurerm_virtual_network.prod_spoke.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "prod_data" {
  provider             = azurerm.production
  name                 = "snet-data-prod"
  resource_group_name  = azurerm_resource_group.prod_network.name
  virtual_network_name = azurerm_virtual_network.prod_spoke.name
  address_prefixes     = ["10.1.2.0/24"]
}

# ── Non-Production Spoke VNet ─────────────────────────
resource "azurerm_resource_group" "nonprod_network" {
  provider = azurerm.nonproduction
  name     = "rg-network-nonprod"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "nonprod_spoke" {
  provider            = azurerm.nonproduction
  name                = "vnet-spoke-nonprod"
  location            = var.location
  resource_group_name = azurerm_resource_group.nonprod_network.name
  address_space       = [var.nonprod_spoke_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "nonprod_app" {
  provider             = azurerm.nonproduction
  name                 = "snet-app-nonprod"
  resource_group_name  = azurerm_resource_group.nonprod_network.name
  virtual_network_name = azurerm_virtual_network.nonprod_spoke.name
  address_prefixes     = ["10.2.1.0/24"]
}

# ── VNet Peering: Hub ↔ Production Spoke ─────────────
resource "azurerm_virtual_network_peering" "hub_to_prod" {
  provider                     = azurerm.connectivity
  name                         = "peer-hub-to-prod"
  resource_group_name          = azurerm_resource_group.connectivity.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.prod_spoke.id
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "prod_to_hub" {
  provider                     = azurerm.production
  name                         = "peer-prod-to-hub"
  resource_group_name          = azurerm_resource_group.prod_network.name
  virtual_network_name         = azurerm_virtual_network.prod_spoke.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# ── VNet Peering: Hub ↔ Non-Production Spoke ─────────
resource "azurerm_virtual_network_peering" "hub_to_nonprod" {
  provider                     = azurerm.connectivity
  name                         = "peer-hub-to-nonprod"
  resource_group_name          = azurerm_resource_group.connectivity.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.nonprod_spoke.id
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "nonprod_to_hub" {
  provider                     = azurerm.nonproduction
  name                         = "peer-nonprod-to-hub"
  resource_group_name          = azurerm_resource_group.nonprod_network.name
  virtual_network_name         = azurerm_virtual_network.nonprod_spoke.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
