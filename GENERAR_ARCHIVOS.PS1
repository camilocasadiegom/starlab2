# Script PowerShell para generar archivos esenciales (registro.html y starlab_autoserve.py)
# Se invoca desde INICIAR_STARLABPW.bat para mayor robustez en la creación de archivos.

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot # Asegura que el script trabaja en la misma carpeta donde está

# ==================== CONTENIDO DE REGISTRO.HTML ====================
$htmlContentRegistro = @'
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

if (-not (Test-Path "registro.html")) {
    $htmlContentRegistro | Set-Content -Path "registro.html" -Encoding UTF8
}

# ==================== CONTENIDO DE STARLAB_AUTOSERVE.PY ====================
$pyContentAutoserve = @"
import os
import json
from datetime import datetime
from pathlib import Path
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware

# Rutas relativas al script de Python para mayor portabilidad
SCRIPT_DIR = Path(__file__).parent
REGISTRO_PATH = SCRIPT_DIR / "registro.html"
DATA_DIR = SCRIPT_DIR / "starlabpw_data" / "data" # Persistente en la raíz del proyecto
DATA_DIR.mkdir(parents=True, exist_ok=True)
REGISTROS_FILE = DATA_DIR / "registros.json"

app = FastAPI(title="Starlab AutoServe", version="3.1")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

def load_registros():
    if REGISTROS_FILE.exists():
        try:
            with open(REGISTROS_FILE, "r", encoding="utf-8") as f:
                # Si el archivo está vacío, devuelve una lista vacía para evitar JSONDecodeError
                content = f.read()
                if not content:
                    return []
                return json.loads(content)
        except json.JSONDecodeError:
            # Archivo existe pero está mal formado (no es JSON válido)
            return []
        except Exception as e:
            # Otros errores al leer el archivo
            print(f"Error loading registros.json: {e}", flush=True) # flush=True para que se vea en logs
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
        return HTMLResponse("<h1>Error: registro.html no encontrado</h1>", status_code=404)
    try:
        with open(REGISTRO_PATH, "r", encoding="utf-8") as f:
            return HTMLResponse(f.read())
    except Exception as e:
        return HTMLResponse(f"<h1>Error leyendo registro.html</h1><p>{e}</p>", status_code=500)


@app.post("/registrar", response_class=HTMLResponse)
async def registrar(request: Request):
    form = await request.form()
    nombre = (form.get("nombre") or "").strip()
    licencia = (form.get("licencia") or "").strip()
    vehiculo = (form.get("vehiculo") or "").strip()
    
    if not all([nombre, licencia, vehiculo]):
        return HTMLResponse("<h2>Error: Datos incompletos</h2><a href='/'>Volver</a>", status_code=400)
    
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

if (-not (Test-Path "starlab_autoserve.py")) {
    $pyContentAutoserve | Set-Content -Path "starlab_autoserve.py" -Encoding UTF8
}

exit 0