# Remote State — Azure Blob Storage

Storage Account : sttfstate
Container       : tfstate
  env/dev/main.tfstate   <- workspace: dev
  env/prod/main.tfstate  <- workspace: prod

Run scripts/bootstrap-state.sh once to provision.
