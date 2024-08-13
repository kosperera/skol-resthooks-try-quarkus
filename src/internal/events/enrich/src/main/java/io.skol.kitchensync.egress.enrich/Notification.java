package io.skol.kitchensync.egress.enrich;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.JsonNode;
import io.quarkus.runtime.annotations.RegisterForReflection;

import java.util.Date;
import java.util.List;
import java.util.UUID;

@RegisterForReflection
public record Notification(
        String version,
        UUID id,
        @JsonProperty("detail-type") String typeOf,
        String source,
        String account,
        Date time,
        String region,
        List<String> resources,
        JsonNode detail) {
}
