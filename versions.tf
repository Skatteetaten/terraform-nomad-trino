terraform {
  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = "1.4.14"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.1.2"
    }
  }
  required_version = ">= 0.13"
}
