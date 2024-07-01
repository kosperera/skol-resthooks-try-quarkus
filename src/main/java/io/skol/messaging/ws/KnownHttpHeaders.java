package io.skol.messaging.ws;

import jakarta.ws.rs.core.HttpHeaders;

public interface KnownHttpHeaders extends HttpHeaders {
    String CONNECTION = "Connection";
    String KEEP_ALIVE = "Keep-Alive";
    String PROXY_AUTHENTICATE = "Proxy-Authenticate";
    String PROXY_AUTHORIZATION = "Proxy-Authorization";
    String PROXY_CONNECTION = "Proxy-Connection";
    String REQUEST_ID = "Request-Id";
    String TRANSFER_ENCODING = "Transfer-Encoding";
    String UPGRADE = "Upgrade";

    String CORRELATION_ID = "X-Correlation-Id";
    String EVENT_KIND = "X-Event-Kind";
    String ENVIRONMENT = "X-Environment";
    String SOURCE = "X-Source";
    String TRACE_ID = "X-Amzn-Trace-Id";
}
