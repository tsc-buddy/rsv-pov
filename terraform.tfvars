# ==============================================================
# terraform.tfvars  –  Non-Production Environment
#
# Fill in all TODO values before running terraform plan/apply.
# ==============================================================

# ── Core ────────────────────────────────────────────────────
subscription_id = "<your-subscription-id>"
location        = "newzealandnorth"
environment     = "npd"
workload        = "backup"
app_code        = "ccc"

private_endpoint_subnet_id = "<subnet-resource-id>"

private_dns_zone_ids = []

# ── Log Analytics ────────────────────────────────────────────
log_analytics_retention_days = 90
enable_immutability = false

# ── Alerting ─────────────────────────────────────────────────
alert_email_receivers = [
  "ops@example.com",
]

alert_email_receivers_security = [
  "security@example.com",
]

# ── Tags ─────────────────────────────────────────────────────
tags = {
  ApplicationName = "<your-app-name>"
  CostCentre      = "<your-cost-centre>"
  ProductOwner    = "<product-owner>"
  SupportTeam     = "<support-team>"
  Environment     = "Production"
}
