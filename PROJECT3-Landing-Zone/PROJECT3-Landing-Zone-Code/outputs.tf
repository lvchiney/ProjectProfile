output "root_management_group_id" {
  description = "Root management group ID"
  value       = module.management_groups.root_mg_id
}

output "platform_mg_id" {
  description = "Platform management group ID"
  value       = module.management_groups.platform_mg_id
}

output "landing_zones_mg_id" {
  description = "Landing Zones management group ID"
  value       = module.management_groups.landing_zones_mg_id
}

output "hub_vnet_id" {
  description = "Hub VNet resource ID"
  value       = module.networking.hub_vnet_id
}

output "prod_spoke_vnet_id" {
  description = "Production spoke VNet resource ID"
  value       = module.networking.prod_spoke_vnet_id
}

output "nonprod_spoke_vnet_id" {
  description = "Non-production spoke VNet resource ID"
  value       = module.networking.nonprod_spoke_vnet_id
}

output "log_analytics_workspace_id" {
  description = "Centralized Log Analytics workspace ID"
  value       = module.monitoring.log_analytics_workspace_id
}

output "log_analytics_workspace_key" {
  description = "Log Analytics workspace primary key"
  value       = module.monitoring.log_analytics_workspace_key
  sensitive   = true
}

output "firewall_public_ip" {
  description = "Azure Firewall public IP address"
  value       = module.networking.firewall_public_ip
}
