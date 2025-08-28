package com.bro.quicklink.adapter.in.web;

import com.bro.quicklink.core.domain.UrlMapping;
import com.bro.quicklink.core.ports.in.UrlShortenerUseCase;
import com.bro.quicklink.core.ports.out.UrlMappingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/")
@RequiredArgsConstructor
public class UrlMappingController {

    private final UrlShortenerUseCase urlShortenerUseCase;
    private final UrlMappingRepository urlMappingRepository;

    @PostMapping("/links")
    public ResponseEntity<UrlMapping> createShortUrl(@RequestBody CreateShortUrlRequest request) {
        UrlMapping urlMapping = urlShortenerUseCase.createShortUrl(request.originalUrl());
        return ResponseEntity.ok(urlMapping);
    }

    @GetMapping("/links/{shortCode}")
    public ResponseEntity<UrlMapping> findByShortCode(@PathVariable String shortCode) {
        return urlMappingRepository.findByShortCode(shortCode)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    // A simple DTO for the request body
    public record CreateShortUrlRequest(String originalUrl) {}
}