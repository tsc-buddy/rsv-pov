# ── Log Analytics Resource Group ───────────────────────────────────────────────
resource "azurerm_resource_group" "law" {
  name     = local.law_resource_group_name
  location = var.location
  tags     = local.tags
}

# ── Log Analytics Workspace ────────────────────────────────────────────────────
module "log_analytics_workspace" {
  source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version = "~> 0.4"

  name                = local.law_name
  location            = var.location
  resource_group_name = azurerm_resource_group.law.name

  log_analytics_workspace_retention_in_days = var.log_analytics_retention_days

  tags = local.tags

  depends_on = [azurerm_resource_group.law]
}
