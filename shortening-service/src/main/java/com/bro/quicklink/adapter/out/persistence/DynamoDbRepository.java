package com.bro.quicklink.adapter.out.persistence;

import com.bro.quicklink.core.domain.UrlMapping;
import com.bro.quicklink.core.ports.out.UrlMappingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.GetItemRequest;
import software.amazon.awssdk.services.dynamodb.model.PutItemRequest;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

/**
 * This is an Output Adapter. It implements the repository port for DynamoDB.
 * It translates domain objects into DynamoDB items and vice-versa.
 */
@Repository
@RequiredArgsConstructor
public class DynamoDbRepository implements UrlMappingRepository {

    private final DynamoDbClient dynamoDbClient;
    private final String TABLE_NAME = "quicklink-mappings"; // We will create this with Terraform

    @Override
    public UrlMapping save(UrlMapping urlMapping) {
        Map<String, AttributeValue> item = new HashMap<>();
        item.put("shortCode", AttributeValue.builder().s(urlMapping.shortCode()).build());
        item.put("originalUrl", AttributeValue.builder().s(urlMapping.originalUrl()).build());
        item.put("createdAt", AttributeValue.builder().s(urlMapping.createdAt().toString()).build());

        PutItemRequest request = PutItemRequest.builder()
                .tableName(TABLE_NAME)
                .item(item)
                .build();

        dynamoDbClient.putItem(request);
        return urlMapping;
    }

    @Override
    public Optional<UrlMapping> findByShortCode(String shortCode) {
        Map<String, AttributeValue> keyToGet = new HashMap<>();
        keyToGet.put("shortCode", AttributeValue.builder().s(shortCode).build());

        GetItemRequest request = GetItemRequest.builder()
                .key(keyToGet)
                .tableName(TABLE_NAME)
                .build();

        Map<String, AttributeValue> returnedItem = dynamoDbClient.getItem(request).item();

        if (returnedItem != null && !returnedItem.isEmpty()) {
            UrlMapping mapping = new UrlMapping(
                    returnedItem.get("shortCode").s(),
                    returnedItem.get("originalUrl").s(),
                    Instant.parse(returnedItem.get("createdAt").s())
            );
            return Optional.of(mapping);
        } else {
            return Optional.empty();
        }
    }
}