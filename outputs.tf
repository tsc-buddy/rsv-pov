output "resource_group_name" {
  description = "Name of the resource group containing all backup resources."
  value       = module.resource_group.name
}

output "resource_group_id" {
  description = "Resource ID of the backup resource group."
  value       = module.resource_group.resource_id
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace."
  value       = module.log_analytics_workspace.resource_id
}

output "recovery_services_vault_id" {
  description = "Resource ID of the Recovery Services vault."
  value       = module.recovery_services_vault.resource_id
}

output "recovery_services_vault_name" {
  description = "Name of the Recovery Services vault."
  value       = module.recovery_services_vault.resource.name
}

output "action_group_ops_id" {
  description = "Resource ID of the backup operations action group."
  value       = azurerm_monitor_action_group.ops.id
}

output "action_group_security_id" {
  description = "Resource ID of the security / platform ops action group."
  value       = azurerm_monitor_action_group.security.id
}
