package io.skol.resthooks.lambda;

import java.util.UUID;
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayV2HTTPEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayV2HTTPResponse;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.inject.Inject;
import software.amazon.awssdk.http.HttpStatusCode;

public class ReceiveEventHandler
        implements RequestHandler<APIGatewayV2HTTPEvent, APIGatewayV2HTTPResponse> {

    @Inject
    private ObjectMapper serializer;

    @Override
    public APIGatewayV2HTTPResponse handleRequest(final APIGatewayV2HTTPEvent input,
            final Context context) {

        String content = input.getBody();
        try {
            final Event im = this.serializer.readValue(content, Event.class);
            final Ack res =
                    new Ack(UUID.fromString(context.getAwsRequestId()), im);

            return OK(res);
        } catch (Exception e) {
            return BadRequest(e);
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
