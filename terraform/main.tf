# -------------------------------------------------------------------------
# Pierre Mathieu
# # Licensed under the MIT License. See License.txt in the project root for
# license information.
# --------------------------------------------------------------------------

# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {
       key_vault {
      purge_soft_delete_on_destroy = false
    }
  }


  subscription_id   = var.subscription_id
  tenant_id         = var.tenant_id
  client_id         = var.client_id
  client_secret     = var.client_secret
}

data "azurerm_client_config" "current" {}

# Create a resource group
resource "azurerm_resource_group" "poc-resource-grp" {
  name = "${var.project}-${var.environment}-resource-group"
  location = var.location
  tags = {
    "environment" = "dev"
    "owner"       = "poc-owner"
  }
}


# Create internal Storage Account, Storage Container.
resource "azurerm_storage_account" "companypocstorageacct" {
  name                     = "${var.project}${var.environment}storageacct"
  resource_group_name = azurerm_resource_group.poc-resource-grp.name
  location            = azurerm_resource_group.poc-resource-grp.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "poc-storage-container" {
  name                  = "${var.project}-${var.environment}-storage-container"
  storage_account_name  = azurerm_storage_account.companypocstorageacct.name
  container_access_type = "private"
}



# Create customer facing Storage Account, Storage Container, and drop an encrypted blob in the container
resource "azurerm_storage_account" "customerpocstorageacct" {
  name                     = "${var.project}${var.environment}custstorageacct"
  resource_group_name = azurerm_resource_group.poc-resource-grp.name
  location            = azurerm_resource_group.poc-resource-grp.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "customer-storage-container" {
  name                  = "${var.project}${var.environment}-customer-storage-container"
  storage_account_name  = azurerm_storage_account.customerpocstorageacct.name
  container_access_type = "private"
}


resource "azurerm_key_vault" "pockeyvault" {
  name                        = "${var.project}${var.environment}keyvault2021"
  location                    = azurerm_resource_group.poc-resource-grp.location
  resource_group_name         = azurerm_resource_group.poc-resource-grp.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "create",
      "get",
      "purge",
      "recover",
    ]

    secret_permissions = [
      "get",
      "set",
      "list",

    ]

    storage_permissions = [
      "get",
      "set",
      "list",
    ]
  }
}
  resource "azurerm_key_vault_access_policy" "ownerpolicy" {
  key_vault_id = azurerm_key_vault.pockeyvault.id
  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id

  key_permissions = [
      "create",
      "get",
      "purge",
      "recover",
    ]

    secret_permissions = [
      "get",
      "set",
      "list",

    ]

    storage_permissions = [
      "get",
      "set",
      "list",
    ]
}



resource "azurerm_servicebus_namespace" "companyservicebusnp" {
  name                = "${var.project}${var.environment}-servicebus-namespace"
  location                    = azurerm_resource_group.poc-resource-grp.location
  resource_group_name         = azurerm_resource_group.poc-resource-grp.name
  sku                 = "Standard"

  tags = {
    "environment" = "dev"
    "owner"       = "poc-owner"
  }
}

resource "azurerm_servicebus_queue" "companyservicebusqueue" {
  name                = "${var.project}${var.environment}_servicebus_queue"
  resource_group_name = azurerm_resource_group.poc-resource-grp.name
  namespace_name      = azurerm_servicebus_namespace.companyservicebusnp.name

  enable_partitioning = true
}


# Create Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "pocloganalyticswp" {
  name                = "${var.project}${var.environment}logwp"
  location            = azurerm_resource_group.poc-resource-grp.location
  resource_group_name = azurerm_resource_group.poc-resource-grp.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_storage_account" "pocloganalyticswpacct" {
  name                     = "${var.project}${var.environment}logswpacct"
  resource_group_name      = azurerm_resource_group.poc-resource-grp.name
  location                 = azurerm_resource_group.poc-resource-grp.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_log_analytics_storage_insights" "poclogstorageinsights" {
  name                = "${var.project}${var.environment}-storageinsightconfig"
  resource_group_name = azurerm_resource_group.poc-resource-grp.name
  workspace_id        = azurerm_log_analytics_workspace.pocloganalyticswp.id

  storage_account_id  = azurerm_storage_account.pocloganalyticswpacct.id
  storage_account_key = azurerm_storage_account.pocloganalyticswpacct.primary_access_key
}


# Create Logic Apps Workflow and Trigger Recurrence every 4 hours
resource "azurerm_logic_app_workflow" "poctimerlogicappwf" {
  name                = "${var.project}${var.environment}-timer-logicappwf"
  location            = azurerm_resource_group.poc-resource-grp.location
  resource_group_name = azurerm_resource_group.poc-resource-grp.name
}

resource "azurerm_logic_app_trigger_recurrence" "timerlogicapptrigger" {
  name         = "${var.project}${var.environment}logicapptrigger-periodic"
  logic_app_id = azurerm_logic_app_workflow.poctimerlogicappwf.id
   frequency    = "Hour"
   interval     = 4
   start_time  = "2021-08-25T03:04:05Z"
}



resource "azurerm_logic_app_workflow" "pocbloblogicappwf" {
  name                = "${var.project}${var.environment}-blob-logicappwf"
  location            = azurerm_resource_group.poc-resource-grp.location
  resource_group_name = azurerm_resource_group.poc-resource-grp.name
}

resource "azurerm_storage_account" "func_storage_account" {
  name = "${var.project}${var.environment}storage2021"
  resource_group_name =  azurerm_resource_group.poc-resource-grp.name
  location = var.location
  account_tier = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_app_service_plan" "app_service_plan" {
  name                = "${var.project}${var.environment}-app-service-plan"
  resource_group_name = azurerm_resource_group.poc-resource-grp.name
  location            = var.location
  kind                = "FunctionApp"
  reserved = true 
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}


resource "azurerm_function_app" "function_app" {
  name                       = "${var.project}${var.environment}-function-app"
  resource_group_name        = azurerm_resource_group.poc-resource-grp.name
  location                   = var.location
  app_service_plan_id        = azurerm_app_service_plan.app_service_plan.id
  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE" = "",
    "FUNCTIONS_WORKER_RUNTIME" = "python",
    "APP_TOKEN_VALUE" = "",
    "FILE_ENCRYPTION_KEY" = "",
    "AZURE_STORAGE_CONNECTION_STRING" = "", 
    "AZURE_INTERNAL_STORAGE_CONNECTION_STRING"  = "",
    "SERVICE_BUS_CONNECTION_STR" = "",
    "SERVICE_BUS_QUEUE_NAME" = ""
    }
  os_type = "linux"
  site_config {
    linux_fx_version          = "python|3.9"
    use_32_bit_worker_process = false
  }
  storage_account_name       = azurerm_storage_account.func_storage_account.name
  storage_account_access_key = azurerm_storage_account.func_storage_account.primary_access_key
  version                    = "~3"

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }
}

resource "azurerm_api_management" "apim" {
  name                = "${var.project}${var.environment}-apim"
  resource_group_name = azurerm_resource_group.poc-resource-grp.name
  location            = var.location
  publisher_name      = var.company
  publisher_email     = var.email

  sku_name = "Developer_1"
}


resource "azurerm_api_management_api" "api_management_api_public" {
  name                  = "${var.project}-${var.environment}-api-management-api-public"
  resource_group_name = azurerm_resource_group.poc-resource-grp.name
  api_management_name = azurerm_api_management.apim.name
  revision              = "1"
  display_name          = "Public"
  path                  = ""
  protocols             = ["https"]
  service_url           = "https://${azurerm_function_app.function_app.default_hostname}/api"
  subscription_required = false
}


resource "azurerm_api_management_api_operation" "api_management_api_operation_sas_token_gen" {
  operation_id        = "sas-token-generator"
  api_name            = azurerm_api_management_api.api_management_api_public.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name =  azurerm_resource_group.poc-resource-grp.name
  display_name        = "SAS token Generation API endpoint"
  method              = "GET"
  url_template        = "/SASTokenGenerator"
}