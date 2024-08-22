provider "azurerm" {
  features {}
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
}

terraform {
  required_providers {
    ipify = {
      source = "rerichardjr/ipify"
    }
  }
}

provider "ipify" {}

data "ipify_ip" "public" {}

resource "azurerm_resource_group" "main" {
  name     = "rg-gwlb-test-${var.location_short}"
  location = "UK South"
}
