package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
)

func init() {
	functions.HTTP("EnableSocialNetworks", enableSocialNetworks)
	functions.HTTP("DisableSocialNetworks", disableSocialNetworks)
	functions.HTTP("ToggleSocialNetworks", toggleSocialNetworks)
}

func enableSocialNetworks(w http.ResponseWriter, r *http.Request) {
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

func disableSocialNetworks(w http.ResponseWriter, r *http.Request) {
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

// toggleSocialNetworks allows enabling/disabling based on query parameter
func toggleSocialNetworks(w http.ResponseWriter, r *http.Request) {
	action := r.URL.Query().Get("action")
	if action == "" {
		http.Error(w, "Missing 'action' query parameter. Use ?action=enable or ?action=disable", http.StatusBadRequest)
		return
	}

	client, err := NewNextDNSClient()
	if err != nil {
		log.Printf("Error creating NextDNS client: %v", err)
		http.Error(w, fmt.Sprintf("Configuration error: %v", err), http.StatusInternalServerError)
		return
	}

	switch action {
	case "enable":
		if err := client.EnableSocialNetworks(); err != nil {
			log.Printf("Error enabling social networks: %v", err)
			http.Error(w, fmt.Sprintf("Failed to enable social networks: %v", err), http.StatusInternalServerError)
			return
		}
		log.Println("Successfully enabled social networks blocking")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("Social networks blocking enabled"))
	case "disable":
		if err := client.DisableSocialNetworks(); err != nil {
			log.Printf("Error disabling social networks: %v", err)
			http.Error(w, fmt.Sprintf("Failed to disable social networks: %v", err), http.StatusInternalServerError)
			return
		}
		log.Println("Successfully disabled social networks blocking")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("Social networks blocking disabled"))
	default:
		http.Error(w, "Invalid action. Use ?action=enable or ?action=disable", http.StatusBadRequest)
	}
}

func main() {
	// Use PORT environment variable, or default to 8080.
	port := "8080"
	if envPort := os.Getenv("PORT"); envPort != "" {
		port = envPort
	}

	// Start HTTP server.
	log.Printf("Listening on port %s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}