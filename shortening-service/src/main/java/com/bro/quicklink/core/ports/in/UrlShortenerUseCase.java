package com.bro.quicklink.core.ports.in;

import com.bro.quicklink.core.domain.UrlMapping;

/**
 * This is an Input Port. It defines the contract for the primary use case
 * of our application, which is to create a shortened URL.
 */
public interface UrlShortenerUseCase {

    /**
     * Takes an original URL and returns a new, persisted UrlMapping.
     * @param originalUrl The URL to be shortened.
     * @return The created UrlMapping domain object.
     */
    UrlMapping createShortUrl(String originalUrl);
}