package io.skol.resthooks.lambda;

import java.util.UUID;
import com.fasterxml.jackson.annotation.JsonProperty;

public record Ack(@JsonProperty("correlation_id") UUID correlationId) {
}
