output "resource_group" {
  value = azurerm_resource_group.this.name
}

output "vnet" {
  value = azurerm_virtual_network.this.name
}

output "subnets" {
  value = {
    web = local.web_cidr
    app = local.app_cidr
    db  = local.db_cidr
  }
}
