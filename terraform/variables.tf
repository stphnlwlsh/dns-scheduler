
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "project_number" {
  description = "The GCP project number"
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
