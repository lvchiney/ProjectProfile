location                = "eastus"
environment             = "prod"
resource_group_name     = "rg-mlops-prod"
ml_workspace_name       = "mlw-mlops-prod"
storage_account_name    = "stmlopsprod"
container_registry_name = "crmlosprod"
keyvault_name           = "kv-mlops-prod"
accuracy_threshold      = 0.90
app_service_sku         = "P2v3"

tags = {
  Environment = "prod"
  Project     = "mlops-pipeline"
  Owner       = "your-name"
  CostCenter  = "engineering"
}
