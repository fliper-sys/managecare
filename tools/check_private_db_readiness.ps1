param(
  [string]$BaseUrl = "https://backend.managecare.info",
  [string]$Email = "migration-check-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())@example.com",
  [string]$Password = "Test1234!"
)

$ErrorActionPreference = "Stop"

function Invoke-Json {
  param(
    [string]$Method,
    [string]$Url,
    [object]$Body = $null,
    [hashtable]$Headers = @{}
  )

  $params = @{
    Method = $Method
    Uri = $Url
    Headers = $Headers
    ContentType = "application/json"
  }
  if ($null -ne $Body) {
    $params.Body = ($Body | ConvertTo-Json -Depth 20 -Compress)
  }
  Invoke-RestMethod @params
}

Write-Host "== ManageCare private database readiness =="
Write-Host "Backend: $BaseUrl"

Write-Host "`n[1/5] Health endpoint"
try {
  $health = Invoke-Json -Method GET -Url "$BaseUrl/api/health"
  if ($health.status -ne "ok") {
    throw "Health check did not return status=ok"
  }
  Write-Host "OK: database=$($health.database)"
} catch {
  Write-Host "FAILED: /api/health is not open on the deployed backend."
  Write-Host "This usually means nginx/DNS is pointing at the wrong service, the latest server.js is not deployed, or an upstream auth gate is protecting health checks."
  throw
}

Write-Host "`n[2/5] GoTrue-compatible signup"
$signup = Invoke-Json -Method POST -Url "$BaseUrl/auth/v1/signup" -Body @{
  email = $Email
  password = $Password
  data = @{ full_name = "Migration Check" }
}
if (-not $signup.access_token -or -not $signup.user.id) {
  throw "Signup did not return access_token and user.id"
}
Write-Host "OK: user=$($signup.user.id)"

$authHeaders = @{
  Authorization = "Bearer $($signup.access_token)"
  apikey = "public-readiness-check"
}

Write-Host "`n[3/5] REST compatibility (/rest/v1/profiles)"
$profile = Invoke-Json -Method GET -Url "$BaseUrl/rest/v1/profiles?id=eq.$($signup.user.id)&limit=1" -Headers $authHeaders
if (-not $profile -or $profile.Count -eq 0) {
  throw "REST profile lookup returned no rows"
}
Write-Host "OK: /rest/v1/profiles returned $($profile.Count) row(s)"

Write-Host "`n[4/5] RPC compatibility"
$summary = Invoke-Json -Method POST -Url "$BaseUrl/rest/v1/rpc/get_daily_sales_summary" -Headers $authHeaders -Body @{
  p_business_id = "00000000-0000-0000-0000-000000000000"
}
Write-Host "OK: get_daily_sales_summary responded"

Write-Host "`n[5/5] Local Flutter Firebase reference inventory"
$firebaseRefs = rg "FirebaseFirestore|FirebaseAuth|FirebaseStorage|firebase_storage|cloud_firestore|firebase_auth" lib -l
$count = 0
if ($LASTEXITCODE -eq 0 -and $firebaseRefs) {
  $count = ($firebaseRefs | Measure-Object).Count
}
Write-Host "Remaining Dart files with Firebase data/auth/storage references: $count"
if ($count -gt 0) {
  Write-Host "These must be migrated or intentionally classified as push/admin legacy before Firebase can be removed."
}

Write-Host "`nREADY CHECK COMPLETE"
