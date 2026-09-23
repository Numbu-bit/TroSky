"""OpenTelemetry tracing and Prometheus metrics setup.

Tracing is disabled by default in local development (``OTEL_ENABLED=false``)
and exports via OTLP/HTTP when enabled. Metrics are always registered on the
Prometheus client's default registry and exposed at ``/metrics``.
"""

from __future__ import annotations

from fastapi import FastAPI
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from prometheus_client import CollectorRegistry, Counter, Histogram
from prometheus_fastapi_instrumentator import Instrumentator

from app.core.config import Settings
from app.core.logging import get_logger

logger = get_logger(__name__)

REGISTRY = CollectorRegistry(auto_describe=True)

# --- Domain-specific metrics (beyond generic HTTP request/latency, which
# prometheus-fastapi-instrumentator provides automatically) ---------------
PAYMENT_EVENTS_TOTAL = Counter(
    "trosky_payment_events_total",
    "Payment lifecycle events by provider and outcome.",
    labelnames=("provider", "outcome"),
    registry=REGISTRY,
)
WEBHOOK_EVENTS_TOTAL = Counter(
    "trosky_webhook_events_total",
    "Payment provider webhook events received, by provider and result.",
    labelnames=("provider", "result"),
    registry=REGISTRY,
)
BOOKING_EVENTS_TOTAL = Counter(
    "trosky_booking_events_total",
    "Booking lifecycle events by outcome.",
    labelnames=("outcome",),
    registry=REGISTRY,
)
RESERVATION_EXPIRATIONS_TOTAL = Counter(
    "trosky_reservation_expirations_total",
    "Seat reservations expired by the background sweeper.",
    registry=REGISTRY,
)
GPS_INGEST_TOTAL = Counter(
    "trosky_gps_ingest_total",
    "GPS location updates ingested, by result.",
    labelnames=("result",),
    registry=REGISTRY,
)
ACTIVE_WEBSOCKET_CONNECTIONS = Counter(
    "trosky_websocket_connections_total",
    "WebSocket connections opened/closed.",
    labelnames=("event",),
    registry=REGISTRY,
)
NOTIFICATION_DELIVERY_TOTAL = Counter(
    "trosky_notification_delivery_total",
    "Notification delivery attempts by channel and result.",
    labelnames=("channel", "result"),
    registry=REGISTRY,
)
SOS_EVENTS_TOTAL = Counter(
    "trosky_sos_events_total",
    "SOS events created, by status.",
    labelnames=("status",),
    registry=REGISTRY,
)
DB_QUERY_LATENCY_SECONDS = Histogram(
    "trosky_db_query_latency_seconds",
    "Latency of critical hand-instrumented database operations.",
    labelnames=("operation",),
    registry=REGISTRY,
)


def configure_telemetry(app: FastAPI, settings: Settings) -> None:
    """Wire up Prometheus metrics (+ optional OpenTelemetry tracing)."""
    if settings.METRICS_ENABLED:
        Instrumentator(
            should_group_status_codes=True,
            should_ignore_untemplated=True,
            excluded_handlers=["/health/live", "/health/ready", "/metrics"],
            registry=REGISTRY,
        ).instrument(app).expose(app, endpoint="/metrics", include_in_schema=False)

    if not settings.OTEL_ENABLED:
        logger.info("otel_tracing_disabled")
        return

    resource = Resource.create({SERVICE_NAME: settings.OTEL_SERVICE_NAME})
    provider = TracerProvider(resource=resource)
    exporter = OTLPSpanExporter(endpoint=f"{settings.OTEL_EXPORTER_OTLP_ENDPOINT}/v1/traces")
    provider.add_span_processor(BatchSpanProcessor(exporter))
    trace.set_tracer_provider(provider)
    FastAPIInstrumentor.instrument_app(app, tracer_provider=provider)
    logger.info("otel_tracing_enabled", endpoint=settings.OTEL_EXPORTER_OTLP_ENDPOINT)
