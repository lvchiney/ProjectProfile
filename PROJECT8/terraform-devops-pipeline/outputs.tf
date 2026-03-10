output "resource_group_id" {
  description = "The ID of the created resource group"
  value       = module.resource_group.id
}

output "resource_group_name" {
  description = "The name of the created resource group"
  value       = module.resource_group.name
}
