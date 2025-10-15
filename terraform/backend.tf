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
  backend "http" {
    # Configuration will be provided via environment variables or CLI flags
    # This allows for flexible configuration in different environments
  }
}
