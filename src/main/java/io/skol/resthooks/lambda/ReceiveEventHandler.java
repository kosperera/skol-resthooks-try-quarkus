package io.skol.resthooks.lambda;

import java.util.UUID;
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayV2HTTPEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayV2HTTPResponse;
import com.amazonaws.services.lambda.runtime.logging.LogLevel;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.inject.Inject;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.http.HttpStatusCode;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectResponse;

public class ReceiveEventHandler
        implements RequestHandler<APIGatewayV2HTTPEvent, APIGatewayV2HTTPResponse> {

    @Inject
    S3Client s3;

    @Inject
    ObjectMapper serializer;

    @Override
    public APIGatewayV2HTTPResponse handleRequest(final APIGatewayV2HTTPEvent input,
            final Context context) {

        String content = input.getBody();
        String reqId = context.getAwsRequestId();

        try {
            // final Event im = this.serializer.readValue(content, Event.class);

            // final S3Client s3 = S3Client.builder().useArnRegion(true).build();
            final PutObjectRequest request = PutObjectRequest.builder()
                    .bucket("sb-s3-kitchensync-receiver-01").key("file-name-" + reqId + ".json")
                    .contentType("application/json").build();

            // s3.putObject(request, RequestBody.fromString(content));
            final Ack ack = new Ack(UUID.fromString(reqId), content);

            return OK(ack);
        } catch (Exception ex) {
            context.getLogger().log(ex.toString(), LogLevel.ERROR);
            return BadRequest(ex);
        }
    }

    private APIGatewayV2HTTPResponse OK(Ack data) throws JsonProcessingException {
        return APIGatewayV2HTTPResponse.builder().withStatusCode(HttpStatusCode.OK)
                .withBody(serializer.writeValueAsString(data)).build();
    }

    private APIGatewayV2HTTPResponse BadRequest(Exception ex) {
        return APIGatewayV2HTTPResponse.builder().withStatusCode(HttpStatusCode.BAD_REQUEST)
                .withBody(ex.toString()).build();
    }
}
