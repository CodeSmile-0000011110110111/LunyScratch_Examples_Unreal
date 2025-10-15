<#
.SYNOPSIS
  Measures LOC and complexity proxy metrics for the LunyScratch package.

.DESCRIPTION
  Computes Lines of Code and simple complexity proxies for:
    - Core:   Packages\de.codesmile.lunyscratch_unity\Runtime\Core
    - Engine: Packages\de.codesmile.lunyscratch_unity\Runtime\<Unity|Godot|Unreal>
    - Editor: Packages\de.codesmile.lunyscratch_unity\Editor

  The script auto-detects the engine folder (Unity, Godot, or Unreal). If none
  are present, Engine metrics default to zero.

  Complexity proxies are derived from keyword/boolean counts:
    - decisions = counts of: if, for, foreach, while, switch, case, catch
    - booleanOps = counts of: &&, ||
    - CyclomaticProxy   = decisions + booleanOps
    - CognitiveProxy    = decisions + 0.5 * booleanOps
    - CyclomaticDensity = CyclomaticProxy / LOC
    - MaintainabilityProxy (0–100; higher is better)
        = max(0, 100 - 50 * CyclomaticDensity)

  Baseline comparison:
    - If -BaselineFile is provided (JSON), values are compared to it.
    - Otherwise, if the detected engine is Unity, compares against embedded
      baseline captured on 2025-10-15 for this repository:
        Core LOC=2368, Engine(Unity) LOC=989, Editor LOC=148, Unity+Editor LOC=1137, Total=3505
        Core CyclomaticProxy=235, CognitiveProxy=213
        Unity+Editor CyclomaticProxy=134, CognitiveProxy=123.5
    - Ranges reported for Maintainability and CyclomaticDensity:
        Maintainability: >=90 Good, 80–90 Watch, <80 Needs Attention
        CyclomaticDensity (per LOC): <0.12 Good, 0.12–0.20 Watch, >0.20 High

.PARAMETER PackageRoot
  Root folder of the LunyScratch package. Default: Packages\de.codesmile.lunyscratch_unity

.PARAMETER BaselineFile
  Optional path to a JSON file with baseline metrics to compare against.
  Example schema (numbers illustrative):
  {
    "Engine": "Unity",
    "Core": {"LOC":2368, "Cyclomatic":235, "Cognitive":213},
    "EngineEditor": {"LOC":1137, "Cyclomatic":134, "Cognitive":123.5},
    "Totals": {"LOC":3505}
  }

.EXAMPLE
  # Run with auto-detection and embedded Unity baseline
  .\Tools\Measure-LunyScratchMetrics.ps1

.EXAMPLE
  # Run and compare to a custom baseline JSON
  .\Tools\Measure-LunyScratchMetrics.ps1 -BaselineFile .\MetricsBaseline.json

.NOTES
  Run from the repository root. PowerShell 5+ compatible.
#>
[CmdletBinding()]
param(
  [string]$PackageRoot = "Packages\de.codesmile.lunyscratch_unity",
  [string]$BaselineFile
)

function Get-CsFiles([string]$dir) {
  if (-not (Test-Path $dir)) { return @() }
  Get-ChildItem -Recurse -LiteralPath $dir -Include *.cs | Where-Object { -not $_.PSIsContainer } | Select-Object -ExpandProperty FullName
}

function Count-Matches([string[]]$files, [string]$pattern) {
  if (-not $files -or $files.Count -eq 0) { return 0 }
  $res = Select-String -Path $files -Pattern $pattern -AllMatches -SimpleMatch:$false -ErrorAction SilentlyContinue |
    ForEach-Object { $_.Matches.Count } | Measure-Object -Sum
  if ($res.Sum) { return [int]$res.Sum } else { return 0 }
}

function Measure-Area([string]$path) {
  $files = Get-CsFiles $path
  $loc = if ($files.Count -gt 0) { (Get-Content -Path $files | Measure-Object -Line).Lines } else { 0 }
  # Regex patterns (word-boundaries for keywords; escaped for pipes)
  $patterns = @{
    if      = '\bif\b'
    for     = '\bfor\b'
    foreach = '\bforeach\b'
    while   = '\bwhile\b'
    switch  = '\bswitch\b'
    case    = '\bcase\b'
    catch   = '\bcatch\b'
    andAnd  = '&&'
    orOr    = '\|\|'
  }
  $counts = @{}
  foreach ($k in $patterns.Keys) { $counts[$k] = Count-Matches $files $patterns[$k] }
  $decisions = $counts.if + $counts.for + $counts.foreach + $counts.while + $counts.switch + $counts.case + $counts.catch
  $boolOps = $counts.andAnd + $counts.orOr
  $cyclomatic = $decisions + $boolOps
  $cognitive  = $decisions + (0.5 * $boolOps)
  $density    = if ($loc -gt 0) { $cyclomatic / $loc } else { 0 }
  $miProxy    = [math]::Max(0, 100 - 50 * $density)
  [pscustomobject]@{
    Files                 = $files.Count
    LOC                   = $loc
    Decisions             = $decisions
    BooleanOps            = $boolOps
    CyclomaticProxy       = [double]::Parse(($cyclomatic.ToString()))
    CognitiveProxy        = [double]::Parse(($cognitive.ToString('0.###')))
    CyclomaticPerLOC      = if ($loc -gt 0) { [double]::Parse(('{0:0.###}' -f $density)) } else { 0 }
    MaintainabilityProxy  = [double]::Parse(('{0:0.###}' -f $miProxy))
    RawCounts             = $counts
  }
}

function Describe-Range([double]$value, [double]$goodMax, [double]$warnMax, [switch]$HigherIsBetter) {
  if ($HigherIsBetter) {
    if ($value -ge $goodMax) { return 'Good' }
    elseif ($value -ge $warnMax) { return 'Watch' }
    else { return 'Needs Attention' }
  }
  else {
    if ($value -lt $goodMax) { return 'Good' }
    elseif ($value -le $warnMax) { return 'Watch' }
    else { return 'High' }
  }
}

function Load-Baseline([string]$engine) {
  if ($BaselineFile -and (Test-Path $BaselineFile)) {
    try { return Get-Content -Raw -LiteralPath $BaselineFile | ConvertFrom-Json } catch { }
  }
  if ($engine -eq 'Unity') {
    return [pscustomobject]@{
      Engine = 'Unity'
      Core = [pscustomobject]@{ LOC = 2368; Cyclomatic = 235; Cognitive = 213 }
      EngineEditor = [pscustomobject]@{ LOC = 1137; Cyclomatic = 134; Cognitive = 123.5 }
      Totals = [pscustomobject]@{ LOC = 3505 }
    }
  }
  return $null
}

# Resolve paths
$pkg = Join-Path -Path (Get-Location) -ChildPath $PackageRoot
$coreDir   = Join-Path $pkg 'Runtime\Core'
$unityDir  = Join-Path $pkg 'Runtime\Unity'
$godotDir  = Join-Path $pkg 'Runtime\Godot'
$unrealDir = Join-Path $pkg 'Runtime\Unreal'
$editorDir = Join-Path $pkg 'Editor'

$engine = $null
$engineDir = $null
if (Test-Path $unityDir) { $engine = 'Unity'; $engineDir = $unityDir }
elseif (Test-Path $godotDir) { $engine = 'Godot'; $engineDir = $godotDir }
elseif (Test-Path $unrealDir) { $engine = 'Unreal'; $engineDir = $unrealDir }
else { $engine = 'None'; $engineDir = $null }

# Measurements
$core   = Measure-Area $coreDir
$engineM = if ($engineDir) { Measure-Area $engineDir } else { [pscustomobject]@{ Files=0; LOC=0; Decisions=0; BooleanOps=0; CyclomaticProxy=0; CognitiveProxy=0; CyclomaticPerLOC=0; MaintainabilityProxy=100; RawCounts=@{} } }
$editor = Measure-Area $editorDir

$enginePlusEditorLoc = $engineM.LOC + $editor.LOC
$enginePlusEditorCyclo = $engineM.CyclomaticProxy + $editor.CyclomaticProxy
$enginePlusEditorCog   = $engineM.CognitiveProxy + $editor.CognitiveProxy

$totalLoc = $core.LOC + $enginePlusEditorLoc
$corePct = if ($totalLoc -gt 0) { [math]::Round(($core.LOC / $totalLoc) * 100, 0) } else { 0 }
$engEdPct = if ($totalLoc -gt 0) { [math]::Round(($enginePlusEditorLoc / $totalLoc) * 100, 0) } else { 0 }

$baseline = Load-Baseline $engine

# Output
Write-Host '=== LunyScratch Metrics ==='
Write-Host ('Package Root         : {0}' -f $pkg)
Write-Host ('Detected Engine      : {0}' -f $engine)
Write-Host ''

Write-Host '--- Lines of Code (LOC) ---'
Write-Host ('Core LOC            : {0}' -f $core.LOC)
Write-Host ('Engine LOC          : {0}' -f $engineM.LOC)
Write-Host ('Editor LOC          : {0}' -f $editor.LOC)
Write-Host ('Engine+Editor LOC   : {0}' -f $enginePlusEditorLoc)
Write-Host ('TOTAL LOC           : {0}' -f $totalLoc)
Write-Host ('Split               : Core {0}% | Engine+Editor {1}%' -f $corePct,$engEdPct)
if ($baseline) {
  Write-Host ('Baseline TOTAL LOC  : {0}' -f $baseline.Totals.LOC)
}
Write-Host ''

Write-Host '--- Complexity (proxies) ---'
Write-Host ('Core Cyclomatic     : {0}  | Cognitive: {1}' -f $core.CyclomaticProxy, $core.CognitiveProxy)
Write-Host ('Core Per-LOC        : {0}  | Maintainability: {1}' -f $core.CyclomaticPerLOC, $core.MaintainabilityProxy)
if ($baseline) {
  Write-Host ('Baseline Core Cyclo : {0}  | Cognitive: {1}' -f $baseline.Core.Cyclomatic, $baseline.Core.Cognitive)
}
Write-Host ''
Write-Host ('Eng+Ed Cyclomatic   : {0}  | Cognitive: {1}' -f $enginePlusEditorCyclo, ('{0:0.###}' -f $enginePlusEditorCog))
$engEdDensity = if ($enginePlusEditorLoc -gt 0) { [double]$enginePlusEditorCyclo / [double]$enginePlusEditorLoc } else { 0 }
$engEdMI = [math]::Max(0, 100 - 50 * $engEdDensity)
Write-Host ('Eng+Ed Per-LOC      : {0:0.###} | Maintainability: {1:0.###}' -f $engEdDensity, $engEdMI)
if ($baseline) {
  Write-Host ('Baseline Eng+Ed Cyc : {0}  | Cognitive: {1}' -f $baseline.EngineEditor.Cyclomatic, $baseline.EngineEditor.Cognitive)
}
Write-Host ''

# Ranges/ratings
$coreMiRating   = Describe-Range -value $core.MaintainabilityProxy -goodMax 90 -warnMax 80 -HigherIsBetter
$engEdMiRating  = Describe-Range -value $engEdMI -goodMax 90 -warnMax 80 -HigherIsBetter
$coreDenRating  = Describe-Range -value $core.CyclomaticPerLOC -goodMax 0.12 -warnMax 0.20
$engEdDenRating = Describe-Range -value $engEdDensity -goodMax 0.12 -warnMax 0.20
Write-Host '--- Baselines & Ranges ---'
Write-Host 'Maintainability ranges: >=90 Good, 80-90 Watch, <80 Needs Attention'
Write-Host 'Cyclomatic density ranges (per LOC): <0.12 Good, 0.12-0.20 Watch, >0.20 High'
Write-Host ('Core Ratings        : Maintainability={0} | CyclomaticDensity={1}' -f $coreMiRating, $coreDenRating)
Write-Host ('Eng+Ed Ratings      : Maintainability={0} | CyclomaticDensity={1}' -f $engEdMiRating, $engEdDenRating)
Write-Host ''

# Optional: emit JSON for automation
$summary = [pscustomobject]@{
  Timestamp = (Get-Date).ToString('s')
  Engine = $engine
  Core = [pscustomobject]@{
    LOC = $core.LOC
    Cyclomatic = $core.CyclomaticProxy
    Cognitive  = $core.CognitiveProxy
    PerLOC     = $core.CyclomaticPerLOC
    Maintainability = $core.MaintainabilityProxy
  }
  EngineEditor = [pscustomobject]@{
    LOC = $enginePlusEditorLoc
    Cyclomatic = $enginePlusEditorCyclo
    Cognitive  = [double]::Parse(('{0:0.###}' -f $enginePlusEditorCog))
    PerLOC     = [double]::Parse(('{0:0.###}' -f $engEdDensity))
    Maintainability = [double]::Parse(('{0:0.###}' -f $engEdMI))
  }
  Totals = [pscustomobject]@{ LOC = $totalLoc; CorePct = $corePct; EngineEditorPct = $engEdPct }
}

# Print compact JSON for CI log readability
# Write-Host '--- JSON Summary ---'
# $summary | ConvertTo-Json -Depth 5
