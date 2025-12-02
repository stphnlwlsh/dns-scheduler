terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
  backend "gcs" {
    bucket = "cwaw-prod-67f8c561-tfstate"
    prefix = "terraform/state"
  }
}
