package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
)

const (
	nextDNSAPIURL = "https://api.nextdns.io"
)

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
	Categories []CategoryPayload `json:"categories"`
	// Add other fields if needed to preserve full settings
	SafeSearch    interface{} `json:"safeSearch,omitempty"`
	YoutubeMode   interface{} `json:"youtubeMode,omitempty"`
	BlockBypass   interface{} `json:"blockBypass,omitempty"`
	Services      interface{} `json:"services,omitempty"`
	Recreation    interface{} `json:"recreation,omitempty"`
}

func NewNextDNSClient() (*NextDNSClient, error) {
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

func (c *NextDNSClient) EnableSocialNetworks() error {
	return c.updateSocialNetworksCategory(true)
}

func (c *NextDNSClient) DisableSocialNetworks() error {
	return c.updateSocialNetworksCategory(false)
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

func (c *NextDNSClient) updateSocialNetworksCategory(active bool) error {
	// First, get current settings
	currentSettings, err := c.getCurrentSettings()
	if err != nil {
		return fmt.Errorf("failed to get current settings: %w", err)
	}

	// Find and update the social-networks category, or add it if it doesn't exist
	found := false
	for i, category := range currentSettings.Categories {
		if category.ID == "social-networks" {
			currentSettings.Categories[i].Active = active
			found = true
			break
		}
	}

	// If social-networks category doesn't exist, add it
	if !found {
		socialNetworksCategory := CategoryPayload{
			ID:         "social-networks",
			Recreation: false,
			Active:     active,
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

	action := "disabled"
	if active {
		action = "enabled"
	}
	fmt.Printf("Successfully %s social networks category while preserving other settings\n", action)
	return nil
}