package function

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"

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

func newNextDNSClientForProfile(profileID string) (*NextDNSClient, error) {
	apiKey := os.Getenv("NEXTDNS_API_KEY")

	if profileID == "" || apiKey == "" {
		return nil, fmt.Errorf("profileID and NEXTDNS_API_KEY are required")
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

	// Ensure porn category is always blocked and update social-networks category
	socialNetworksFound := false
	pornFound := false
	for i, category := range currentSettings.Categories {
		if category.ID == "social-networks" {
			currentSettings.Categories[i].Active = true
			socialNetworksFound = true
		} else if category.ID == "porn" {
			currentSettings.Categories[i].Active = true // Always keep porn blocked
			pornFound = true
		}
	}

	// Add missing categories if they don't exist
	if !socialNetworksFound {
		socialNetworksCategory := CategoryPayload{
			ID:         "social-networks",
			Recreation: false,
			Active:     true,
		}
		currentSettings.Categories = append(currentSettings.Categories, socialNetworksCategory)
	}
	if !pornFound {
		pornCategory := CategoryPayload{
			ID:         "porn",
			Recreation: false,
			Active:     true, // Always blocked
		}
		currentSettings.Categories = append(currentSettings.Categories, pornCategory)
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

func enableSocialNetworksForProfile(profileID string) error {
	client, err := newNextDNSClientForProfile(profileID)
	if err != nil {
		return err
	}
	return client.enableSocialNetworks()
}

func enableSocialNetworksForAllProfiles() error {
	// Get all profile IDs from environment variables
	profileID1 := os.Getenv("NEXTDNS_PROFILE_ID")
	profileID2 := os.Getenv("NEXTDNS_PROFILE_ID_2")

	var errors []string

	if profileID1 != "" {
		if err := enableSocialNetworksForProfile(profileID1); err != nil {
			errors = append(errors, fmt.Sprintf("Profile %s: %v", profileID1, err))
		}
	}

	if profileID2 != "" {
		if err := enableSocialNetworksForProfile(profileID2); err != nil {
			errors = append(errors, fmt.Sprintf("Profile %s: %v", profileID2, err))
		}
	}

	if len(errors) > 0 {
		return fmt.Errorf("errors occurred: %s", strings.Join(errors, "; "))
	}

	return nil
}

// EnableSocialNetworks is the Cloud Function entry point
func EnableSocialNetworks(w http.ResponseWriter, r *http.Request) {
	if err := enableSocialNetworksForAllProfiles(); err != nil {
		log.Printf("Error enabling social networks: %v", err)
		http.Error(w, fmt.Sprintf("Failed to enable social networks: %v", err), http.StatusInternalServerError)
		return
	}

	log.Println("Successfully enabled social networks blocking for all profiles (porn always blocked)")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Social networks blocking enabled for all profiles (porn always blocked)"))
}

func (c *NextDNSClient) disableSocialNetworks() error {
	currentSettings, err := c.getCurrentSettings()
	if err != nil {
		return fmt.Errorf("failed to get current settings: %w", err)
	}

	// Ensure porn category is always blocked and update social-networks category
	socialNetworksFound := false
	pornFound := false
	for i, category := range currentSettings.Categories {
		if category.ID == "social-networks" {
			currentSettings.Categories[i].Active = false
			socialNetworksFound = true
		} else if category.ID == "porn" {
			currentSettings.Categories[i].Active = true // Always keep porn blocked
			pornFound = true
		}
	}

	// Add missing categories if they don't exist
	if !socialNetworksFound {
		socialNetworksCategory := CategoryPayload{
			ID:         "social-networks",
			Recreation: false,
			Active:     false,
		}
		currentSettings.Categories = append(currentSettings.Categories, socialNetworksCategory)
	}
	if !pornFound {
		pornCategory := CategoryPayload{
			ID:         "porn",
			Recreation: false,
			Active:     true, // Always blocked
		}
		currentSettings.Categories = append(currentSettings.Categories, pornCategory)
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

func disableSocialNetworksForProfile(profileID string) error {
	client, err := newNextDNSClientForProfile(profileID)
	if err != nil {
		return err
	}
	return client.disableSocialNetworks()
}

func disableSocialNetworksForAllProfiles() error {
	// Get all profile IDs from environment variables
	profileID1 := os.Getenv("NEXTDNS_PROFILE_ID")
	profileID2 := os.Getenv("NEXTDNS_PROFILE_ID_2")

	var errors []string

	if profileID1 != "" {
		if err := disableSocialNetworksForProfile(profileID1); err != nil {
			errors = append(errors, fmt.Sprintf("Profile %s: %v", profileID1, err))
		}
	}

	if profileID2 != "" {
		if err := disableSocialNetworksForProfile(profileID2); err != nil {
			errors = append(errors, fmt.Sprintf("Profile %s: %v", profileID2, err))
		}
	}

	if len(errors) > 0 {
		return fmt.Errorf("errors occurred: %s", strings.Join(errors, "; "))
	}

	return nil
}

// DisableSocialNetworks is the Cloud Function entry point
func DisableSocialNetworks(w http.ResponseWriter, r *http.Request) {
	if err := disableSocialNetworksForAllProfiles(); err != nil {
		log.Printf("Error disabling social networks: %v", err)
		http.Error(w, fmt.Sprintf("Failed to disable social networks: %v", err), http.StatusInternalServerError)
		return
	}

	log.Println("Successfully disabled social networks blocking for all profiles (porn always blocked)")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Social networks blocking disabled for all profiles (porn always blocked)"))
}

// ToggleSocialNetworks allows enabling/disabling based on query parameter
// Supports optional 'profile' parameter to target specific profile, otherwise affects all profiles
func ToggleSocialNetworks(w http.ResponseWriter, r *http.Request) {
	action := r.URL.Query().Get("action")
	profileID := r.URL.Query().Get("profile")
	
	if action == "" {
		http.Error(w, "Missing 'action' query parameter. Use ?action=enable or ?action=disable&profile=ID (optional)", http.StatusBadRequest)
		return
	}

	switch action {
	case "enable":
		var err error
		var message string
		
		if profileID != "" {
			// Target specific profile
			err = enableSocialNetworksForProfile(profileID)
			message = fmt.Sprintf("Social networks blocking enabled for profile %s (porn always blocked)", profileID)
		} else {
			// Target all profiles
			err = enableSocialNetworksForAllProfiles()
			message = "Social networks blocking enabled for all profiles (porn always blocked)"
		}
		
		if err != nil {
			log.Printf("Error enabling social networks: %v", err)
			http.Error(w, fmt.Sprintf("Failed to enable social networks: %v", err), http.StatusInternalServerError)
			return
		}
		
		log.Println(message)
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(message))
		
	case "disable":
		var err error
		var message string
		
		if profileID != "" {
			// Target specific profile
			err = disableSocialNetworksForProfile(profileID)
			message = fmt.Sprintf("Social networks blocking disabled for profile %s (porn always blocked)", profileID)
		} else {
			// Target all profiles
			err = disableSocialNetworksForAllProfiles()
			message = "Social networks blocking disabled for all profiles (porn always blocked)"
		}
		
		if err != nil {
			log.Printf("Error disabling social networks: %v", err)
			http.Error(w, fmt.Sprintf("Failed to disable social networks: %v", err), http.StatusInternalServerError)
			return
		}
		
		log.Println(message)
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(message))
	default:
		http.Error(w, "Invalid action. Use ?action=enable or ?action=disable", http.StatusBadRequest)
	}
}
