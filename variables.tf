variable "subscription_id" {
  description = "Azure subscription containing the VMs and logging resources."
  type        = string
  default     = "d7948271-885c-4a73-a883-cf1b0a2f8696"
}

variable "resource_group_name" {
  description = "Existing resource group containing the Log Analytics workspace and target Linux VMs."
  type        = string
  default     = "rg-linux-vm-logging"
}

variable "location" {
  description = "Azure region for the data collection rule."
  type        = string
  default     = "canadacentral"
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace to create for Linux VM syslogs."
  type        = string
  default     = "law-linux-vm-logs"
}

variable "log_analytics_workspace_id" {
  description = "Optional existing Log Analytics workspace resource ID. When empty, the module creates the workspace."
  type        = string
  default     = null
}

variable "log_analytics_retention_days" {
  description = "Log Analytics workspace retention in days."
  type        = number
  default     = 90
}

variable "data_collection_rule_name" {
  description = "Name of the Linux VM data collection rule."
  type        = string
  default     = "dcr-linux-vm-syslog"
}

variable "policy_assignment_name" {
  description = "Name of the Azure Policy assignment."
  type        = string
  default     = "enable-linux-vm-logging"
}

variable "tags" {
  description = "Tags applied to supported logging resources."
  type        = map(string)
  default     = {}
}

variable "create_test_vm" {
  description = "Create a private Ubuntu test VM to verify Azure Policy logging remediation."
  type        = bool
  default     = true
}

variable "test_vm_name" {
  description = "Name of the Ubuntu test VM."
  type        = string
  default     = "vm-linux-logging-test"
}

variable "test_vm_size" {
  description = "Azure VM SKU for the logging test VM."
  type        = string
  default     = "Standard_B2s"
}

variable "test_vm_admin_username" {
  description = "Admin username for the Ubuntu test VM."
  type        = string
  default     = "azureadmin"
}

variable "test_vm_admin_password" {
  description = "Admin password for the Ubuntu test VM."
  type        = string
  default     = "P@ssw0rd1234!"
}
