package middleware

import (
	"net/http"
	"os"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/propagation"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
)

func initTracer() {
	if os.Getenv("GOOGLE_CLOUD_PROJECT") == "" {
		return
	}
	if _, ok := otel.GetTracerProvider().(*sdktrace.TracerProvider); ok {
		return
	}
	otel.SetTracerProvider(sdktrace.NewTracerProvider())
	otel.SetTextMapPropagator(propagation.TraceContext{})
}

func Tracing(serviceName string, next http.Handler) http.Handler {
	initTracer()
	return otelhttp.NewHandler(next, serviceName)
}

func NewOutboundClient() *http.Client {
	initTracer()
	return &http.Client{
		Transport: otelhttp.NewTransport(http.DefaultTransport),
	}
}

func OutboundRequest(req *http.Request) *http.Request {
	PropagateRequestID(req)
	return req
}
