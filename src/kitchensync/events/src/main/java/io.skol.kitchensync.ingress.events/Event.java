package io.skol.kitchensync.ingress.events;

import com.fasterxml.jackson.databind.JsonNode;
import io.quarkus.runtime.annotations.RegisterForReflection;

@RegisterForReflection
public record Event(JsonNode metadata, JsonNode data) {
}
