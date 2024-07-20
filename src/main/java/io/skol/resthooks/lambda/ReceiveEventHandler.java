package io.skol.resthooks.lambda;

import java.util.UUID;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.LambdaLogger;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayV2HTTPEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayV2HTTPResponse;
import com.amazonaws.services.lambda.runtime.logging.LogLevel;
import com.fasterxml.jackson.core.JacksonException;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.inject.Inject;
import software.amazon.awssdk.core.internal.util.Mimetype;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.http.HttpStatusCode;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;

public class ReceiveEventHandler implements RequestHandler<APIGatewayV2HTTPEvent, APIGatewayV2HTTPResponse> {

    final static String FILE_NAME_FORMAT = "%1$s/%2$s/%3$s-%4$s.json";

    @ConfigProperty(name = "BUCKET_NAME")
    String target;

    @Inject
    S3Client s3;

    @Inject
    ObjectMapper serializer;

    @Override
    public APIGatewayV2HTTPResponse handleRequest(final APIGatewayV2HTTPEvent input, final Context context) {

        final LambdaLogger logger = context.getLogger();

        final String env = input.getHeaders().getOrDefault(KnownHttpHeaders.ENVIRONMENT, "sandbox");
        final String source = input.getHeaders().getOrDefault(KnownHttpHeaders.SOURCE, "others");
        final String eventKind = input.getHeaders().getOrDefault(KnownHttpHeaders.EVENT_KIND, "noop");
        final String requestId = input.getHeaders().getOrDefault(KnownHttpHeaders.REQUEST_ID, context.getAwsRequestId());

        final String content = input.getBody();

        try {
            final Event im = this.serializer.readValue(content, Event.class);

            final String correlationId = input.getHeaders().getOrDefault(
                    KnownHttpHeaders.CORRELATION_ID,
                    im.metadata().get("correlation_id").asText(requestId));
            final String filepath = FILE_NAME_FORMAT.formatted(env, eventKind, source, correlationId)
                                                    .toLowerCase();

            s3.putObject(
                    PutObjectRequest.builder().bucket(target).key(filepath).contentType(Mimetype.MIMETYPE_TEXT_PLAIN).build(),
                    RequestBody.fromString(content));

            return OK(new Ack(UUID.fromString(correlationId)));

        } catch (S3Exception ex) {
            Log.UploadFailed(logger, ex);
            return BadRequest(ex);

        } catch (JacksonException jex) {
            Log.JsonParseFailed(logger, jex);
            return BadRequest(jex);
        }
    }

    private APIGatewayV2HTTPResponse OK(final Ack data) throws JsonProcessingException {
        return APIGatewayV2HTTPResponse.builder()
                                       .withStatusCode(HttpStatusCode.OK)
                                       .withBody(serializer.writeValueAsString(data))
                                       .build();
    }

    private APIGatewayV2HTTPResponse BadRequest(final Exception ex) {
        return APIGatewayV2HTTPResponse.builder()
                                       .withStatusCode(HttpStatusCode.INTERNAL_SERVER_ERROR)
                                       .withBody(ex.toString())
                                       .build();
    }

    static class Log {
        static void JsonParseFailed(final LambdaLogger logger, JacksonException ex) {
            logger.log(
                "Failed to deserialize request data: %1$s. %2$s".formatted(ex.getMessage(), ex.getStackTrace()),
                LogLevel.FATAL);
        }

        static void UploadFailed(final LambdaLogger logger, S3Exception ex) {
            logger.log(
                "Failed to upload the request data: %1$s. %2$s".formatted(ex.getMessage(), ex.getStackTrace()),
                LogLevel.ERROR);
        }
    }
}
