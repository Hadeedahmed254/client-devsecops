package com.example.bankapp.service;

import io.getunleash.Unleash;
import io.getunleash.variant.Variant;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * ⚑ Feature Flag Service (GOD LEVEL)
 *
 * Central service for ALL feature flag checks in the BankApp.
 * Controllers and Services should NEVER call Unleash directly —
 * always go through this service so flags can be easily mocked in tests.
 *
 * USAGE EXAMPLE:
 *   @Autowired FeatureFlagService flags;
 *   if (flags.isNewDashboardEnabled()) { ... new code ... }
 *   else                               { ... old code ... }
 *
 * FLAG REGISTRY (must match names in Unleash dashboard):
 *   ┌──────────────────────────────┬──────────────────────────────────────────────┐
 *   │ Flag Name                    │ Purpose                                      │
 *   ├──────────────────────────────┼──────────────────────────────────────────────┤
 *   │ bankapp.new-dashboard        │ New UI dashboard (A/B test - 10% rollout)    │
 *   │ bankapp.instant-transfer     │ Instant transfer feature (canary release)    │
 *   │ bankapp.maintenance-mode     │ Kill-switch: shows maintenance page          │
 *   │ bankapp.enhanced-security    │ Extra 2FA for transactions > $5000           │
 *   └──────────────────────────────┴──────────────────────────────────────────────┘
 */
@Service
public class FeatureFlagService {

    private static final Logger log = LoggerFactory.getLogger(FeatureFlagService.class);

    // Flag name constants — avoids magic strings scattered across code
    public static final String FLAG_NEW_DASHBOARD     = "bankapp.new-dashboard";
    public static final String FLAG_INSTANT_TRANSFER  = "bankapp.instant-transfer";
    public static final String FLAG_MAINTENANCE_MODE  = "bankapp.maintenance-mode";
    public static final String FLAG_ENHANCED_SECURITY = "bankapp.enhanced-security";

    private final Unleash unleash;

    public FeatureFlagService(Unleash unleash) {
        this.unleash = unleash;
    }

    /**
     * Checks if the new dashboard UI is enabled.
     * Typically rolled out to 10% of users first.
     */
    public boolean isNewDashboardEnabled() {
        boolean enabled = unleash.isEnabled(FLAG_NEW_DASHBOARD);
        log.debug("Feature flag [{}] = {}", FLAG_NEW_DASHBOARD, enabled);
        return enabled;
    }

    /**
     * Checks if the Instant Transfer feature is live.
     * Deployed behind a flag to decouple deploy from release.
     */
    public boolean isInstantTransferEnabled() {
        boolean enabled = unleash.isEnabled(FLAG_INSTANT_TRANSFER);
        log.debug("Feature flag [{}] = {}", FLAG_INSTANT_TRANSFER, enabled);
        return enabled;
    }

    /**
     * Kill-switch: if ON, all traffic sees the maintenance page.
     * Flip this in Unleash to instantly take the app offline safely.
     */
    public boolean isMaintenanceModeActive() {
        boolean enabled = unleash.isEnabled(FLAG_MAINTENANCE_MODE);
        if (enabled) {
            log.warn("⚠️ MAINTENANCE MODE IS ACTIVE — all requests will be redirected.");
        }
        return enabled;
    }

    /**
     * Checks if enhanced security (extra 2FA) is required for large transactions.
     */
    public boolean isEnhancedSecurityEnabled() {
        boolean enabled = unleash.isEnabled(FLAG_ENHANCED_SECURITY);
        log.debug("Feature flag [{}] = {}", FLAG_ENHANCED_SECURITY, enabled);
        return enabled;
    }

    /**
     * Returns a JSON-safe map of ALL current flag states.
     * Used by the /api/feature-flags health endpoint for observability.
     */
    public java.util.Map<String, Boolean> getAllFlags() {
        java.util.Map<String, Boolean> flags = new java.util.LinkedHashMap<>();
        flags.put(FLAG_NEW_DASHBOARD,     isNewDashboardEnabled());
        flags.put(FLAG_INSTANT_TRANSFER,  isInstantTransferEnabled());
        flags.put(FLAG_MAINTENANCE_MODE,  isMaintenanceModeActive());
        flags.put(FLAG_ENHANCED_SECURITY, isEnhancedSecurityEnabled());
        return flags;
    }
}
