# Verifies an Apigee X org is ready for deployment:
# environments, instance attachments, environment groups and hostnames.
# Usage:  .\scripts\check-apigee-org.ps1                         (non-prod)
#         .\scripts\check-apigee-org.ps1 -Org apigee-prod-511508 (prod)
# Read-only: it changes nothing.

param(
  [string]$Org = "apigee-nonprod-511322"
)
$ErrorActionPreference = "Stop"

$token = (gcloud auth print-access-token).Trim()
$h = @{ Authorization = "Bearer $token" }
$api = "https://apigee.googleapis.com/v1/organizations/$Org"

function Section($title) { Write-Host "`n== $title" -ForegroundColor Cyan }

Section "Organization: $Org"
$o = Invoke-RestMethod -Uri $api -Headers $h
"state: $($o.state)   runtimeType: $($o.runtimeType)   billingType: $($o.billingType)"

Section "Environments"
$envs = Invoke-RestMethod -Uri "$api/environments" -Headers $h
if (-not $envs) { "(none)" } else { foreach ($e in $envs) { "  $e" } }

Section "Instances and attached environments"
$inst = @((Invoke-RestMethod -Uri "$api/instances" -Headers $h).instances)
if ($inst.Count -eq 0 -or $null -eq $inst[0]) { "(no instance)" }
foreach ($i in $inst) {
  if ($null -eq $i) { continue }
  "  $($i.name)   location=$($i.location)   state=$($i.state)"
  $att = @((Invoke-RestMethod -Uri "$api/instances/$($i.name)/attachments" -Headers $h).attachments)
  if ($att.Count -eq 0 -or $null -eq $att[0]) { "     (no environments attached)" }
  foreach ($a in $att) { if ($a) { "     attached env: $($a.environment)" } }
}

Section "Environment groups (hostnames)"
$groups = @((Invoke-RestMethod -Uri "$api/envgroups" -Headers $h).environmentGroups)
if ($groups.Count -eq 0 -or $null -eq $groups[0]) { "(no environment groups)" }
foreach ($g in $groups) {
  if ($null -eq $g) { continue }
  "  $($g.name)   hostnames: $($g.hostnames -join ', ')"
  $ga = @((Invoke-RestMethod -Uri "$api/envgroups/$($g.name)/attachments" -Headers $h).environmentGroupAttachments)
  if ($ga.Count -eq 0 -or $null -eq $ga[0]) { "     (no environments attached)" }
  foreach ($a in $ga) { if ($a) { "     attached env: $($a.environment)" } }
}
Write-Host ""