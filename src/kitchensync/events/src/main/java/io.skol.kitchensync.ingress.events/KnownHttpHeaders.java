package io.skol.kitchensync.ingress.events;

public interface KnownHttpHeaders {
    static final String DATE = "date";
    static final String ENVIRONMENT = "x-environment";
    static final String EVENT_KIND = "x-event-kind";
    static final String SOURCE = "x-source";
    static final String REQUEST_ID = "x-request-id";
    static final String CORRELATION_ID = "x-correlation-id";
}
