package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"

	sharedmw "github.com/alekhyaakkiraju-droid/focusquest/packages/shared/middleware"
)

const serviceName = "analytics-service"

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", healthHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	handler := sharedmw.Chain(serviceName, mux)
	log.Printf("%s listening on :%s", serviceName, port)
	if err := http.ListenAndServe(":"+port, handler); err != nil {
		log.Fatalf("%s server failed: %v", serviceName, err)
	}
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{
		"status":  "ok",
		"service": serviceName,
	})
}
