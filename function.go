package main

import (
	"fmt"
	"log"
	"net/http"

	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
)

func init() {
	functions.HTTP("EnableSocialNetworks", EnableSocialNetworks)
	functions.HTTP("DisableSocialNetworks", DisableSocialNetworks)
}

func EnableSocialNetworks(w http.ResponseWriter, r *http.Request) {
	client, err := NewNextDNSClient()
	if err != nil {
		log.Printf("Error creating NextDNS client: %v", err)
		http.Error(w, fmt.Sprintf("Configuration error: %v", err), http.StatusInternalServerError)
		return
	}

	if err := client.EnableSocialNetworks(); err != nil {
		log.Printf("Error enabling social networks: %v", err)
		http.Error(w, fmt.Sprintf("Failed to enable social networks: %v", err), http.StatusInternalServerError)
		return
	}

	log.Println("Successfully enabled social networks blocking")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Social networks blocking enabled"))
}

func DisableSocialNetworks(w http.ResponseWriter, r *http.Request) {
	client, err := NewNextDNSClient()
	if err != nil {
		log.Printf("Error creating NextDNS client: %v", err)
		http.Error(w, fmt.Sprintf("Configuration error: %v", err), http.StatusInternalServerError)
		return
	}

	if err := client.DisableSocialNetworks(); err != nil {
		log.Printf("Error disabling social networks: %v", err)
		http.Error(w, fmt.Sprintf("Failed to disable social networks: %v", err), http.StatusInternalServerError)
		return
	}

	log.Println("Successfully disabled social networks blocking")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Social networks blocking disabled"))
}

