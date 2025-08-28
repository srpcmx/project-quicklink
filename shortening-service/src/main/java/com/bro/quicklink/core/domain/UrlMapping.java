package com.bro.quicklink.core.domain;

import java.time.Instant;

/**
 * Represents the core domain entity of our service.
 * A simple, immutable record with no framework or infrastructure dependencies.
 */
public record UrlMapping(
        String shortCode,
        String originalUrl,
        Instant createdAt
) {}