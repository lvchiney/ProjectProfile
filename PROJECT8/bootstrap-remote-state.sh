#!/bin/bash
# bootstrap-remote-state.sh
# One-time setup: creates the Azure Storage Account used as Terraform remote state.
# Run this ONCE before the first pipeline execution.
# Matches the "Azure Storage Account" (Remote State / Blob Storage) box in the diagram.

set -euo pipefail

RESOURCE_GROUP="rg-terraform-state"
STORAGE_ACCOUNT="stterraformstate"      # must be globally unique — change if needed
CONTAINER="tfstate"
LOCATION="eastus"

echo "==> Creating resource group: $RESOURCE_GROUP"
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

echo "==> Creating storage account: $STORAGE_ACCOUNT"
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

echo "==> Creating blob container: $CONTAINER"
az storage container create \
  --name "$CONTAINER" \
  --account-name "$STORAGE_ACCOUNT" \
  --auth-mode login

echo "==> Enabling versioning (protects state files)"
az storage account blob-service-properties update \
  --account-name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --enable-versioning true

echo ""
echo "✅ Remote state backend is ready."
echo "   State files will be stored at:"
echo "     $STORAGE_ACCOUNT/$CONTAINER/env/dev/main.tfstate"
echo "     $STORAGE_ACCOUNT/$CONTAINER/env/prod/main.tfstate"
