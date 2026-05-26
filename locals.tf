locals {
  region_code = "nzn" # New Zealand North

  resource_group_name     = "rg-${var.app_code}-backup-${var.environment}-${local.region_code}"
  vault_name              = "rsv-${var.app_code}-backup-${var.environment}-${local.region_code}"
  law_resource_group_name = "rg-ds-lz-prd-nzn"
  law_name                = "log-ds-prd-nzn"
  action_group_ops        = "ag-${var.app_code}-backup-ops-${local.region_code}-${var.environment}"
  action_group_sec        = "ag-${var.app_code}-backup-sec-${local.region_code}-${var.environment}"

  nz_timezone = "New Zealand Standard Time"

  default_tags = {
    workload      = var.workload
    managed_by    = "terraform"
  }
  tags = merge(local.default_tags, var.tags)

  # Derive the VNet resource ID from the subnet ID (strips /subnets/{name} suffix).
  # Used by the private DNS zone VNet links in private_endpoints.tf.
  vnet_resource_id = var.private_endpoint_subnet_id != "" ? join("/", slice(split("/", var.private_endpoint_subnet_id), 0, 9)) : ""

  # Private endpoint: always enabled per spec (public access disabled)
  vault_private_endpoints = var.private_endpoint_subnet_id != "" ? {
    "pe-${local.vault_name}" = {
      name                            = "pe-${local.vault_name}"
      subnet_resource_id              = var.private_endpoint_subnet_id
      subresource_name                = "AzureBackup"
      private_dns_zone_resource_ids   = toset(var.private_dns_zone_ids)
      private_service_connection_name = "psc-${local.vault_name}"
    }
  } : {}
}
