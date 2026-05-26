# ── Private DNS Zone for Azure Backup vault private endpoint ───────────────────
#
# privatelink.nzn.backup.windowsazure.com – backup service endpoint

resource "azurerm_private_dns_zone" "backup" {
  name                = "privatelink.nzn.backup.windowsazure.com"
  resource_group_name = module.resource_group.name
  tags                = local.tags

  depends_on = [module.resource_group]
}

# ── VNet link – backup zone linked to the existing VNet

resource "azurerm_private_dns_zone_virtual_network_link" "backup" {
  name                  = "pdnslink-${var.app_code}-backup-${local.region_code}-${var.environment}"
  resource_group_name   = module.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.backup.name
  virtual_network_id    = local.vnet_resource_id
  registration_enabled  = false
  tags                  = local.tags
}
