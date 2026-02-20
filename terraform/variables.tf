
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "location" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "image_tag" {
  description = "The tag for the Docker image"
  type        = string
  default     = "latest"
}

variable "app_name" {
  description = "The name of the application"
  type        = string
  default     = "dns-scheduler"
}

variable "app_name_friendly" {
  description = "The friendly name of the application"
  type        = string
  default     = "DNS Scheduler"
}

variable "domain_deny_list" {
  description = "The list of domains to deny"
  type        = string
  default     = ""
}

variable "domain_allow_list" {
  description = "The list of domains to allow"
  type        = string
  default     = ""
}

variable "environment" {
  description = "The environment (e.g. prod, dev)"
  type        = string
  default     = "prod"
}
