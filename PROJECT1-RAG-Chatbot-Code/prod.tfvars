location            = "eastus"
environment         = "prod"
resource_group_name = "rg-rag-chatbot-prod"
openai_sku          = "S0"
search_sku          = "standard"
app_service_sku     = "P2v3"

tags = {
  Environment = "prod"
  Project     = "rag-chatbot"
  Owner       = "your-name"
  CostCenter  = "engineering"
}
