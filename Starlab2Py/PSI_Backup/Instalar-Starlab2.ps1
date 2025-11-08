# Script de Instalación Automática de Starlab2 - Versión 1.0
# Ejecuta con: .\Instalar-Starlab2.ps1

param(
    [string]$Destination = "$env:USERPROFILE\Documents\starlab2"
)

Clear-Host
Write-Host "=== Instalando Starlab2 ===" -ForegroundColor Cyan
Write-Host "Destino: $Destination" -ForegroundColor Yellow

function Write-FileContent {
    param([string]$Path, [string]$Content, [string]$Encoding = "UTF8")
    try {
        $Content | Out-File -FilePath $Path -Encoding $Encoding -Force
        Write-Host "Archivo creado: $Path" -ForegroundColor Green
    } catch {
        Write-Host "Error creando $Path : $_" -ForegroundColor Red
        Exit 1
    }
}

# Crear estructura
if (-not (Test-Path $Destination)) { New-Item -Path $Destination -ItemType Directory -Force | Out-Null }
$Proj = $Destination
$ProjSrc = Join-Path $Proj "src"
New-Item -Path $ProjSrc -ItemType Directory -Force | Out-Null

# Crear web_app.py
$webAppContent = @"
from fastapi import FastAPI, HTMLResponse, Request
app = FastAPI(title="Starlab2 - Formulario en Línea")

@app.get("/health")
def health_check():
    return {"status": "healthy"}

@app.get("/", response_class=HTMLResponse)
async def home():
    return """
    <html><body>
    <h1>🌟 Starlab2</h1>
    <form action='/submit' method='post'>
      <input name='nombre' placeholder='Tu nombre'><br>
      <textarea name='mensaje' rows='5' placeholder='Tu mensaje'></textarea><br>
      <button>Enviar</button>
    </form></body></html>
    """

@app.post("/submit", response_class=HTMLResponse)
async def submit(request: Request):
    f = await request.form()
    return f"<html><body><h1>Gracias, {f.get('nombre')}</h1><p>{f.get('mensaje')}</p><a href='/'>Volver</a></body></html>"
"@
Write-FileContent -Path (Join-Path $ProjSrc "web_app.py") -Content $webAppContent

# requirements.txt
$req = @"
fastapi
uvicorn[standard]
requests
psutil
pyperclip
"@
Write-FileContent -Path (Join-Path $Proj "requirements.txt") -Content $req

# Script principal de arranque PowerShell
$ps = @'
param([int]$Port=8000)
Add-Type -AssemblyName System.Windows.Forms
$Proj = Join-Path $env:USERPROFILE "Documents\starlab2"
$Py = Join-Path $Proj ".venv\Scripts\python.exe"
Set-Location $Proj
if (-not (Test-Path $Py)) {
    Write-Host "Creando entorno virtual..."
    python -m venv .venv
    & $Py -m pip install --upgrade pip
    & $Py -m pip install -r requirements.txt
}
$pidfile = Join-Path $Proj "server.pid"
if (Test-Path $pidfile) {
    $pid = Get-Content $pidfile
    if (Get-Process -Id $pid -ErrorAction SilentlyContinue) { Stop-Process -Id $pid -Force }
}
Write-Host "Iniciando servidor..." -ForegroundColor Yellow
$p = Start-Process -FilePath $Py -ArgumentList "-m","uvicorn","src.web_app:app","--host","127.0.0.1","--port",$Port,"--reload" -PassThru -NoNewWindow
$p.Id | Out-File $pidfile
Write-Host "Servidor iniciado en http://127.0.0.1:$Port" -ForegroundColor Green
MsgBox = [System.Windows.Forms.MessageBox]::Show("Servidor iniciado en http://127.0.0.1:$Port`nPresiona Aceptar para crear túnel público.","Starlab2")
$CF = "cloudflared"
try { & $CF --version | Out-Null } catch {
    Write-Host "Instalando Cloudflared..." -ForegroundColor Yellow
    winget install --id Cloudflare.Cloudflared --source winget --accept-package-agreements --accept-source-agreements | Out-Null
}
Write-Host "Creando túnel Cloudflare..." -ForegroundColor Cyan
Start-Process -FilePath $CF -ArgumentList "tunnel","--url","http://127.0.0.1:$Port" -NoNewWindow
'@
Write-FileContent -Path (Join-Path $Proj "start_starlab2.ps1") -Content $ps

Write-Host "✅ Instalación completada. Ejecuta con: .\start_starlab2.ps1" -ForegroundColor Green
