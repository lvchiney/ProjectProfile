#!/usr/bin/env bash
# Bootstrap Azure remote state storage - run once before first pipeline run
set -eu

RG="rg-terraform-state"
SA="sttfstate"
CONTAINER="tfstate"
LOCATION="eastus"

az group create --name "$RG" --location "$LOCATION"
az storage account create --name "$SA" --resource-group "$RG" --sku Standard_LRS --kind StorageV2 --https-only true --min-tls-version TLS1_2
az storage container create --name "$CONTAINER" --account-name "$SA"

echo "Done. State keys: env/dev/main.tfstate | env/prod/main.tfstate"
