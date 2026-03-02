location           = "eastus"
secondary_location = "westus2"

allowed_regions = ["eastus", "westeurope"]

# ⚠️ Replace these with your real IDs
root_management_group_id     = "YOUR-TENANT-ID"
prod_subscription_id         = "YOUR-PROD-SUBSCRIPTION-ID"
nonprod_subscription_id      = "YOUR-NONPROD-SUBSCRIPTION-ID"
connectivity_subscription_id = "YOUR-CONNECTIVITY-SUBSCRIPTION-ID"
management_subscription_id   = "YOUR-MANAGEMENT-SUBSCRIPTION-ID"

# Azure AD Group Object IDs
security_team_object_id = "YOUR-SECURITY-TEAM-GROUP-OBJECT-ID"
platform_team_object_id = "YOUR-PLATFORM-TEAM-GROUP-OBJECT-ID"
dev_team_object_id      = "YOUR-DEV-TEAM-GROUP-OBJECT-ID"

# Networking
hub_vnet_address_space      = "10.0.0.0/16"
prod_spoke_address_space    = "10.1.0.0/16"
nonprod_spoke_address_space = "10.2.0.0/16"

# Cost management
budget_amount = 5000
alert_email   = "your-email@company.com"

tags = {
  Project    = "azure-landing-zone"
  ManagedBy  = "terraform"
  Owner      = "platform-team"
  CostCenter = "engineering"
}
