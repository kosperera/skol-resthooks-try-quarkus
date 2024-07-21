package io.skol.resthooks.lambda;

import java.util.UUID;
import com.fasterxml.jackson.annotation.JsonProperty;
import io.quarkus.runtime.annotations.RegisterForReflection;

// @RegisterForReflection
public record Ack(@JsonProperty("correlation_id") UUID correlationId) {
}
