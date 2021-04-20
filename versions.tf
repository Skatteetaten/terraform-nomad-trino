terraform {
  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = "1.4.9"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2.0"
    }
  }
  required_version = ">= 0.13"
}
