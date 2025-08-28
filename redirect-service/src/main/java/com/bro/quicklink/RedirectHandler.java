package com.bro.quicklink;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayV2HTTPEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayV2HTTPResponse;
import com.fasterxml.jackson.databind.ObjectMapper;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.GetItemRequest;
import software.amazon.awssdk.services.eventbridge.EventBridgeClient;
import software.amazon.awssdk.services.eventbridge.model.PutEventsRequest;
import software.amazon.awssdk.services.eventbridge.model.PutEventsRequestEntry;

import java.util.Collections;
import java.util.Map;

public class RedirectHandler implements RequestHandler<APIGatewayV2HTTPEvent, APIGatewayV2HTTPResponse> {

    private final DynamoDbClient dynamoDbClient;
    private final EventBridgeClient eventBridgeClient;
    private final ObjectMapper objectMapper = new ObjectMapper();
    private final String tableName;
    private final String eventBusName;

    public RedirectHandler() {
        this.dynamoDbClient = DynamoDbClient.builder().region(Region.US_EAST_1).build();
        this.eventBridgeClient = EventBridgeClient.builder().region(Region.US_EAST_1).build();
        this.tableName = System.getenv("TABLE_NAME");
        this.eventBusName = System.getenv("EVENT_BUS_NAME");
    }

    @Override
    public APIGatewayV2HTTPResponse handleRequest(APIGatewayV2HTTPEvent event, Context context) {
        String shortCode = event.getPathParameters().get("shortCode");

        if (shortCode == null || shortCode.trim().isEmpty()) {
            return createErrorResponse(400, "Short code is missing.");
        }

        Map<String, AttributeValue> returnedItem = dynamoDbClient.getItem(GetItemRequest.builder()
                .tableName(tableName)
                .key(Map.of("shortCode", AttributeValue.builder().s(shortCode).build()))
                .build()).item();

        if (returnedItem != null && returnedItem.containsKey("originalUrl")) {
            publishUrlAccessedEvent(shortCode);
            return APIGatewayV2HTTPResponse.builder()
                    .withStatusCode(302)
                    .withHeaders(Map.of("Location", returnedItem.get("originalUrl").s()))
                    .build();
        } else {
            return createErrorResponse(404, "URL not found.");
        }
    }

    private void publishUrlAccessedEvent(String shortCode) {
        try {
            String detailJson = objectMapper.writeValueAsString(Map.of("shortCode", shortCode));
            PutEventsRequestEntry requestEntry = PutEventsRequestEntry.builder()
                    .eventBusName(eventBusName)
                    .source("com.bro.quicklink.redirect-service")
                    .detailType("UrlAccessedEvent")
                    .detail(detailJson)
                    .build();
            eventBridgeClient.putEvents(PutEventsRequest.builder().entries(requestEntry).build());
        } catch (Exception e) {
            // Log the exception but do not fail the redirect
        }
    }

    private APIGatewayV2HTTPResponse createErrorResponse(int statusCode, String message) {
        return APIGatewayV2HTTPResponse.builder()
                .withStatusCode(statusCode)
                .withHeaders(Map.of("Content-Type", "application/json"))
                .withBody("{\"error\": \"" + message + "\"}")
                .build();
    }
}