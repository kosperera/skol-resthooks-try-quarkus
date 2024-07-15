package io.skol.resthooks.lambda;

import java.util.UUID;

public record Ack(UUID correlationId, Object data) {
}
