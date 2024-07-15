package io.skol.resthooks.lambda;

import com.fasterxml.jackson.databind.JsonNode;

public record Event(JsonNode metadata, JsonNode data) {
}
