package com.example.bankapp.controller;

import com.example.bankapp.service.FeatureFlagService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * ⚑ Feature Flag REST Controller
 *
 * Exposes a read-only endpoint so the CI/CD pipeline and monitoring
 * dashboards can verify which flags are ON in each environment.
 *
 * Endpoints:
 *   GET /api/feature-flags          → Returns all flag states (for observability)
 *
 * Used in the CI/CD smoke test step:
 *   curl -f http://$ALB_URL/api/feature-flags
 *   → Confirms Unleash is connected and flags are being served.
 */
@RestController
@RequestMapping("/api/feature-flags")
public class FeatureFlagController {

    private final FeatureFlagService featureFlagService;

    public FeatureFlagController(FeatureFlagService featureFlagService) {
        this.featureFlagService = featureFlagService;
    }

    /**
     * Returns the current state of all feature flags.
     * This is called by the smoke-test script after every deployment.
     *
     * Example response:
     * {
     *   "timestamp": "2026-03-05T09:47:00Z",
     *   "environment": "production",
     *   "flags": {
     *     "bankapp.new-dashboard": false,
     *     "bankapp.instant-transfer": true,
     *     "bankapp.maintenance-mode": false,
     *     "bankapp.enhanced-security": true
     *   }
     * }
     */
    @GetMapping
    public ResponseEntity<Map<String, Object>> getFeatureFlags() {
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("timestamp", Instant.now().toString());
        response.put("environment", System.getenv().getOrDefault("APP_ENV", "unknown"));
        response.put("flags", featureFlagService.getAllFlags());
        return ResponseEntity.ok(response);
    }
}
