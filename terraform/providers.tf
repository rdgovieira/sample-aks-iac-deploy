terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }

  # Configuração parcial do backend: os parâmetros (resource_group_name,
  # storage_account_name, container_name, key) são passados via CLI (-backend-config)
  # na pipeline do GitHub Actions ou localmente.
  backend "azurerm" {}
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

