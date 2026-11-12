terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.38" }
    random  = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

# Subscription comes from ARM_SUBSCRIPTION_ID (run.ps1 sets it from `az login`).
provider "azurerm" {
  features {}
}

locals {
  name = "${var.workload}-${var.environment}"
  tags = merge({ workload = var.workload, environment = var.environment }, var.tags)

  web_cidr = cidrsubnet(var.vnet_cidr, 8, 1)
  app_cidr = cidrsubnet(var.vnet_cidr, 8, 2)
  db_cidr  = cidrsubnet(var.vnet_cidr, 8, 3)
}

#  Resource group 
resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name}"
  location = var.location
}

#  Network + 3 subnets 
resource "azurerm_virtual_network" "this" {
  name                = "vnet-${local.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = [var.vnet_cidr]
}

resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.web_cidr]
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.app_cidr]
}

resource "azurerm_subnet" "db" {
  name                 = "snet-db"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.db_cidr]
}

#  Tier 1: WEB  (internet -> 80/443) 
resource "azurerm_network_security_group" "web" {
  name                = "nsg-${local.name}-web"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location


  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = local.web_cidr
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = local.web_cidr
  }

  security_rule {
    name                       = "Allow-LB-Probe"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

#  Tier 2: COMPUTE  (web subnet -> app port only) 
resource "azurerm_network_security_group" "app" {
  name                = "nsg-${local.name}-app"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location


  security_rule {
    name                       = "Allow-Web-To-App"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = var.app_port
    source_address_prefix      = local.web_cidr
    destination_address_prefix = local.app_cidr
  }

  security_rule {
    name                       = "Allow-LB-Probe"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

#  Tier 3: DATABASE  (app subnet -> db port only) 
resource "azurerm_network_security_group" "db" {
  name                = "nsg-${local.name}-db"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location


  security_rule {
    name                       = "Allow-App-To-DB"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = var.db_port
    source_address_prefix      = local.app_cidr
    destination_address_prefix = local.db_cidr
  }

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_subnet_network_security_group_association" "db" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.db.id
}

#  Network monitor: Network Watcher + VNet flow logs 
resource "azurerm_network_watcher" "this" {
  count               = var.use_existing_network_watcher ? 0 : 1
  name                = "nw-${local.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

}

data "azurerm_network_watcher" "existing" {
  count               = var.use_existing_network_watcher ? 1 : 0
  name                = "NetworkWatcher_${var.location}"
  resource_group_name = "NetworkWatcherRG"
}

locals {
  nw_name = var.use_existing_network_watcher ? data.azurerm_network_watcher.existing[0].name : azurerm_network_watcher.this[0].name
  nw_rg   = var.use_existing_network_watcher ? data.azurerm_network_watcher.existing[0].resource_group_name : azurerm_network_watcher.this[0].resource_group_name
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

resource "azurerm_storage_account" "flowlogs" {
  name                            = substr("st${var.workload}${var.environment}fl${random_string.suffix.result}", 0, 24)
  resource_group_name             = azurerm_resource_group.this.name
  location                        = azurerm_resource_group.this.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = local.tags
}

resource "azurerm_network_watcher_flow_log" "vnet" {
  name                 = "fl-${local.name}"
  network_watcher_name = local.nw_name
  resource_group_name  = local.nw_rg
  target_resource_id   = azurerm_virtual_network.this.id
  storage_account_id   = azurerm_storage_account.flowlogs.id
  enabled              = true

  retention_policy {
    enabled = true
    days    = var.flow_log_days
  }

  tags = local.tags
}
