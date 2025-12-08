
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
  description = "The tag for the Docker image"
  type        = string
  default     = "dns-scheduler"
}

variable "app_name_friendly" {
  description = "The tag for the Docker image"
  type        = string
  default     = "DNS Scheduler"
}

variable "nextdns_api_key" {
  description = "NextDNS API Key"
  type        = string
  sensitive   = true
}

variable "nextdns_profile_id" {
  description = "NextDNS Profile ID"
  type        = string
  sensitive   = true
}

variable "nextdns_profile_id_2" {
  description = "NextDNS Profile ID for second profile (optional)"
  type        = string
  sensitive   = true
  default     = ""
}
