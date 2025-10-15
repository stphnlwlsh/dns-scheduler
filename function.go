package function

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"

	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
)

func init() {
	functions.HTTP("EnableSocialNetworks", EnableSocialNetworks)
	functions.HTTP("DisableSocialNetworks", DisableSocialNetworks)
	functions.HTTP("ToggleSocialNetworks", ToggleSocialNetworks)
}

const nextDNSAPIURL = "https://api.nextdns.io"

type NextDNSClient struct {
	profileID string
	apiKey    string
}

type CategoryPayload struct {
	ID         string `json:"id"`
	Recreation bool   `json:"recreation"`
	Active     bool   `json:"active"`
}

type ParentalControlSettings struct {
	Categories    []CategoryPayload `json:"categories"`
	SafeSearch    interface{}       `json:"safeSearch,omitempty"`
	YoutubeMode   interface{}       `json:"youtubeMode,omitempty"`
	BlockBypass   interface{}       `json:"blockBypass,omitempty"`
	Services      interface{}       `json:"services,omitempty"`
	Recreation    interface{}       `json:"recreation,omitempty"`
}

func newNextDNSClient() (*NextDNSClient, error) {
	profileID := os.Getenv("NEXTDNS_PROFILE_ID")
	apiKey := os.Getenv("NEXTDNS_API_KEY")

	if profileID == "" || apiKey == "" {
		return nil, fmt.Errorf("NEXTDNS_PROFILE_ID and NEXTDNS_API_KEY environment variables are required")
	}

	return &NextDNSClient{
		profileID: profileID,
		apiKey:    apiKey,
	}, nil
}

func (c *NextDNSClient) getCurrentSettings() (*ParentalControlSettings, error) {
	url := fmt.Sprintf("%s/profiles/%s/parentalControl", nextDNSAPIURL, c.profileID)
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create GET request: %w", err)
	}

	req.Header.Set("x-api-key", c.apiKey)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to get current settings: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("NextDNS API GET returned status %d: %s", resp.StatusCode, string(body))
	}

	var settings ParentalControlSettings
	if err := json.NewDecoder(resp.Body).Decode(&settings); err != nil {
		return nil, fmt.Errorf("failed to decode current settings: %w", err)
	}

	return &settings, nil
}

func (c *NextDNSClient) enableSocialNetworks() error {
	currentSettings, err := c.getCurrentSettings()
	if err != nil {
		return fmt.Errorf("failed to get current settings: %w", err)
	}

	// Find and update the social-networks category, or add it if it doesn't exist
	found := false
	for i, category := range currentSettings.Categories {
		if category.ID == "social-networks" {
			currentSettings.Categories[i].Active = true
			found = true
			break
		}
	}

	// If social-networks category doesn't exist, add it
	if !found {
		socialNetworksCategory := CategoryPayload{
			ID:         "social-networks",
			Recreation: false,
			Active:     true,
		}
		currentSettings.Categories = append(currentSettings.Categories, socialNetworksCategory)
	}

	// Send the updated settings
	jsonData, err := json.Marshal(currentSettings)
	if err != nil {
		return fmt.Errorf("failed to marshal JSON: %w", err)
	}

	url := fmt.Sprintf("%s/profiles/%s/parentalControl", nextDNSAPIURL, c.profileID)
	req, err := http.NewRequest("PATCH", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create PATCH request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-api-key", c.apiKey)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to make request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("NextDNS API PATCH returned status %d: %s", resp.StatusCode, string(body))
	}

	fmt.Printf("Successfully enabled social networks category\n")
	return nil
}

// EnableSocialNetworks is the Cloud Function entry point
func EnableSocialNetworks(w http.ResponseWriter, r *http.Request) {
	client, err := newNextDNSClient()
	if err != nil {
		log.Printf("Error creating NextDNS client: %v", err)
		http.Error(w, fmt.Sprintf("Configuration error: %v", err), http.StatusInternalServerError)
		return
	}

	if err := client.enableSocialNetworks(); err != nil {
		log.Printf("Error enabling social networks: %v", err)
		http.Error(w, fmt.Sprintf("Failed to enable social networks: %v", err), http.StatusInternalServerError)
		return
	}

	log.Println("Successfully enabled social networks blocking")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Social networks blocking enabled"))
}

func (c *NextDNSClient) disableSocialNetworks() error {
	currentSettings, err := c.getCurrentSettings()
	if err != nil {
		return fmt.Errorf("failed to get current settings: %w", err)
	}

	// Find and update the social-networks category, or add it if it doesn't exist
	found := false
	for i, category := range currentSettings.Categories {
		if category.ID == "social-networks" {
			currentSettings.Categories[i].Active = false
			found = true
			break
		}
	}

	// If social-networks category doesn't exist, add it as disabled
	if !found {
		socialNetworksCategory := CategoryPayload{
			ID:         "social-networks",
			Recreation: false,
			Active:     false,
		}
		currentSettings.Categories = append(currentSettings.Categories, socialNetworksCategory)
	}

	// Send the updated settings
	jsonData, err := json.Marshal(currentSettings)
	if err != nil {
		return fmt.Errorf("failed to marshal JSON: %w", err)
	}

	url := fmt.Sprintf("%s/profiles/%s/parentalControl", nextDNSAPIURL, c.profileID)
	req, err := http.NewRequest("PATCH", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create PATCH request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-api-key", c.apiKey)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to make request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("NextDNS API PATCH returned status %d: %s", resp.StatusCode, string(body))
	}

	fmt.Printf("Successfully disabled social networks category\n")
	return nil
}

// DisableSocialNetworks is the Cloud Function entry point
func DisableSocialNetworks(w http.ResponseWriter, r *http.Request) {
	client, err := newNextDNSClient()
	if err != nil {
		log.Printf("Error creating NextDNS client: %v", err)
		http.Error(w, fmt.Sprintf("Configuration error: %v", err), http.StatusInternalServerError)
		return
	}

	if err := client.disableSocialNetworks(); err != nil {
		log.Printf("Error disabling social networks: %v", err)
		http.Error(w, fmt.Sprintf("Failed to disable social networks: %v", err), http.StatusInternalServerError)
		return
	}

	log.Println("Successfully disabled social networks blocking")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Social networks blocking disabled"))
}

// ToggleSocialNetworks allows enabling/disabling based on query parameter
func ToggleSocialNetworks(w http.ResponseWriter, r *http.Request) {
	action := r.URL.Query().Get("action")
	if action == "" {
		http.Error(w, "Missing 'action' query parameter. Use ?action=enable or ?action=disable", http.StatusBadRequest)
		return
	}

	client, err := newNextDNSClient()
	if err != nil {
		log.Printf("Error creating NextDNS client: %v", err)
		http.Error(w, fmt.Sprintf("Configuration error: %v", err), http.StatusInternalServerError)
		return
	}

	switch action {
	case "enable":
		if err := client.enableSocialNetworks(); err != nil {
			log.Printf("Error enabling social networks: %v", err)
			http.Error(w, fmt.Sprintf("Failed to enable social networks: %v", err), http.StatusInternalServerError)
			return
		}
		log.Println("Successfully enabled social networks blocking")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("Social networks blocking enabled"))
	case "disable":
		if err := client.disableSocialNetworks(); err != nil {
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
