# -------------------------------------------------------------------------
# Pierre Mathieu
# Licensed under the MIT License. See License.txt in the project root for
# license information.
# --------------------------------------------------------------------------

# terraform/variables.tf

variable "project" {
  type = string
  description = "Project name"
}

variable "environment" {
  type = string
  description = "Environment (dev / stage / prod)"
}

variable "owner" {
  type = string
  description = "Project owner"
}
variable "location" {
  type = string
  description = "Azure region to deploy module to"
}

variable "failover_location" {
  type = string
  description = "Azure region for failovers"
  default = "East Us"
}


variable "subscription_id" {
  type = string
  description = "Azure Subscription"
}

variable "tenant_id" {
  type = string
  description = "Azure Tenant"
}

variable "client_id" {
  type = string
  description = "Azure Client"
}

variable "client_secret" {
  type = string
  description = "Azure client Secret"
}

