package com.bro.quicklink.core.ports.out;

import com.bro.quicklink.core.domain.UrlMapping;
import java.util.Optional;

/**
 * This is an Output Port. It defines the contract for any persistence
 * adapter that needs to save or retrieve URL mappings.
 */
public interface UrlMappingRepository {

    UrlMapping save(UrlMapping urlMapping);

    Optional<UrlMapping> findByShortCode(String shortCode);
}