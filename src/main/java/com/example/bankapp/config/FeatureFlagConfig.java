package com.example.bankapp.config;

import io.getunleash.DefaultUnleash;
import io.getunleash.Unleash;
import io.getunleash.util.UnleashConfig;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * ⚑ Feature Flag Configuration (GOD LEVEL)
 *
 * Uses Unleash open-source feature flag server.
 * This config reads the Unleash server URL and app key from environment variables
 * (injected via AWS Secrets Manager / External Secrets Operator in Kubernetes).
 *
 * How it works:
 *   - Each feature flag is a toggle in the Unleash dashboard.
 *   - The client polls Unleash every 15s and caches flags locally.
 *   - If Unleash is unreachable, flags fall back to OFF (safe default).
 *
 * Feature Flags defined (see Unleash dashboard):
 *   - bankapp.new-dashboard      → Enables the new user dashboard UI
 *   - bankapp.instant-transfer   → Enables the instant bank transfer feature
 *   - bankapp.maintenance-mode   → Activates maintenance page (kill-switch)
 *   - bankapp.enhanced-security  → Enables extra 2FA step for high-value transactions
 */
@Configuration
public class FeatureFlagConfig {

    @Value("${unleash.server.url:http://unleash-service:4242/api}")
    private String unleashServerUrl;

    @Value("${unleash.api.key:default:development.unleash-insecure-api-token}")
    private String unleashApiKey;

    @Value("${spring.application.name:bankapp}")
    private String appName;

    @Bean
    public Unleash unleash() {
        UnleashConfig config = UnleashConfig.builder()
                .appName(appName)
                .instanceId("bankapp-" + System.getenv().getOrDefault("HOSTNAME", "local"))
                .unleashAPI(unleashServerUrl)
                .apiKey(unleashApiKey)
                // Poll Unleash server every 15 seconds for flag updates
                .fetchTogglesInterval(15)
                // Send usage metrics every 60 seconds
                .sendMetricsInterval(60)
                // If Unleash is unreachable, all flags are OFF (safe default)
                .build();

        return new DefaultUnleash(config);
    }
}
