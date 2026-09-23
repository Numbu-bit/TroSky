# Bring up local dev dependencies for the TroSky backend, then run the API.
#
# Redis lives inside WSL Ubuntu and is managed by systemd. WSL's localhost
# relay only publishes a port to Windows if the port is bound *while a WSL
# session is attached* -- a service started at boot is invisible to Windows.
# So we restart redis-server here, then hold a session open (the distro is
# also torn down once its last session exits, which would kill Redis).
#
# Usage:  .\scripts\dev_up.ps1          # start Redis, then run uvicorn
#         .\scripts\dev_up.ps1 -NoApi   # start Redis only

param([switch]$NoApi)

$ErrorActionPreference = "Stop"
$backend = Split-Path $PSScriptRoot -Parent

Write-Host "==> Starting Redis in WSL and holding the session open..." -ForegroundColor Cyan
Start-Process -WindowStyle Minimized wsl `
    -ArgumentList '-d', 'Ubuntu', '-u', 'root', '-e', 'bash', '-lc',
                  'systemctl restart redis-server; sleep infinity'

# Wait for Windows to actually see the forwarded port.
$ok = $false
foreach ($i in 1..15) {
    Start-Sleep -Seconds 2
    try {
        $c = New-Object Net.Sockets.TcpClient
        $c.Connect("127.0.0.1", 6379)
        $c.Close()
        $ok = $true
        break
    } catch {
        Write-Host "    waiting for Redis ($i/15)..."
    }
}
if (-not $ok) { throw "Redis did not become reachable on 127.0.0.1:6379" }
Write-Host "==> Redis is up on 127.0.0.1:6379" -ForegroundColor Green

if ($NoApi) { return }

Write-Host "==> Starting the API on http://127.0.0.1:8000 (Ctrl+C to stop)" -ForegroundColor Cyan
Set-Location $backend
& "$backend\.venv\Scripts\python.exe" -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
