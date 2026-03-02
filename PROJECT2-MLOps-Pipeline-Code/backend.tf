# ⚠️ IMPORTANT: Create this storage account MANUALLY before running terraform init
# Run these Azure CLI commands ONCE before anything else:
#
#   az group create --name rg-terraform-state --location eastus
#   az storage account create --name stterraformstate --resource-group rg-terraform-state --location eastus --sku Standard_LRS
#   az storage account blob-service-properties update --account-name stterraformstate --resource-group rg-terraform-state --enable-versioning true
#   az storage container create --name tfstate --account-name stterraformstate
#
# Then run: terraform init

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    key                  = "mlops-pipeline/terraform.tfstate"
  }
}
