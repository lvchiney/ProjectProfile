location            = "eastus"
environment         = "dev"
resource_group_name = "rg-rag-chatbot-dev"
openai_sku          = "S0"
search_sku          = "basic"
app_service_sku     = "B1"

tags = {
  Environment = "dev"
  Project     = "rag-chatbot"
  Owner       = "your-name"
  CostCenter  = "engineering"
}
