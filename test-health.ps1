# Test Health Check Endpoints
Write-Host "Testing Health Check Endpoints..." -ForegroundColor Cyan

# Test /health endpoint
Write-Host "`n1. Testing /health endpoint..." -ForegroundColor Yellow
try {
    $healthResponse = Invoke-WebRequest -Uri "http://localhost:8080/health" -UseBasicParsing
    Write-Host "✅ Status Code: $($healthResponse.StatusCode)" -ForegroundColor Green
    Write-Host "Response:" -ForegroundColor Green
    $healthResponse.Content | ConvertFrom-Json | ConvertTo-Json
} catch {
    Write-Host "❌ Failed: $_" -ForegroundColor Red
}

# Test /ready endpoint
Write-Host "`n2. Testing /ready endpoint..." -ForegroundColor Yellow
try {
    $readyResponse = Invoke-WebRequest -Uri "http://localhost:8080/ready" -UseBasicParsing
    Write-Host "✅ Status Code: $($readyResponse.StatusCode)" -ForegroundColor Green
    Write-Host "Response:" -ForegroundColor Green
    $readyResponse.Content | ConvertFrom-Json | ConvertTo-Json
} catch {
    Write-Host "❌ Failed: $_" -ForegroundColor Red
}

Write-Host "`n✅ Health check tests complete!" -ForegroundColor Cyan
