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

// YouTube domains to block when social networks are blocked
var youtubeDomains = []string{
	"youtube.com",
	"youtu.be",
	"www.youtube.com",
	"m.youtube.com",
}

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

	// Also add YouTube domains to denylist when blocking social networks
	if err := c.addYouTubeToDenylist(); err != nil {
		fmt.Printf("Warning: Failed to add YouTube domains to denylist: %v\n", err)
	}

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

// handlePanicURL blocks or unblocks my.nextdns.io in the denylist
func handlePanicURL(profileID, action string) error {
	client, err := newNextDNSClientForProfile(profileID)
	if err != nil {
		return fmt.Errorf("failed to create NextDNS client: %w", err)
	}

	panicDomain := "my.nextdns.io"

	if action == "block" {
		return client.addToDenylist(panicDomain)
	} else if action == "unblock" {
		return client.removeFromDenylist(panicDomain)
	}

	return fmt.Errorf("invalid action: %s", action)
}

// addToDenylist adds a domain to the NextDNS denylist
func (c *NextDNSClient) addToDenylist(domain string) error {
	url := fmt.Sprintf("%s/profiles/%s/denylist", nextDNSAPIURL, c.profileID)

	payload := map[string]string{"id": domain}
	jsonData, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal JSON: %w", err)
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create POST request: %w", err)
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
		return fmt.Errorf("NextDNS API POST returned status %d: %s", resp.StatusCode, string(body))
	}

	fmt.Printf("Successfully added %s to denylist\n", domain)
	return nil
}

// addYouTubeToDenylist adds YouTube domains to the denylist
func (c *NextDNSClient) addYouTubeToDenylist() error {
	var errors []string
	for _, domain := range youtubeDomains {
		if err := c.addToDenylist(domain); err != nil {
			errors = append(errors, fmt.Sprintf("%s: %v", domain, err))
		}
	}
	if len(errors) > 0 {
		return fmt.Errorf("failed to add some YouTube domains: %s", strings.Join(errors, "; "))
	}
	return nil
}

// removeYouTubeFromDenylist removes YouTube domains from the denylist
func (c *NextDNSClient) removeYouTubeFromDenylist() error {
	var errors []string
	for _, domain := range youtubeDomains {
		if err := c.removeFromDenylist(domain); err != nil {
			errors = append(errors, fmt.Sprintf("%s: %v", domain, err))
		}
	}
	if len(errors) > 0 {
		return fmt.Errorf("failed to remove some YouTube domains: %s", strings.Join(errors, "; "))
	}
	return nil
}

// removeFromDenylist removes a domain from the NextDNS denylist
func (c *NextDNSClient) removeFromDenylist(domain string) error {
	url := fmt.Sprintf("%s/profiles/%s/denylist/%s", nextDNSAPIURL, c.profileID, domain)

	req, err := http.NewRequest("DELETE", url, nil)
	if err != nil {
		return fmt.Errorf("failed to create DELETE request: %w", err)
	}

	req.Header.Set("x-api-key", c.apiKey)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to make request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("NextDNS API DELETE returned status %d: %s", resp.StatusCode, string(body))
	}

	fmt.Printf("Successfully removed %s from denylist\n", domain)
	return nil
}

// isPanicModeActive checks if my.nextdns.io is in the denylist (indicating panic mode)
func (c *NextDNSClient) isPanicModeActive() (bool, error) {
	url := fmt.Sprintf("%s/profiles/%s/denylist", nextDNSAPIURL, c.profileID)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return false, fmt.Errorf("failed to create GET request: %w", err)
	}

	req.Header.Set("x-api-key", c.apiKey)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return false, fmt.Errorf("failed to get denylist: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := io.ReadAll(resp.Body)
		return false, fmt.Errorf("NextDNS API GET returned status %d: %s", resp.StatusCode, string(body))
	}

	var denylist struct {
		Data []struct {
			ID string `json:"id"`
		} `json:"data"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&denylist); err != nil {
		return false, fmt.Errorf("failed to decode denylist: %w", err)
	}

	// Check if my.nextdns.io is in the denylist
	for _, entry := range denylist.Data {
		if entry.ID == "my.nextdns.io" {
			return true, nil
		}
	}

	return false, nil
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
	// Check if panic mode is active - if so, don't disable
	panicActive, err := c.isPanicModeActive()
	if err != nil {
		log.Printf("Warning: Failed to check panic mode status: %v", err)
		// Continue anyway if we can't check
	} else if panicActive {
		fmt.Printf("Panic mode active for profile %s - skipping disable\n", c.profileID)
		return fmt.Errorf("panic mode active - blocking will not be disabled")
	}

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

	// Also remove YouTube domains from denylist when unblocking social networks
	if err := c.removeYouTubeFromDenylist(); err != nil {
		fmt.Printf("Warning: Failed to remove YouTube domains from denylist: %v\n", err)
	}

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
		// Check if all errors are due to panic mode
		if strings.Contains(err.Error(), "panic mode active") {
			log.Printf("Panic mode is active - scheduled disable skipped: %v", err)
			w.WriteHeader(http.StatusOK)
			w.Write([]byte("Panic mode active - blocking maintained. Use toggle function to disable panic mode."))
			return
		}
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
// Also handles panic URL blocking for my.nextdns.io when panic_profile is provided
func ToggleSocialNetworks(w http.ResponseWriter, r *http.Request) {
	action := r.URL.Query().Get("action")
	profileID := r.URL.Query().Get("profile")
	panicProfileID := r.URL.Query().Get("panic_profile")
	
	if action == "" {
		http.Error(w, "Missing 'action' query parameter. Use ?action=enable or ?action=disable&profile=ID (optional)&panic_profile=ID (optional)", http.StatusBadRequest)
		return
	}

	switch action {
	case "enable":
		var err error
		var message string
		
		// If panic_profile is provided, use that as the target profile
		targetProfile := profileID
		if panicProfileID != "" {
			targetProfile = panicProfileID
		}
		
		if targetProfile != "" {
			// Target specific profile
			err = enableSocialNetworksForProfile(targetProfile)
			message = fmt.Sprintf("Social networks blocking enabled for profile %s (porn always blocked)", targetProfile)
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
		
		// Handle panic URL blocking if panic_profile is provided
		if panicProfileID != "" {
			if err := handlePanicURL(panicProfileID, "block"); err != nil {
				log.Printf("Warning: Failed to block panic URL for profile %s: %v", panicProfileID, err)
				// Don't fail the whole request, just log the warning
			}
		}
		
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(message))
		
	case "disable":
		var err error
		var message string
		
		// If panic_profile is provided, use that as the target profile
		targetProfile := profileID
		if panicProfileID != "" {
			targetProfile = panicProfileID
		}
		
		if targetProfile != "" {
			// Target specific profile
			err = disableSocialNetworksForProfile(targetProfile)
			message = fmt.Sprintf("Social networks blocking disabled for profile %s (porn always blocked)", targetProfile)
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
		
		// Handle panic URL unblocking if panic_profile is provided
		if panicProfileID != "" {
			if err := handlePanicURL(panicProfileID, "unblock"); err != nil {
				log.Printf("Warning: Failed to unblock panic URL for profile %s: %v", panicProfileID, err)
				// Don't fail the whole request, just log the warning
			}
		}
		
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(message))
	default:
		http.Error(w, "Invalid action. Use ?action=enable or ?action=disable", http.StatusBadRequest)
	}
}
