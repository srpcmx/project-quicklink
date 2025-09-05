package com.bro.quicklink;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayV2WebSocketEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayV2WebSocketResponse;
import com.amazonaws.services.lambda.runtime.events.DynamodbEvent;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.MapperFeature;
import software.amazon.awssdk.core.SdkBytes;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.apigatewaymanagementapi.ApiGatewayManagementApiClient;
import software.amazon.awssdk.services.apigatewaymanagementapi.model.PostToConnectionRequest;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.DeleteItemRequest;
import software.amazon.awssdk.services.dynamodb.model.PutItemRequest;
import software.amazon.awssdk.services.dynamodb.model.ScanRequest;

import java.net.URI;
import java.util.List;
import java.util.Map;

public class DashboardHandler implements RequestHandler<Map<String, Object>, Object> {

    private final DynamoDbClient dynamoDbClient;
    private final ApiGatewayManagementApiClient apiGatewayManagementApiClient;
    private final ObjectMapper objectMapper;
    private final String connectionsTableName;

    public DashboardHandler() {
        this.dynamoDbClient = DynamoDbClient.builder().region(Region.of(System.getenv("AWS_REGION"))).build();
        this.connectionsTableName = System.getenv("CONNECTIONS_TABLE_NAME");
        String endpoint = "https://" + System.getenv("WEBSOCKET_API_ID") + ".execute-api." + System.getenv("AWS_REGION") + ".amazonaws.com/" + System.getenv("WEBSOCKET_API_STAGE");
        this.apiGatewayManagementApiClient = ApiGatewayManagementApiClient.builder()
                .endpointOverride(URI.create(endpoint))
                .region(Region.of(System.getenv("AWS_REGION")))
                .build();
        // This configuration will prevent the error
        this.objectMapper = new ObjectMapper()
                .configure(MapperFeature.ACCEPT_CASE_INSENSITIVE_PROPERTIES, true)
                .configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false)
                .configure(DeserializationFeature.READ_DATE_TIMESTAMPS_AS_NANOSECONDS, false);
    }

    @Override
    public Object handleRequest(Map<String, Object> event, Context context) {
        if (event.containsKey("Records")) {
            try {
                normalizeDdbApproxDate(event); // 👈 clave: normalizar segundos → milisegundos long
                byte[] json = objectMapper.writeValueAsBytes(event);
                DynamodbEvent ddbEvent = objectMapper.readValue(json, DynamodbEvent.class);

                if (ddbEvent.getRecords() == null || ddbEvent.getRecords().isEmpty()) {
                    context.getLogger().log("DDB event without records (after mapping): " + new String(json));
                    return "No DDB records";
                }

                handleDynamoDbStreamEvent(ddbEvent);
                return "OK";
            } catch (Exception e) {
                context.getLogger().log("Failed to parse DDB event: " + e.getMessage());
                return "Bad DDB event";
            }
        } else if (event.containsKey("requestContext")) {
            return handleWebSocketEvent(objectMapper.convertValue(event, APIGatewayV2WebSocketEvent.class));
        }
        return "Unsupported event type";
    }

    @SuppressWarnings("unchecked")
    private static void normalizeDdbApproxDate(Map<String, Object> eventMap) {
        Object recs = eventMap.get("Records");
        if (!(recs instanceof List<?> records)) return;

        for (Object r : records) {
            if (!(r instanceof Map<?, ?> rm)) continue;
            Object dyn = rm.get("dynamodb");
            if (!(dyn instanceof Map<?, ?> dm)) continue;

            Object tsObj = ((Map<String, Object>) dm).get("ApproximateCreationDateTime");
            if (tsObj instanceof Number n) {
                // segundos (posible Double) → milisegundos (long entero)
                long millis = (long) Math.round(n.doubleValue() * 1000d);
                ((Map<String, Object>) dm).put("ApproximateCreationDateTime", millis);
            }
        }
    }

    private APIGatewayV2WebSocketResponse handleWebSocketEvent(APIGatewayV2WebSocketEvent event) {
        String routeKey = event.getRequestContext().getRouteKey();
        String connectionId = event.getRequestContext().getConnectionId();

        switch (routeKey) {
            case "$connect":
                dynamoDbClient.putItem(PutItemRequest.builder()
                        .tableName(connectionsTableName)
                        .item(Map.of("connectionId", AttributeValue.builder().s(connectionId).build()))
                        .build());
                break;
            case "$disconnect":
                dynamoDbClient.deleteItem(DeleteItemRequest.builder()
                        .tableName(connectionsTableName)
                        .key(Map.of("connectionId", AttributeValue.builder().s(connectionId).build()))
                        .build());
                break;
        }

        APIGatewayV2WebSocketResponse response = new APIGatewayV2WebSocketResponse();
        response.setStatusCode(200);
        response.setBody("OK");
        return response;
    }

    private void handleDynamoDbStreamEvent(DynamodbEvent ddbEvent) {
        for (DynamodbEvent.DynamodbStreamRecord record : ddbEvent.getRecords()) {
            if (!"INSERT".equals(record.getEventName()) && !"MODIFY".equals(record.getEventName())) continue;
            var stream = record.getDynamodb();
            if (stream == null || stream.getNewImage() == null) continue;

            String shortCode = stream.getNewImage().get("shortCode").getS();
            String clicks    = stream.getNewImage().get("clicks").getN();

            String message = "{\"shortCode\":\"" + shortCode + "\",\"clicks\":" + clicks + "}";

            List<String> connectionIds = dynamoDbClient.scan(ScanRequest.builder()
                            .tableName(connectionsTableName).build())
                    .items().stream()
                    .map(item -> item.get("connectionId").s())
                    .toList();

            for (String connectionId : connectionIds) {
                apiGatewayManagementApiClient.postToConnection(PostToConnectionRequest.builder()
                        .connectionId(connectionId)
                        .data(SdkBytes.fromUtf8String(message))
                        .build());
            }
        }
    }
}