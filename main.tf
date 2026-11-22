terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
}

resource "azurerm_resource_provider_registration" "policy_insights" {
  name = "Microsoft.PolicyInsights"
}

resource "azurerm_resource_group" "target" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_log_analytics_workspace" "linux_vm" {
  count = var.log_analytics_workspace_id == null || trimspace(var.log_analytics_workspace_id) == "" ? 1 : 0

  name                = var.log_analytics_workspace_name
  resource_group_name = azurerm_resource_group.target.name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
  tags                = var.tags
}

locals {
  log_analytics_workspace_id = (
    var.log_analytics_workspace_id != null && trimspace(var.log_analytics_workspace_id) != ""
    ? var.log_analytics_workspace_id
    : azurerm_log_analytics_workspace.linux_vm[0].id
  )
}

resource "azurerm_monitor_data_collection_rule" "linux_vm" {
  name                = var.data_collection_rule_name
  resource_group_name = azurerm_resource_group.target.name
  location            = var.location
  kind                = "Linux"
  tags                = var.tags

  destinations {
    log_analytics {
      name                  = "la-linux-vm-logs"
      workspace_resource_id = local.log_analytics_workspace_id
    }
  }

  data_sources {
    syslog {
      name           = "linuxSyslogDataSource"
      streams        = ["Microsoft-Syslog"]
      facility_names = ["*"]
      log_levels     = ["*"]
    }
  }

  data_flow {
    streams      = ["Microsoft-Syslog"]
    destinations = ["la-linux-vm-logs"]
  }
}

resource "azurerm_policy_definition" "linux_vm_logging" {
  name         = "deploy-linux-vm-monitoring-${var.resource_group_name}"
  display_name = "Deploy Linux VM logging with Azure Monitor Agent"
  description  = "Enables Azure Monitor Agent, a system-assigned identity, and the Linux syslog DCR for Linux virtual machines."
  policy_type  = "Custom"
  mode         = "Indexed"

  parameters = jsonencode({
    dcrResourceId = {
      type = "String"
      metadata = {
        displayName = "Linux VM data collection rule resource ID"
        description = "The DCR that receives Linux syslog data."
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
          field  = "Microsoft.Compute/virtualMachines/storageProfile.osDisk.osType"
          equals = "Linux"
        }
      ]
    }
    then = {
      effect = "DeployIfNotExists"
      details = {
        type = "Microsoft.Compute/virtualMachines"
        roleDefinitionIds = [
          "/providers/Microsoft.Authorization/roleDefinitions/9980e02c-c2be-4d73-94e8-173b1dc7cf3d",
          "/providers/Microsoft.Authorization/roleDefinitions/749f88d5-cbae-40b8-bcfc-e573ddc772fa"
        ]
        existenceCondition = {
          allOf = [
            {
              field  = "Microsoft.Compute/virtualMachines/extensions/type"
              equals = "AzureMonitorLinuxAgent"
            },
            {
              field  = "Microsoft.Compute/virtualMachines/extensions/publisher"
              equals = "Microsoft.Azure.Monitor"
            }
          ]
        }
        deployment = {
          properties = {
            mode = "Incremental"
            parameters = {
              vmResourceId = {
                value = "[field('id')]"
              }
              vmName = {
                value = "[field('name')]"
              }
              location = {
                value = azurerm_resource_group.target.location
              }
              dcrResourceId = {
                value = "[parameters('dcrResourceId')]"
              }
              resourceGroupName = {
                value = "[resourceGroup().name]"
              }
            }
            template = {
              "$schema"        = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
              "contentVersion" = "1.0.0.0"
              parameters = {
                vmResourceId = {
                  type = "string"
                }
                vmName = {
                  type = "string"
                }
                location = {
                  type = "string"
                }
                dcrResourceId = {
                  type = "string"
                }
                resourceGroupName = {
                  type = "string"
                }
              }
              resources = [
                {
                  type       = "Microsoft.Compute/virtualMachines"
                  apiVersion = "2024-03-01"
                  name       = "[parameters('vmName')]"
                  location   = "[parameters('location')]"
                  identity = {
                    type = "SystemAssigned"
                  }
                  properties = {}
                },
                {
                  type       = "Microsoft.Compute/virtualMachines/extensions"
                  apiVersion = "2024-03-01"
                  name       = "[concat(parameters('vmName'), '/AzureMonitorLinuxAgent')]"
                  location   = "[parameters('location')]"
                  dependsOn = [
                    "[concat('Microsoft.Compute/virtualMachines/', parameters('vmName'))]"
                  ]
                  properties = {
                    publisher               = "Microsoft.Azure.Monitor"
                    type                    = "AzureMonitorLinuxAgent"
                    typeHandlerVersion      = "1.34"
                    autoUpgradeMinorVersion = true
                    enableAutomaticUpgrade  = true
                  }
                },
                {
                  type       = "Microsoft.Insights/dataCollectionRuleAssociations"
                  apiVersion = "2022-06-01"
                  name       = "[concat(parameters('vmName'), '-linux-syslog-dcra')]"
                  scope      = "[parameters('vmResourceId')]"
                  dependsOn = [
                    "[concat('Microsoft.Compute/virtualMachines/', parameters('vmName'), '/extensions/AzureMonitorLinuxAgent')]"
                  ]
                  properties = {
                    dataCollectionRuleId = "[parameters('dcrResourceId')]"
                  }
                }
              ]
            }
          }
        }
      }
    }
  })
}

resource "azurerm_subscription_policy_assignment" "linux_vm" {
  name                 = var.policy_assignment_name
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = azurerm_policy_definition.linux_vm_logging.id
  description          = "Deploy Azure Monitor Agent and Linux syslog DCR association to Linux VMs across the subscription."
  display_name         = "Enable Linux VM logging"
  location             = var.location

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    dcrResourceId = {
      value = azurerm_monitor_data_collection_rule.linux_vm.id
    }
  })

  depends_on = [azurerm_resource_provider_registration.policy_insights]
}

resource "azurerm_role_assignment" "policy_virtual_machine_contributor" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_subscription_policy_assignment.linux_vm.identity[0].principal_id
}

resource "azurerm_role_assignment" "policy_monitoring_contributor" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Monitoring Contributor"
  principal_id         = azurerm_subscription_policy_assignment.linux_vm.identity[0].principal_id
}

resource "azurerm_subscription_policy_remediation" "linux_vm" {
  name                 = "remediate-linux-vm-logging"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_assignment_id = azurerm_subscription_policy_assignment.linux_vm.id

  resource_discovery_mode = "ExistingNonCompliant"

  depends_on = [
    azurerm_resource_provider_registration.policy_insights,
    azurerm_role_assignment.policy_virtual_machine_contributor,
    azurerm_role_assignment.policy_monitoring_contributor
  ]
}

resource "azurerm_virtual_network" "test_vm" {
  count = var.create_test_vm ? 1 : 0

  name                = "vnet-linux-vm-test"
  address_space       = ["10.246.0.0/16"]
  location            = azurerm_resource_group.target.location
  resource_group_name = azurerm_resource_group.target.name
  tags                = var.tags
}

resource "azurerm_subnet" "test_vm" {
  count = var.create_test_vm ? 1 : 0

  name                 = "snet-linux-vm-test"
  resource_group_name  = azurerm_resource_group.target.name
  virtual_network_name = azurerm_virtual_network.test_vm[0].name
  address_prefixes     = ["10.246.1.0/24"]
}

resource "azurerm_public_ip" "test_vm" {
  count = var.create_test_vm ? 1 : 0

  name                = "pip-${var.test_vm_name}"
  location            = azurerm_resource_group.target.location
  resource_group_name = azurerm_resource_group.target.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "test_vm" {
  count = var.create_test_vm ? 1 : 0

  name                = "nic-${var.test_vm_name}"
  location            = azurerm_resource_group.target.location
  resource_group_name = azurerm_resource_group.target.name
  tags                = var.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.test_vm[0].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.test_vm[0].id
  }
}

resource "azurerm_linux_virtual_machine" "test" {
  count = var.create_test_vm ? 1 : 0

  name                            = var.test_vm_name
  resource_group_name             = azurerm_resource_group.target.name
  location                        = azurerm_resource_group.target.location
  size                            = var.test_vm_size
  admin_username                  = var.test_vm_admin_username
  admin_password                  = var.test_vm_admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.test_vm[0].id]
  tags                            = var.tags

  os_disk {
    name                 = "osdisk-${var.test_vm_name}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  depends_on = [
    azurerm_subscription_policy_assignment.linux_vm,
    azurerm_role_assignment.policy_virtual_machine_contributor,
    azurerm_role_assignment.policy_monitoring_contributor
  ]
}
