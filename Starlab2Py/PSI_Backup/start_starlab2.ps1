param(
    [int]$Port = 8000,
    [int]$HealthIntervalSec = 30,
    [int]$HealthFailuresToRestart = 3
)

Add-Type -AssemblyName System.Windows.Forms
function Say($m,$c="Cyan"){ Write-Host $m -ForegroundColor $c }
function Msg($m,$t="Starlab2"){ [System.Windows.Forms.MessageBox]::Show($m, $t) | Out-Null }

$ErrorActionPreference = "SilentlyContinue"

$Proj = Join-Path $env:USERPROFILE "Documents\starlab2"
$Py = Join-Path $Proj ".venv\Scripts\python.exe"
$PidF = Join-Path $Proj "server.pid"
$outLog = Join-Path $Proj "cloudflared.out.log"
$errLog = Join-Path $Proj "cloudflared.err.log"
$UrlFile = Join-Path $Proj "public_url.txt"

# Guardar snapshot inicial
if (-not (Test-Path (Join-Path $Proj "initial_setup.txt"))) {
    $snap = @()
    $snap += "Starlab2: setup inicial - $(Get-Date -Format s)"
    $snap += "Usuario: $env:USERNAME"
    $snap += "Equipo : $env:COMPUTERNAME"
    $snap += "Python : $Py"
    $snap += "Puerto : $Port"
    $snap -join "`r`n" | Set-Content -Path (Join-Path $Proj "initial_setup.txt") -Encoding UTF8
}

# Refrescar PATH
$machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = "$machinePath;$userPath"

function Resolve-Cloudflared {
    $cands = @(
        "cloudflared",
        (Join-Path $env:ProgramFiles "Cloudflare\cloudflared\cloudflared.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\cloudflared\cloudflared.exe"),
        (Join-Path $env:LOCALAPPDATA "Cloudflare\cloudflared\cloudflared.exe")
    )
    foreach ($c in $cands) {
        try {
            if ($c -eq "cloudflared") {
                & $c --version 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) { return $c }
            } elseif (Test-Path $c) { return $c }
        } catch {}
    }
    return $null
}

function Ensure-Cloudflared {
    $cf = Resolve-Cloudflared
    if ($cf) { return $cf }
    Msg "No se encontró cloudflared. Se intentará instalar automáticamente (winget)." "Instalando cloudflared"
    try {
        winget install --id Cloudflare.Cloudflared --source winget --accept-package-agreements --accept-source-agreements | Out-Null
        $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
        $env:Path = "$machinePath;$userPath"
        $cf = Resolve-Cloudflared
        if (-not $cf) { throw "No se pudo instalar cloudflared" }
    } catch {
        Msg "Error al instalar cloudflared: $_" "Error"
        Exit 1
    }
    return $cf
}

function Ensure-Server {
    if (-not (Test-Path $Py)) {
        Msg "No se encontró el Python del entorno (.venv). Revisa la instalación en $Proj" "Error"
        Exit 1
    }
    $needStart = $true
    if (Test-Path $PidF) {
        try {
            $pid = [int](Get-Content $PidF)
            if (Get-Process -Id $pid -ErrorAction SilentlyContinue) { $needStart = $false } else { Remove-Item $PidF -ErrorAction SilentlyContinue }
        } catch {}
    }
    if ($needStart) {
        Say "Iniciando Uvicorn en 127.0.0.1:$Port ..." "Yellow"
        $uvArgs = @('-m','uvicorn','src.web_app:app','--host','127.0.0.1','--port',"$Port",'--reload','--log-level','info')
        $p = Start-Process -FilePath $Py -ArgumentList $uvArgs -WorkingDirectory $Proj -PassThru -NoNewWindow
        $p.Id | Out-File -FilePath $PidF -Encoding UTF8
        Start-Sleep -Seconds 2
    }
    $ok = $false
    for ($i=1; $i -le 12; $i++) {
        Start-Sleep -Milliseconds 900
        try {
            $resp = Invoke-WebRequest "http://127.0.0.1:$Port/health" -UseBasicParsing -TimeoutSec 5
            if ($resp.StatusCode -eq 200) { $ok = $true; break }
        } catch {}
    }
    if (-not $ok) {
        Msg "El servidor local no respondió en /health." "Error"
        Exit 1
    }
    Say "Local /health: 200" "Green"
}

function Start-Tunnel {
    param([string]$CloudflaredExe)
    Remove-Item $outLog, $errLog -Force -ErrorAction SilentlyContinue
    $cfArgs = @('tunnel', '--url', "http://127.0.0.1:$Port", '--no-autoupdate', '--loglevel', 'info')
    $cfProc = Start-Process -FilePath $CloudflaredExe -ArgumentList $cfArgs -WorkingDirectory $Proj -PassThru -NoNewWindow -RedirectStandardOutput $outLog -RedirectStandardError $errLog
    Say "Creando túnel público... (PID $($cfProc.Id))" "Yellow"

    $PublicUrl = $null
    for ($i=0; $i -lt 180 -and -not $PublicUrl; $i++) {
        Start-Sleep -Seconds 1
        if (Test-Path $errLog) {
            $txtErr = Get-Content $errLog -Raw -ErrorAction SilentlyContinue
            if ($txtErr -match 'https://[a-z0-9\-]+\.trycloudflare\.com') {
                $PublicUrl = $Matches[0]
                break
            }
        }
    }
    if (-not $PublicUrl) { return $null }
    $PublicUrl | Set-Content -Path $UrlFile -Encoding UTF8
    return $PublicUrl
}

function Run-Watchdog {
    param([string]$CloudflaredExe)
    $failLocal = 0
    $failPub = 0
    while ($true) {
        Start-Sleep -Seconds $HealthIntervalSec
        $localOk = $false
        try {
            $r = Invoke-WebRequest "http://127.0.0.1:$Port/health" -UseBasicParsing -TimeoutSec 5
            if ($r.StatusCode -eq 200) { $localOk = $true }
        } catch {}
        if ($localOk) { $failLocal = 0 } else { $failLocal++ }

        $PublicUrl = $null
        if (Test-Path $UrlFile) { $PublicUrl = Get-Content $UrlFile -ErrorAction SilentlyContinue }
        if ($PublicUrl) {
            $pubOk = $false
            try {
                $rp = Invoke-WebRequest "$PublicUrl/health" -UseBasicParsing -TimeoutSec 8
                if ($rp.StatusCode -eq 200) { $pubOk = $true }
            } catch {}
            if ($pubOk) { $failPub = 0 } else { $failPub++ }
        } else {
            $failPub++
        }

        if ($failLocal -ge $HealthFailuresToRestart -or $failPub -ge $HealthFailuresToRestart) {
            Say "Watchdog: reiniciando servicios..." "Yellow"
            $failLocal = 0; $failPub = 0
            if (Test-Path $PidF) {
                try { $pid = [int](Get-Content $PidF); Stop-Process -Id $pid -ErrorAction SilentlyContinue } catch {}
                Remove-Item $PidF -ErrorAction SilentlyContinue
            }
            Get-Process | Where-Object { $_.ProcessName -match 'cloudflared' } | ForEach-Object {
                try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } catch {}
            }
            Ensure-Server
            $pub = Start-Tunnel -CloudflaredExe $CloudflaredExe
            if ($pub) {
                Say "Nuevo enlace público: $pub" "Green"
            } else {
                Say "No se pudo recuperar URL pública en la reconexión." "Red"
            }
        }
    }
}

# FLUJO PRINCIPAL
Set-Location $Proj
$CF = Ensure-Cloudflared
Ensure-Server
$PublicUrl = Start-Tunnel -CloudflaredExe $CF
if (-not $PublicUrl) {
    Msg "No se detectó URL pública. Revisa logs en:`n$outLog`n$errLog" "Error"
    Exit 1
}
Msg "URL Pública:`n$PublicUrl`n(copiada al portapapeles)" "Túnel listo"
$PublicUrl | Set-Clipboard
try { Start-Process "$PublicUrl" } catch {}
Run-Watchdog -CloudflaredExe $CF
