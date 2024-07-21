package io.skol.resthooks.lambda;

import com.fasterxml.jackson.databind.JsonNode;
import io.quarkus.runtime.annotations.RegisterForReflection;

@RegisterForReflection
public record Event(JsonNode metadata, JsonNode data) {
}
