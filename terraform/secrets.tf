data "google_secret_manager_secret_version" "NEXTDNS_API_KEY" {
  secret = "NEXTDNS_API_KEY"
}

data "google_secret_manager_secret_version" "NEXTDNS_PROFILE_ID" {
  secret = "NEXTDNS_PROFILE_ID"
}

data "google_secret_manager_secret_version" "NEXTDNS_PROFILE_ID_2" {
  secret = "NEXTDNS_PROFILE_ID_2"
}
