package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"

	sharederrors "github.com/alekhyaakkiraju-droid/focusquest/packages/shared/errors"
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

	handler := sharederrors.Chain(serviceName, sharedmw.Chain(serviceName, mux))
	log.Printf("%s listening on :%s", serviceName, port)
	if err := http.ListenAndServe(":"+port, handler); err != nil {
		log.Fatalf("%s server failed: %v", serviceName, err)
	}
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		sharederrors.WriteError(w, r, serviceName, sharederrors.ValidationError(
			"Only GET is supported for this endpoint",
			sharederrors.Detail{Field: "method", Reason: r.Method + " is not allowed"},
		))
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{
		"status":  "ok",
		"service": serviceName,
	})
}
