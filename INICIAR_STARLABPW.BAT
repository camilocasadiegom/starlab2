# ==============================================================================
# STARLABPW v4.0 - Sistema Robusto, Automático y Ultra-Portable (Un Solo Archivo)
# Objetivo: Iniciar servidor local + túnel público Cloudflare sin interacción.
# ==============================================================================

#region Configuración y Preparación Inicial
$ErrorActionPreference = "Stop" # Detener la ejecución si ocurre un error
Set-StrictMode -Version Latest # Habilitar comprobaciones estrictas
$Script:CurrentDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition # Directorio donde está este script

# Configuración de rutas y puertos
$Script:ProjectRoot = $Script:CurrentDir
$Script:Port = 8000
$Script:DataDir = Join-Path $Script:ProjectRoot "starlabpw_data"
$Script:LogDir = Join-Path $Script:DataDir "logs"
$Script:RegistroHtmlPath = Join-Path $Script:ProjectRoot "registro.html"
$Script:AppPyPath = Join-Path $Script:ProjectRoot "starlab_autoserve.py"
$Script:CloudflaredExePath = Join-Path $Script:ProjectRoot "cloudflared.exe"
$Script:PublicUrlFile = Join-Path $Script:DataDir "public_url.txt"
$Script:VenvPath = Join-Path $Script:ProjectRoot ".venv"

# Crear directorios necesarios
try {
    if (-not (Test-Path $Script:DataDir)) { New-Item -ItemType Directory -Path $Script:DataDir -Force | Out-Null }
    if (-not (Test-Path $Script:LogDir)) { New-Item -ItemType Directory -Path $Script:LogDir -Force | Out-Null }
} catch {
    Write-Host "❌ ERROR: No se pudieron crear los directorios de datos. Asegúrate de tener permisos de escritura en '$Script:ProjectRoot'." -ForegroundColor Red
    Read-Host "Presiona Enter para salir."
    exit 1
}

#endregion

#region Funciones de Logging y Salida
function Write-StarlabLog {
    param(
        [string]$Message,
        [ValidateSet("INFO","SUCCESS","WARNING","ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path (Join-Path $Script:LogDir "starlabpw.log") -Value $logEntry -Encoding UTF8
    
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }
    Write-Host $logEntry -ForegroundColor $color
}

function Write-Step {
    param(
        [int]$StepNum,
        [int]$TotalSteps,
        [string]$Message
    )
    Write-Host "[$StepNum/$TotalSteps] $Message" -ForegroundColor Cyan -NoNewline
}

function Write-StepResult {
    param(
        [bool]$Success
    )
    if ($Success) {
        Write-Host " OK" -ForegroundColor Green
    } else {
        Write-Host " FALLÓ" -ForegroundColor Red
    }
}
#endregion

#region Funciones de Utilidad (Limpieza, Python, Cloudflared)
function Stop-StarlabProcesses {
    Write-StarlabLog "Deteniendo procesos anteriores..." "INFO"
    
    # Detener cloudflared
    Get-Process cloudflared -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Stop-Process -Id $_.Id -Force
            Write-StarlabLog "Cloudflared detenido (PID: $($_.Id))" "SUCCESS"
        } catch {}
    }
    
    # Detener uvicorn en el puerto específico (proceso python)
    (Get-NetTCPConnection -LocalPort $Script:Port -ErrorAction SilentlyContinue).OwningProcess | ForEach-Object {
        try {
            $proc = Get-Process -Id $_ -ErrorAction SilentlyContinue
            if ($proc -and $proc.ProcessName -like "*python*") {
                Stop-Process -Id $_ -Force
                Write-StarlabLog "Uvicorn (python) detenido (PID: $_)" "SUCCESS"
            }
        } catch {}
    }
    Start-Sleep -Seconds 2
}

function Ensure-PythonInstalled {
    try {
        $pythonVersion = (python --version 2>&1).Trim()
        Write-StarlabLog "Python detectado: $pythonVersion" "INFO"
        return $true
    } catch {
        Write-StarlabLog "ERROR: Python no está instalado o no está en el PATH." "ERROR"
        Write-Host "Por favor, instala Python desde https://www.python.org/downloads/ y asegúrate de marcar 'Add Python to PATH' durante la instalación." -ForegroundColor Red
        return $false
    }
}

function Ensure-VenvAndDependencies {
    Write-StarlabLog "Configurando entorno virtual y dependencias..." "INFO"
    
    if (-not (Test-Path $Script:VenvPath)) {
        Write-StarlabLog "Creando entorno virtual en '$Script:VenvPath'..." "INFO"
        python -m venv $Script:VenvPath
    } else {
        Write-StarlabLog "Entorno virtual existente: '$Script:VenvPath'." "INFO"
    }
    
    # Activar venv para la sesión actual de PowerShell
    & (Join-Path $Script:VenvPath "Scripts\Activate.ps1") | Out-Null
    
    Write-StarlabLog "Instalando/actualizando pip, fastapi y uvicorn..." "INFO"
    python -m pip install --upgrade pip --quiet | Out-Null
    pip install fastapi "uvicorn[standard]" --quiet | Out-Null
    return $true
}

function Ensure-CloudflaredExe {
    Write-StarlabLog "Verificando 'cloudflared.exe'..." "INFO"
    if (-not (Test-Path $Script:CloudflaredExePath)) {
        Write-StarlabLog "Descargando 'cloudflared.exe'..." "INFO"
        try {
            $url = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
            Invoke-WebRequest -Uri $url -OutFile $Script:CloudflaredExePath -UseBasicParsing
            return $true
        } catch {
            Write-StarlabLog "ERROR: No se pudo descargar 'cloudflared.exe': $_" "ERROR"
            return $false
        }
    }
    return $true
}
#endregion

#region Generación de Archivos (registro.html y starlab_autoserve.py)
function Generate-StarlabFiles {
    Write-StarlabLog "Generando 'registro.html' y 'starlab_autoserve.py'..." "INFO"

    # Contenido de registro.html
    $registroHtmlContent = @'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Starlab - Registro de Conductores</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 500px;
            width: 100%;
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 { font-size: 28px; margin-bottom: 5px; }
        .header p { opacity: 0.9; font-size: 14px; }
        .content { padding: 40px 30px; }
        .form-group { margin-bottom: 25px; }
        label {
            display: block;
            margin-bottom: 8px;
            font-weight: 600;
            color: #333;
            font-size: 14px;
        }
        input {
            width: 100%;
            padding: 14px;
            border: 2px solid #e0e0e0;
            border-radius: 10px;
            font-size: 15px;
            transition: all 0.3s;
        }
        input:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }
        button {
            width: 100%;
            padding: 16px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 10px;
            font-size: 16px;
            font-weight: 700;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 25px rgba(102, 126, 234, 0.3);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚗 Starlab</h1>
            <p>Sistema de Registro de Conductores</p>
        </div>
        <div class="content">
            <form action="/registrar" method="post">
                <div class="form-group">
                    <label for="nombre">Nombre completo</label>
                    <input type="text" id="nombre" name="nombre" placeholder="Ej: Juan Pérez" required minlength="2" maxlength="100">
                </div>
                <div class="form-group">
                    <label for="licencia">Número de Licencia</label>
                    <input type="text" id="licencia" name="licencia" placeholder="Ej: L12345678" required minlength="5" maxlength="20">
                </div>
                <div class="form-group">
                    <label for="vehiculo">Vehículo</label>
                    <input type="text" id="vehiculo" name="vehiculo" placeholder="Ej: Toyota Corolla 2020" required minlength="2" maxlength="50">
                </div>
                <button type="submit">Registrar Conductor</button>
            </form>
        </div>
    </div>
</body>
</html>
'@

    if (-not (Test-Path $Script:RegistroHtmlPath)) {
        $registroHtmlContent | Set-Content -Path $Script:RegistroHtmlPath -Encoding UTF8
        Write-StarlabLog "'registro.html' generado." "SUCCESS"
    } else {
        Write-StarlabLog "'registro.html' ya existe, no se sobrescribe." "INFO"
    }

    # Contenido de starlab_autoserve.py
    # Usamos Convert-Path para asegurar rutas absolutas en el script Python
    $absoluteRegistroHtmlPath = (Convert-Path $Script:RegistroHtmlPath).Replace('\', '/')
    $absoluteDataDirPath = (Convert-Path (Join-Path $Script:DataDir "data")).Replace('\', '/')

    $starlabAutoserveContent = @"
import os
import json
from datetime import datetime
from pathlib import Path
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware

# Rutas definidas de forma absoluta para máxima robustez
REGISTRO_PATH = Path(r'$absoluteRegistroHtmlPath')
DATA_DIR = Path(r'$absoluteDataDirPath')
DATA_DIR.mkdir(parents=True, exist_ok=True) # Asegura que el directorio de datos existe
REGISTROS_FILE = DATA_DIR / "registros.json"

app = FastAPI(title="Starlab AutoServe", version="4.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

def load_registros():
    if REGISTROS_FILE.exists():
        try:
            with open(REGISTROS_FILE, "r", encoding="utf-8") as f:
                content = f.read()
                if not content: # Manejar archivos JSON vacíos
                    return []
                return json.loads(content)
        except json.JSONDecodeError:
            # Si el archivo está corrupto o mal formado, lo ignoramos y devolvemos vacío
            print(f"WARNING: registros.json está corrupto o mal formado. Se iniciará vacío. Archivo: {REGISTROS_FILE}", flush=True)
            return []
        except Exception as e:
            print(f"ERROR: No se pudo leer registros.json: {e}", flush=True)
            return []
    return []

def save_registro(data):
    registros = load_registros()
    data["timestamp"] = datetime.now().isoformat()
    data["id"] = len(registros) + 1
    registros.append(data)
    with open(REGISTROS_FILE, "w", encoding="utf-8") as f:
        json.dump(registros, f, indent=2, ensure_ascii=False)
    return data

@app.get("/health")
def health():
    return {"status": "ok", "timestamp": datetime.now().isoformat()}

@app.get("/", response_class=HTMLResponse)
def home():
    if not REGISTRO_PATH.is_file():
        raise HTTPException(status_code=404, detail=f"Error: El archivo {REGISTRO_PATH} no fue encontrado.")
    try:
        with open(REGISTRO_PATH, "r", encoding="utf-8") as f:
            return HTMLResponse(f.read())
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error leyendo {REGISTRO_PATH}: {e}")


@app.post("/registrar", response_class=HTMLResponse)
async def registrar(request: Request):
    form = await request.form()
    nombre = (form.get("nombre") or "").strip()
    licencia = (form.get("licencia") or "").strip()
    vehiculo = (form.get("vehiculo") or "").strip()
    
    if not all([nombre, licencia, vehiculo]):
        return HTMLResponse("<h2>Error: Datos incompletos</h2><p>Por favor, completa todos los campos.</p><a href='/'>Volver</a>", status_code=400)
    
    data = {"nombre": nombre, "licencia": licencia, "vehiculo": vehiculo}
    saved = save_registro(data)
    
    html = f"""
    <html>
    <head>
        <meta charset="UTF-8">
        <style>
            body {{
                font-family: Arial, sans-serif;
                background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                color: white;
            }}
            .container {{
                background: rgba(255, 255, 255, 0.1);
                padding: 40px;
                border-radius: 20px;
                text-align: center;
                max-width: 500px;
            }}
            h2 {{ margin-bottom: 20px; }}
            .info {{ background: rgba(0,0,0,0.2); padding: 20px; border-radius: 10px; margin: 20px 0; }}
            .info p {{ margin: 10px 0; }}
            a {{
                display: inline-block;
                margin-top: 20px;
                padding: 12px 30px;
                background: rgba(255, 255, 255, 0.2);
                color: white;
                text-decoration: none;
                border-radius: 25px;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <h2>✅ Registro Exitoso</h2>
            <div class="info">
                <p><strong>Nombre:</strong> {nombre}</p>
                <p><strong>Licencia:</strong> {licencia}</p>
                <p><strong>Vehículo:</strong> {vehiculo}</p>
                <p style="font-size: 12px; margin-top: 10px;">ID: #{saved['id']} | {saved['timestamp'][:19]}</p>
            </div>
            <a href="/">← Registrar otro conductor</a>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(html)

@app.get("/api/registros")
def api_get_registros():
    return JSONResponse({"ok": True, "registros": load_registros()})
"@

    if (-not (Test-Path $Script:AppPyPath)) {
        $starlabAutoserveContent | Set-Content -Path $Script:AppPyPath -Encoding UTF8
        Write-StarlabLog "'starlab_autoserve.py' generado." "SUCCESS"
    } else {
        Write-StarlabLog "'starlab_autoserve.py' ya existe, no se sobrescribe." "INFO"
    }
    return $true
}
#endregion

#region Notificación GUI
function Show-SuccessNotification {
    param(
        [string]$PublicURL,
        [string]$LocalURL,
        [int]$Port
    )
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "✅ STARLABPW - Sistema Listo"
    $form.Size = New-Object System.Drawing.Size(600, 300)
    $form.StartPosition = "CenterScreen"
    $form.TopMost = $true # Siempre en primer plano
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(240, 248, 255)
    
    # Icono y Título
    $lblIcon = New-Object System.Windows.Forms.Label
    $lblIcon.Text = "✅"
    $lblIcon.Font = New-Object System.Drawing.Font("Segoe UI", 48)
    $lblIcon.AutoSize = $true
    $lblIcon.Location = New-Object System.Drawing.Point(250, 10)
    $form.Controls.Add($lblIcon)
    
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Sistema STARLABPW Activo"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(102, 126, 234)
    $lblTitle.AutoSize = $true
    $lblTitle.Location = New-Object System.Drawing.Point(150, 80)
    $form.Controls.Add($lblTitle)
    
    # URL Pública
    $lblURL = New-Object System.Windows.Forms.Label
    $lblURL.Text = "🌐 URL PÚBLICA:"
    $lblURL.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lblURL.AutoSize = $true
    $lblURL.Location = New-Object System.Drawing.Point(20, 130)
    $form.Controls.Add($lblURL)
    
    $txtURL = New-Object System.Windows.Forms.TextBox
    $txtURL.Text = $PublicURL
    $txtURL.Size = New-Object System.Drawing.Size(560, 30)
    $txtURL.Location = New-Object System.Drawing.Point(20, 160)
    $txtURL.ReadOnly = $true
    $txtURL.Font = New-Object System.Drawing.Font("Consolas", 10)
    $form.Controls.Add($txtURL)
    
    # Botón Copiar URL
    $btnCopy = New-Object System.Windows.Forms.Button
    $btnCopy.Text = "📋 Copiar URL"
    $btnCopy.Size = New-Object System.Drawing.Size(120, 35)
    $btnCopy.Location = New-Object System.Drawing.Point(20, 200)
    $btnCopy.BackColor = [System.Drawing.Color]::FromArgb(102, 126, 234)
    $btnCopy.ForeColor = [System.Drawing.Color]::White
    $btnCopy.FlatStyle = "Flat"
    $btnCopy.Add_Click({
        [System.Windows.Forms.Clipboard]::SetText($PublicURL)
        [System.Windows.Forms.MessageBox]::Show("✅ URL copiada al portapapeles", "Copiado", "OK", "Information")
    })
    $form.Controls.Add($btnCopy)
    
    # Información adicional
    $lblInfo = New-Object System.Windows.Forms.Label
    $lblInfo.Text = "ℹ️  El sistema está activo en segundo plano.`nℹ️  La URL es temporal (válida mientras este PC esté encendido).`nℹ️  Puedes compartir esta URL con cualquier persona."
    $lblInfo.Size = New-Object System.Drawing.Size(560, 60)
    $lblInfo.Location = New-Object System.Drawing.Point(20, 240)
    $lblInfo.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $form.Controls.Add($lblInfo)
    
    # Botón Cerrar
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "Entendido ✓"
    $btnClose.Size = New-Object System.Drawing.Size(100, 35)
    $btnClose.Location = New-Object System.Drawing.Point(480, 240)
    $btnClose.BackColor = [System.Drawing.Color]::FromArgb(76, 175, 80)
    $btnClose.ForeColor = [System.Drawing.Color]::White
    $btnClose.FlatStyle = "Flat"
    $btnClose.Add_Click({$form.Close()})
    $form.Controls.Add($btnClose)
    
    # Abrir URL en navegador automáticamente
    Start-Process $PublicURL
    
    $form.ShowDialog() | Out-Null
}
#endregion

#region Ejecución Principal
Write-Host "`n"
Write-Host "╔═════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║            🚀 STARLABPW v4.0 - Iniciando Sistema Robusto          ║" -ForegroundColor Green
Write-Host "╚═════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host "`n"

$TotalSteps = 8
$CurrentStep = 1

# Paso 1: Verificar Python
Write-Step $CurrentStep $TotalSteps "Verificando instalación de Python..."
if (-not (Ensure-PythonInstalled)) { Write-StepResult $false; Read-Host "Presiona Enter para salir."; exit 1 }
Write-StepResult $true; $CurrentStep++
Start-Sleep -Milliseconds 500

# Paso 2: Limpiar procesos anteriores
Write-Step $CurrentStep $TotalSteps "Deteniendo procesos anteriores (Uvicorn, Cloudflared)..."
Stop-StarlabProcesses
Write-StepResult $true; $CurrentStep++
Start-Sleep -Milliseconds 500

# Paso 3: Configurar entorno virtual e instalar dependencias
Write-Step $CurrentStep $TotalSteps "Configurando entorno virtual Python y dependencias (FastAPI, Uvicorn)..."
if (-not (Ensure-VenvAndDependencies)) { Write-StepResult $false; Read-Host "Presiona Enter para salir."; exit 1 }
Write-StepResult $true; $CurrentStep++
Start-Sleep -Milliseconds 500

# Paso 4: Generar archivos esenciales (registro.html, starlab_autoserve.py)
Write-Step $CurrentStep $TotalSteps "Generando 'registro.html' y 'starlab_autoserve.py'..."
if (-not (Generate-StarlabFiles)) { Write-StepResult $false; Read-Host "Presiona Enter para salir."; exit 1 }
Write-StepResult $true; $CurrentStep++
Start-Sleep -Milliseconds 500

# Paso 5: Iniciar servidor Uvicorn (FastAPI)
Write-Step $CurrentStep $TotalSteps "Iniciando servidor web local en http://localhost:$Script:Port..."
$UvicornLogFile = Join-Path $Script:LogDir "uvicorn_out.log"
try {
    Start-Process -FilePath (Join-Path $Script:VenvPath "Scripts\python.exe") `
        -ArgumentList "-m","uvicorn","starlab_autoserve:app","--host","0.0.0.0","--port","$Script:Port" `
        -NoNewWindow -RedirectStandardOutput $UvicornLogFile -RedirectStandardError $UvicornLogFile -PassThru | Out-Null
    
    Start-Sleep -Seconds 5 # Dar tiempo al servidor para iniciar
    
    # Verificar salud del servidor
    $healthCheckAttempts = 0
    $isUvicornRunning = $false
    while ($healthCheckAttempts -lt 10 -and -not $isUvicornRunning) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$Script:Port/health" -UseBasicParsing -TimeoutSec 3
            if ($response.StatusCode -eq 200) { $isUvicornRunning = $true }
        } catch {}
        Start-Sleep -Seconds 1
        $healthCheckAttempts++
    }
    
    if (-not $isUvicornRunning) { throw "El servidor Uvicorn no respondió después de varios intentos." }
    Write-StepResult $true; $CurrentStep++
} catch {
    Write-StepResult $false
    Write-Host "❌ ERROR: No se pudo iniciar el servidor web Uvicorn o no respondió." -ForegroundColor Red
    Write-Host "Revisa el archivo de log: '$UvicornLogFile' para más detalles." -ForegroundColor Yellow
    Read-Host "Presiona Enter para salir."
    exit 1
}
Start-Sleep -Milliseconds 500

# Paso 6: Descargar Cloudflared si es necesario
Write-Step $CurrentStep $TotalSteps "Verificando y descargando 'cloudflared.exe'..."
if (-not (Ensure-CloudflaredExe)) { Write-StepResult $false; Read-Host "Presiona Enter para salir."; exit 1 }
Write-StepResult $true; $CurrentStep++
Start-Sleep -Milliseconds 500

# Paso 7: Iniciar túnel Cloudflare y obtener URL pública
Write-Step $CurrentStep $TotalSteps "Iniciando túnel público Cloudflare..."
$CloudflaredLogFile = Join-Path $Script:LogDir "cloudflared_out.log"
$PublicURL = $null

try {
    Start-Process -FilePath $Script:CloudflaredExePath -ArgumentList "tunnel","--url","http://localhost:$Script:Port" `
        -NoNewWindow -RedirectStandardOutput $CloudflaredLogFile -RedirectStandardError $CloudflaredLogFile -PassThru | Out-Null
    
    Start-Sleep -Seconds 5 # Dar tiempo a Cloudflared para iniciar el túnel
    
    # Intentar obtener la URL pública del log
    $urlDetectionAttempts = 0
    while ($urlDetectionAttempts -lt 15 -and -not $PublicURL) { # 15 segundos
        if (Test-Path $CloudflaredLogFile) {
            $logContent = Get-Content $CloudflaredLogFile -Raw
            if ($logContent -match 'https://[a-z0-9-]+\.trycloudflare\.com') {
                $PublicURL = $Matches[0]
            }
        }
        if (-not $PublicURL) { Start-Sleep -Seconds 1 }
        $urlDetectionAttempts++
    }
    
    if (-not $PublicURL) { throw "No se pudo obtener la URL pública de Cloudflare en el tiempo esperado." }
    
    $PublicURL | Set-Content -Path $Script:PublicUrlFile -Encoding UTF8
    Write-StepResult $true; $CurrentStep++
} catch {
    Write-StepResult $false
    Write-Host "❌ ERROR: Fallo al iniciar el túnel de Cloudflare o al obtener la URL pública." -ForegroundColor Red
    Write-Host "El servidor LOCAL sigue funcionando en: http://localhost:$Script:Port" -ForegroundColor Yellow
    Write-Host "Revisa el archivo de log: '$CloudflaredLogFile' para más detalles." -ForegroundColor Yellow
    Read-Host "Presiona Enter para continuar."
    # Si Cloudflare falla, el script aún continúa para mostrar el local URL.
    $PublicURL = "http://localhost:$Script:Port (SOLO LOCAL)" # Fallback para la notificación
}
Start-Sleep -Milliseconds 500

# Paso 8: Mostrar resultados finales y notificación GUI
Write-Step $CurrentStep $TotalSteps "Sistema iniciado. Mostrando URL pública y notificación."
if ($PublicURL -and $PublicURL -notlike "*SOLO LOCAL*") {
    Write-StarlabLog "Sistema iniciado correctamente. URL pública: $PublicURL" "SUCCESS"
    Show-SuccessNotification -PublicURL $PublicURL -LocalURL "http://localhost:$Script:Port" -Port $Script:Port
} else {
    Write-StarlabLog "Sistema iniciado. Sólo URL local: http://localhost:$Script:Port" "WARNING"
    Write-Host "`n"
    Write-Host "╔═════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║             ⚠️  ADVERTENCIA: URL PÚBLICA NO DISPONIBLE            ║" -ForegroundColor Yellow
    Write-Host "║             El servidor local está activo, pero Cloudflare falló. ║" -ForegroundColor Yellow
    Write-Host "╚═════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host "`n"
    Write-Host "💻 URL LOCAL: http://localhost:$Script:Port" -ForegroundColor Yellow
    Write-Host "`nPor favor, revisa los logs en '$CloudflaredLogFile' si necesitas depurar." -ForegroundColor Yellow
    Start-Process "http://localhost:$Script:Port" # Abre el local URL en el navegador
    Read-Host "`nPresiona Enter para cerrar esta ventana."
}
Write-StepResult $true; $CurrentStep++

Write-Host "`n╔═════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║       ✅ STARLABPW está corriendo en segundo plano.            ║" -ForegroundColor Green
Write-Host "║       Puedes minimizar esta ventana.                           ║" -ForegroundColor Green
Write-Host "╚═════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host "`n"
# Mantiene la ventana de PowerShell abierta para ver los logs, pero los procesos corren en segundo plano.
# Si quieres que se cierre automáticamente, elimina el Read-Host.
Read-Host "Presiona Enter para cerrar esta ventana."

#endregion