#!/bin/bash
# God Level Smoke Test Script
# Usage: ./smoke-test.sh <APP_URL>

APP_URL=$1
echo "🐣 Starting Canary Smoke Test on $APP_URL..."

# 1. Check Liveness (Is the app alive?)
STATUS_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" $APP_URL/health)

# 2. Check Readiness (Is the DB connected?)
STATUS_READY=$(curl -s -o /dev/null -w "%{http_code}" $APP_URL/ready)

if [ "$STATUS_HEALTH" == "200" ] && [ "$STATUS_READY" == "200" ]; then
  echo "✅ SMOKE TEST SUCCESS: New version is healthy and connected to DB."
  exit 0
else
  echo "❌ SMOKE TEST FAILED: Health ($STATUS_HEALTH), Ready ($STATUS_READY)"
  echo "🚨 ABORTING CANARY: New version is unstable!"
  exit 1
fi
