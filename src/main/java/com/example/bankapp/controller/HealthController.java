package com.example.bankapp.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.sql.DataSource;
import java.sql.Connection;
import java.util.HashMap;
import java.util.Map;

@RestController
public class HealthController {

    @Autowired
    private DataSource dataSource;

    /**
     * Liveness probe - checks if application is running
     * Kubernetes will restart the pod if this fails
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "UP");
        response.put("service", "bankapp");
        response.put("timestamp", System.currentTimeMillis());
        
        return ResponseEntity.ok(response);
    }

    /**
     * Readiness probe - checks if application is ready to serve traffic
     * Kubernetes will not send traffic if this fails
     */
    @GetMapping("/ready")
    public ResponseEntity<Map<String, Object>> ready() {
        Map<String, Object> response = new HashMap<>();
        Map<String, String> checks = new HashMap<>();
        
        // Check database connectivity
        boolean dbHealthy = checkDatabase();
        checks.put("database", dbHealthy ? "UP" : "DOWN");
        
        response.put("checks", checks);
        
        // If any check fails, return 503 Service Unavailable
        if (!dbHealthy) {
            response.put("status", "DOWN");
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(response);
        }
        
        response.put("status", "READY");
        return ResponseEntity.ok(response);
    }

    /**
     * Check if database connection is working
     */
    private boolean checkDatabase() {
        try (Connection connection = dataSource.getConnection()) {
            return connection.isValid(5); // 5 second timeout
        } catch (Exception e) {
            return false;
        }
    }
}
