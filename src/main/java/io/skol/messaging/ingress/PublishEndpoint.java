package io.skol.messaging.ingress;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.skol.messaging.ws.KnownHttpHeaders;
import io.smallrye.common.annotation.NonBlocking;
import io.vertx.core.http.HttpServerRequest;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import software.amazon.awssdk.services.eventbridge.EventBridgeAsyncClient;
import software.amazon.awssdk.services.eventbridge.model.PutEventsRequestEntry;
import software.amazon.awssdk.services.eventbridge.model.PutEventsResponse;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import static java.util.function.Predicate.not;

@ApplicationScoped
@Path("")
public class PublishEndpoint {

    public static class MessageIngestParams {
        @HeaderParam(KnownHttpHeaders.REQUEST_ID)
        UUID requestId;
        @HeaderParam(KnownHttpHeaders.CORRELATION_ID)
        UUID correlationId;

        @HeaderParam(KnownHttpHeaders.DATE)
        OffsetDateTime occurredAsOf;

        @HeaderParam(KnownHttpHeaders.EVENT_KIND)
        String eventKind;

        @HeaderParam(KnownHttpHeaders.ENVIRONMENT)
        String environment;

        @HeaderParam(KnownHttpHeaders.SOURCE)
        String source;
    }

    record MessageIngested(List<Map.Entry<String, String>> metadata, Object data) {}

    ObjectMapper serializer;
    EventBridgeAsyncClient publisher;
    Logger logger;

    public PublishEndpoint(ObjectMapper serializer, EventBridgeAsyncClient publisher) {
        this.serializer = serializer;
        this.publisher = publisher;
        this.logger = LoggerFactory.getLogger(PublishEndpoint.class);
    }

    @POST
    @Path("/v1/messaging/publish")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    @NonBlocking
    public Response runAsync(
            @BeanParam MessageIngestParams params,
            Object payload,
            HttpServerRequest req) throws JsonProcessingException {

        List<Map.Entry<String, String>> headers = req.headers().entries().stream()
                .filter(not(PublishEndpoint::poisoned))
                .collect(Collectors.toList());

        PutEventsRequestEntry msg = PutEventsRequestEntry.builder()
                .detailType(params.eventKind)
                .source(params.source)
                .detail(serializer.writeValueAsString(new MessageIngested(headers, payload)))
                .build();

        publisher.putEvents(e -> e.entries(msg).build()).whenCompleteAsync((res, err) -> {
            if (res.failedEntryCount() > 0) {
                Log.failed(logger, msg, err);
            } else {
                Log.published(logger, res);
            }
        });

        return Response.accepted().build();
    }

    static boolean poisoned(Map.Entry<String, String> header) {
        return PoisonedHeaderNames.stream().anyMatch(header.getKey()::equalsIgnoreCase);
    }

    static final List<String> PoisonedHeaderNames = List.of(
            KnownHttpHeaders.CONNECTION,

            KnownHttpHeaders.ACCEPT, KnownHttpHeaders.HOST, KnownHttpHeaders.USER_AGENT, KnownHttpHeaders.UPGRADE,
            KnownHttpHeaders.CONTENT_TYPE, KnownHttpHeaders.CONTENT_LENGTH,
            KnownHttpHeaders.TRANSFER_ENCODING,
            KnownHttpHeaders.KEEP_ALIVE, KnownHttpHeaders.PROXY_CONNECTION,

            KnownHttpHeaders.AUTHORIZATION, KnownHttpHeaders.PROXY_AUTHORIZATION, KnownHttpHeaders.WWW_AUTHENTICATE, KnownHttpHeaders.PROXY_AUTHENTICATE,
            KnownHttpHeaders.DATE);

    static class Log {
        static void failed(Logger log, PutEventsRequestEntry msg, Throwable ex) {
            log.error("failed to publish event {} to EventBridge: {}", msg, ex.toString());
        }

        static void published(Logger log, PutEventsResponse res) {
            log.info("Published event {}", res.entries().getFirst().eventId());
        }
    }
}
