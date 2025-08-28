package com.bro.quicklink.core.service;

import com.bro.quicklink.core.domain.UrlMapping;
import com.bro.quicklink.core.ports.in.UrlShortenerUseCase;
import com.bro.quicklink.core.ports.out.EventPublisher;
import com.bro.quicklink.core.ports.out.UrlMappingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.UUID;

/**
 * This is the primary implementation of our application's core logic.
 * It implements the input port and uses output ports to perform its tasks.
 * Notice the @Service annotation from Spring, which marks it as a component.
 * The @RequiredArgsConstructor from Lombok creates a constructor for our final fields.
 */
@Service
@RequiredArgsConstructor
public class UrlShortenerService implements UrlShortenerUseCase {

    // These are our connections to the outside world (output ports).
    // We depend on the interfaces, not the concrete implementations.
    private final UrlMappingRepository urlMappingRepository;
    private final EventPublisher eventPublisher;

    @Override
    public UrlMapping createShortUrl(String originalUrl) {
        // 1. Generate a unique short code.
        // For now, we'll use a simple method. This can be replaced with a more
        // sophisticated algorithm (like Base62 encoding) later without
        // changing the core architecture.
        String shortCode = generateShortCode();

        // 2. Create the domain object.
        UrlMapping newMapping = new UrlMapping(
                shortCode,
                originalUrl,
                Instant.now()
        );

        // 3. Persist the new mapping using the repository output port.
        UrlMapping savedMapping = urlMappingRepository.save(newMapping);

        // 4. Publish an event using the event publisher output port.
        // The event object itself could be more complex, but for now,
        // we'll just send the domain object.
        eventPublisher.publishUrlCreatedEvent(savedMapping);

        // 5. Return the created object.
        return savedMapping;
    }

    /**
     * Generates a short, pseudo-unique identifier.
     * @return A 7-character string.
     */
    private String generateShortCode() {
        // A simple implementation using the first 7 chars of a UUID.
        return UUID.randomUUID().toString().substring(0, 7);
    }
}