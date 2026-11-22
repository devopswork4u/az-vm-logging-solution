output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace used for Linux VM syslogs."
  value       = local.log_analytics_workspace_id
}

output "data_collection_rule_id" {
  description = "Resource ID of the Linux VM data collection rule."
  value       = azurerm_monitor_data_collection_rule.linux_vm.id
}

output "policy_assignment_id" {
  description = "Resource ID of the subscription-scoped Linux VM logging policy assignment."
  value       = azurerm_subscription_policy_assignment.linux_vm.id
}

output "test_vm_id" {
  description = "Resource ID of the Ubuntu test VM, when created."
  value       = var.create_test_vm ? azurerm_linux_virtual_machine.test[0].id : null
}

output "test_vm_private_ip" {
  description = "Private IP address of the Ubuntu test VM, when created."
  value       = var.create_test_vm ? azurerm_network_interface.test_vm[0].private_ip_address : null
}

output "test_vm_public_ip" {
  description = "Public IP address of the Ubuntu test VM, when created."
  value       = var.create_test_vm ? azurerm_public_ip.test_vm[0].ip_address : null
}

output "policy_assignment_principal_id" {
  description = "Managed identity principal used by Azure Policy remediation."
  value       = azurerm_subscription_policy_assignment.linux_vm.identity[0].principal_id
}
