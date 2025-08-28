package com.bro.quicklink;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.UpdateItemRequest;

import java.util.Map;

public class AnalyticsHandler implements RequestHandler<Map<String, Object>, Void> {

    private final DynamoDbClient dynamoDbClient;
    private final String tableName;

    public AnalyticsHandler() {
        this.dynamoDbClient = DynamoDbClient.builder()
                .region(Region.US_EAST_1)
                .build();
        this.tableName = System.getenv("ANALYTICS_TABLE_NAME");
    }

    @Override
    public Void handleRequest(Map<String, Object> event, Context context) {
        // Manually parse the 'detail' field from the EventBridge event
        if (event.containsKey("detail")) {
            Map<String, Object> detail = (Map<String, Object>) event.get("detail");
            String shortCode = (String) detail.get("shortCode");

            if (shortCode != null) {
                UpdateItemRequest request = UpdateItemRequest.builder()
                        .tableName(tableName)
                        .key(Map.of("shortCode", AttributeValue.builder().s(shortCode).build()))
                        .updateExpression("ADD clicks :inc")
                        .expressionAttributeValues(Map.of(":inc", AttributeValue.builder().n("1").build()))
                        .build();

                dynamoDbClient.updateItem(request);
            }
        }
        return null;
    }
}