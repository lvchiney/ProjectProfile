location                = "eastus"
environment             = "dev"
resource_group_name     = "rg-mlops-dev"
ml_workspace_name       = "mlw-mlops-dev"
storage_account_name    = "stmlopsdev"
container_registry_name = "crmlopsdev"
keyvault_name           = "kv-mlops-dev"
accuracy_threshold      = 0.85
app_service_sku         = "B1"

tags = {
  Environment = "dev"
  Project     = "mlops-pipeline"
  Owner       = "your-name"
  CostCenter  = "engineering"
}
