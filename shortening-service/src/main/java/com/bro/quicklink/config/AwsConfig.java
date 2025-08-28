package com.bro.quicklink.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.eventbridge.EventBridgeClient;

@Configuration
public class AwsConfig {

    @Bean
    public DynamoDbClient dynamoDbClient() {
        // This creates a standard DynamoDB client.
        // The SDK will automatically use the credentials and region from your
        // environment (e.g., from `aws configure` or IAM role on Lambda).
        return DynamoDbClient.builder()
                .region(Region.US_EAST_1) // Or your preferred region
                .build();
    }

    @Bean
    public EventBridgeClient eventBridgeClient() {
        return EventBridgeClient.builder()
                .region(Region.US_EAST_1) // Must be the same region
                .build();
    }
}