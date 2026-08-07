package main

import (
	"bufio"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

func loadEnv() {
	file, err := os.Open(".env")
	if err != nil {
		return // Skip if no .env
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) == 2 {
			key := strings.TrimSpace(parts[0])
			value := strings.TrimSpace(parts[1])
			if strings.HasPrefix(value, "\"") && strings.HasSuffix(value, "\"") {
				value = value[1 : len(value)-1]
			}
			os.Setenv(key, value)
		}
	}
}

func main() {
	loadEnv()

	port := os.Getenv("PORT")
	if port == "" {
		port = "8081" // Backend uses 8080, we use 8081 for frontend development
	}

	staticDir := "build/web"

	// Serve config variables to the frontend dynamically
	http.HandleFunc("/config.json", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Access-Control-Allow-Origin", "*")
		backendURL := os.Getenv("BACKEND_BASE_URL")
		if backendURL == "" {
			backendURL = "http://localhost:8080/api/v1" // Fallback
		}
		// Empty until a real Google OAuth Web Client ID is configured; the
		// frontend hides the Google sign-in button when this is blank.
		googleClientID := os.Getenv("GOOGLE_CLIENT_ID")

		config := map[string]string{
			"base_url":         backendURL,
			"google_client_id": googleClientID,
		}
		encoded, err := json.Marshal(config)
		if err != nil {
			http.Error(w, "failed to encode config", http.StatusInternalServerError)
			return
		}
		w.Write(encoded)
	})

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		path := filepath.Clean(r.URL.Path)
		fullPath := filepath.Join(staticDir, path)

		// Check if file exists and is not a directory
		info, err := os.Stat(fullPath)
		if err == nil && !info.IsDir() {
			w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
			w.Header().Set("Pragma", "no-cache")
			w.Header().Set("Expires", "0")
			http.ServeFile(w, r, fullPath)
			return
		}

		// Fallback to index.html for SPA routing (Flutter Web)
		w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
		w.Header().Set("Pragma", "no-cache")
		w.Header().Set("Expires", "0")
		http.ServeFile(w, r, filepath.Join(staticDir, "index.html"))
	})

	log.Printf("Frontend server starting on port %s...", port)
	err := http.ListenAndServe(":"+port, nil)
	if err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
