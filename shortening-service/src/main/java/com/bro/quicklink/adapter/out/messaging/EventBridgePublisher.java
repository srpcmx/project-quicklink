package com.bro.quicklink.adapter.out.messaging;

import com.bro.quicklink.core.domain.UrlMapping;
import com.bro.quicklink.core.ports.out.EventPublisher;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.SneakyThrows;
import org.springframework.stereotype.Component;
import software.amazon.awssdk.services.eventbridge.EventBridgeClient;
import software.amazon.awssdk.services.eventbridge.model.PutEventsRequest;
import software.amazon.awssdk.services.eventbridge.model.PutEventsRequestEntry;

import java.util.Collections;

/**
 * This is an Output Adapter. It implements the event publisher port for EventBridge.
 */
@Component
@RequiredArgsConstructor
public class EventBridgePublisher implements EventPublisher {

    private final EventBridgeClient eventBridgeClient;
    private final ObjectMapper objectMapper; // Spring Boot provides this bean by default
    private final String EVENT_BUS_NAME = "quicklink-event-bus"; // We will create this with Terraform

    @Override
    @SneakyThrows // A Lombok annotation to avoid boilerplate try/catch for the JSON conversion
    public void publishUrlCreatedEvent(Object event) {
        String eventJson = objectMapper.writeValueAsString(event);

        PutEventsRequestEntry requestEntry = PutEventsRequestEntry.builder()
                .eventBusName(EVENT_BUS_NAME)
                .source("com.bro.quicklink.shortening-service")
                .detailType("UrlCreatedEvent")
                .detail(eventJson)
                .build();

        PutEventsRequest request = PutEventsRequest.builder()
                .entries(Collections.singletonList(requestEntry))
                .build();

        eventBridgeClient.putEvents(request);
    }
}