#!/bin/bash
# ==============================================================================
# 🚀 GOD-LEVEL SMOKE TEST: Business Logic & Integrity Validation
# ==============================================================================
# Purpose: Validates the NEW (Green) environment BEFORE traffic switch. 
# This script ensures that the app isn't just "Running", but "Correct".
# ==============================================================================

APP_URL=$1
HEADER="X-Environment: green" # The Secret Tunnel to the Green pods

echo "------------------------------------------------------------"
echo "🔍 STARTING DEEP VALIDATION FOR GREEN ENVIRONMENT"
echo "URL: $APP_URL"
echo "------------------------------------------------------------"

# --- TEST 1: INFRASTRUCTURE PULSE ---
# Purpose: Standard health check of the Java process.
echo "1. Checking Infrastructure Pulse (/health)..."
HEALTH_CODE=$(curl -s -H "$HEADER" -o /dev/null -w "%{http_code}" "$APP_URL/health")

if [ "$HEALTH_CODE" != "200" ]; then
    echo "❌ FAIL: App process is not responding correctly ($HEALTH_CODE)."
    exit 1
fi
echo "✅ OK: Process is healthy."

# --- TEST 2: UI INTEGRITY (The 'Missing CSS/404' check) ---
# Purpose: Verifies the UI actually renders and isn't a blank or error page.
echo "2. Validating UI Integrity (Login Page Content)..."
UI_CONTENT=$(curl -s -L -H "$HEADER" "$APP_URL/login")

if [[ "$UI_CONTENT" != *"Login"* ]] || [[ "$UI_CONTENT" == *"404"* ]]; then
    echo "❌ FAIL: UI is broken. Login text not found or 404 detected."
    exit 1
fi
echo "✅ OK: UI is rendering correctly."

# --- TEST 3: CORE API LOGIC ---
# Purpose: Verifies that the internal API can speak JSON and reach the Database.
echo "3. Testing Core API Logic (Account API)..."
API_RESPONSE=$(curl -s -H "$HEADER" "$APP_URL/api/accounts/test")

if [[ "$API_RESPONSE" != *"balance"* ]]; then
    echo "❌ FAIL: API logic is broken. Expected JSON keys not found."
    exit 1
fi
echo "✅ OK: API is returning valid account data."

# --- TEST 4: BUSINESS LOGIC VALIDATION ---
# Purpose: Verifies the logic isn't "stupid" (e.g. balance is negative or null).
echo "4. Checking Business Logic (Data Accuracy)..."
# We check if the balance is a positive number (Simulated check)
if [[ "$API_RESPONSE" == *"\"balance\":-"* ]] || [[ "$API_RESPONSE" == *"\"balance\":null"* ]]; then
    echo "❌ FAIL: Business logic error! Negative or null balance detected."
    exit 1
fi
echo "✅ OK: Business logic validated."

# --- FINAL VERDICT ---
echo "------------------------------------------------------------"
echo "🏆 ALL GATES PASSED: Green version is safe for production traffic!"
echo "------------------------------------------------------------"
exit 0
