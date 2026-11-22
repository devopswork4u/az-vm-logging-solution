# Linux VM logging

This module enables Linux VM syslog collection with Azure Monitor Agent and Azure Policy.

- Creates a Log Analytics workspace unless `log_analytics_workspace_id` is supplied.
- Creates a Linux data collection rule that sends all syslog facilities and levels to Log Analytics.
- Registers `Microsoft.PolicyInsights` and assigns a custom DeployIfNotExists policy at subscription scope, covering Linux VMs in every resource group in the subscription.
- Adds a system-assigned identity to Linux VMs when one is missing.
- Installs `AzureMonitorLinuxAgent` and associates the VM with the DCR.
- Remediates existing noncompliant VMs; the policy handles future Linux VM deployments.

```hcl
module "az-vm-logging-solution" {
  source = "./logging"

  subscription_id           = var.subscription_id
  resource_group_name       = azurerm_resource_group.main.name
  location                  = azurerm_resource_group.main.location
  log_analytics_workspace_name = "law-linux-vm-logs"
  create_test_vm               = true
}
```

To use an existing workspace, set `log_analytics_workspace_id` instead of creating a new one. The module does not configure guest logs with `azurerm_monitor_diagnostic_setting`; Linux syslog collection is configured through the DCR and DCR association, which is the Azure Monitor Agent mechanism.

The module creates an Ubuntu 22.04 test VM by default. Set `create_test_vm = false` to skip it. The test VM has a public Standard SKU IP and also requires explicit NSG or firewall rules for inbound access. Use the `test_vm_id`, `test_vm_private_ip`, and `test_vm_public_ip` outputs to verify deployment.
