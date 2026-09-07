$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$certDirectory = Join-Path $root ".https"
$logDirectory = Join-Path $root "logs"
$keyPath = Join-Path $certDirectory "aki-lan-server-key.pem"
$certPath = Join-Path $certDirectory "aki-lan-server-cert.pem"

if (-not (Test-Path -LiteralPath $keyPath) -or -not (Test-Path -LiteralPath $certPath)) {
  throw "HTTPS server certificate is missing from $certDirectory"
}

New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null

$env:AKI_HTTPS_KEY = $keyPath
$env:AKI_HTTPS_CERT = $certPath

$servers = @(
  @{ Name = "vrm-avatar-studio"; Directory = "vrm-avatar-studio"; Arguments = @("run", "dev", "--", "--hostname", "0.0.0.0", "--port", "5173", "--experimental-https", "--experimental-https-key", $keyPath, "--experimental-https-cert", $certPath) },
  @{ Name = "pose-quiz-studio"; Directory = "pose-quiz-studio"; Arguments = @("run", "dev", "--", "--host", "0.0.0.0", "--port", "5174", "--strictPort") },
  @{ Name = "expression-api"; Directory = "expression-lab"; Port = "8788"; Arguments = @("run", "dev:api") },
  @{ Name = "expression-lab"; Directory = "expression-lab"; Arguments = @("run", "dev:web", "--", "--host", "0.0.0.0", "--port", "5175", "--strictPort") },
  @{ Name = "mediapipe-bench"; Directory = "mediapipe-bench"; DirectVite = $true; Arguments = @("--host", "0.0.0.0", "--port", "5176", "--strictPort") },
  @{ Name = "perfect-poses"; Directory = "perfect-poses"; Arguments = @("run", "dev", "--", "--host", "0.0.0.0", "--port", "5177", "--strictPort") },
  @{ Name = "kinetic-avatar-lab"; Directory = "kinetic-avatar-lab"; Arguments = @("run", "dev", "--", "--host", "0.0.0.0", "--port", "5178", "--strictPort") },
  @{ Name = "pose-pop-api"; Directory = "pose-pop"; Port = "8787"; Arguments = @("run", "dev:api") },
  @{ Name = "pose-pop"; Directory = "pose-pop"; Arguments = @("run", "dev:web", "--", "--host", "0.0.0.0", "--port", "5179", "--strictPort") }
)

foreach ($server in $servers) {
  if ($server.Port) {
    $listener = Get-NetTCPConnection -LocalPort ([int]$server.Port) -State Listen -ErrorAction SilentlyContinue
  } else {
    $portIndex = [Array]::IndexOf($server.Arguments, "--port")
    $port = [int]$server.Arguments[$portIndex + 1]
    $listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
  }

  if ($listener) {
    Write-Host "$($server.Name) is already listening; skipped."
    continue
  }

  $workingDirectory = Join-Path $root $server.Directory
  $stdout = Join-Path $logDirectory "$($server.Name).log"
  $stderr = Join-Path $logDirectory "$($server.Name)-error.log"

  if ($server.DirectVite) {
    $vite = Join-Path $root "pose-quiz-studio\node_modules\vite\bin\vite.js"
    $arguments = @($vite, ".") + $server.Arguments
    $executable = (Get-Command "node.exe" -ErrorAction Stop).Source
  } else {
    $arguments = $server.Arguments
    $executable = (Get-Command "npm.cmd" -ErrorAction Stop).Source
  }

  if ($server.Port) {
    $previousPort = $env:PORT
    $env:PORT = $server.Port
  }

  Start-Process -FilePath $executable -ArgumentList $arguments -WorkingDirectory $workingDirectory -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr

  if ($server.Port) {
    $env:PORT = $previousPort
  }
}

Write-Host "AKI HTTPS servers started. Frontend ports: 5173-5179"
