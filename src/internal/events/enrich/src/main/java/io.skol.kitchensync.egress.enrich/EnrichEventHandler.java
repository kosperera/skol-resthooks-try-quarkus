package io.skol.kitchensync.egress.enrich;

import com.amazonaws.services.lambda.runtime.events.SQSEvent;
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.LambdaLogger;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.logging.LogLevel;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.inject.Inject;

import java.util.*;

public class EnrichEventHandler implements RequestHandler<SQSEvent.SQSMessage[], JsonNode[]> {
    @Inject
    ObjectMapper serializer;

    @Override
    public JsonNode[] handleRequest(final SQSEvent.SQSMessage[] input, final Context context) {
        final LambdaLogger logger = context.getLogger();
        try {
            JsonNode[] data = Arrays.stream(input).map(SQSEvent.SQSMessage::getBody)
                                                  .map(this::toObject)
                                                  .map(Notification::detail)
                                                  .toArray(JsonNode[]::new);

            Log.enriched(logger, context.getAwsRequestId(), context.getFunctionName(), context.getFunctionVersion(), data.length);

            return data;

        } catch (Exception ex) {
            Log.enrichFailed(logger, ex);
        }

        return new JsonNode[0];
    }

    Notification toObject(String json) {
        try {
            return serializer.readValue(json, Notification.class);
        } catch (JsonProcessingException ignored) {
        }

        return null;
    }

    static class Log {
        static void enriched(final LambdaLogger logger, String requestId, String fn, String ver, Integer len) {
            logger.log(
                    "Request %1$s enriched: (function = %2$s, version = %3$s, objects = %4$s)".formatted(requestId, fn, ver, len),
                    LogLevel.INFO);
        }

        static void enrichFailed(final LambdaLogger logger, Exception ex) {
            logger.log(
                    "Failed to enrich the request data: %1$s. %2$s".formatted(ex.getMessage(), ex.getStackTrace()),
                    LogLevel.ERROR);
        }
    }
}
