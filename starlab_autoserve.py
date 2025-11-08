import os
import json
from datetime import datetime
from pathlib import Path
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware

REGISTRO_PATH = r"""C:\\Users\\Camilo C\\Documents\\starlab2\\Starlab2Py\\PSI_Backup\\src\\templates\\registro.html"""
DATA_DIR = Path.home() / ".starlabpw" / "data"
DATA_DIR.mkdir(parents=True, exist_ok=True)
REGISTROS_FILE = DATA_DIR / "registros.json"

app = FastAPI(
    title="Starlab AutoServe",
    description="Sistema de gestión de conductores",
    version="2.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def load_registros():
    if REGISTROS_FILE.exists():
        try:
            with open(REGISTROS_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except:
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
    return {
        "status": "ok",
        "timestamp": datetime.now().isoformat(),
        "service": "Starlab AutoServe v2.0"
    }

@app.get("/", response_class=HTMLResponse)
def home():
    if not os.path.isfile(REGISTRO_PATH):
        return HTMLResponse(
            "<h1>❌ Error</h1><p>No se encontró registro.html</p>",
            status_code=404
        )
    
    try:
        with open(REGISTRO_PATH, "r", encoding="utf-8") as f:
            return HTMLResponse(f.read())
    except Exception as e:
        return HTMLResponse(
            f"<h1>❌ Error</h1><p>Error leyendo registro.html: {str(e)}</p>",
            status_code=500
        )

@app.post("/registrar", response_class=HTMLResponse)
async def registrar(request: Request):
    try:
        form = await request.form()
        nombre = (form.get("nombre") or "").strip()
        licencia = (form.get("licencia") or "").strip()
        vehiculo = (form.get("vehiculo") or "").strip()
        
        if not all([nombre, licencia, vehiculo]):
            return HTMLResponse(
                """
                <html>
                <head>
                    <meta charset="UTF-8">
                    <style>
                        body {font-family:Arial;padding:40px;background:#f44336;color:white;text-align:center;}
                        .box {background:rgba(0,0,0,0.2);padding:30px;border-radius:10px;display:inline-block;}
                        a {color:white;text-decoration:underline;}
                    </style>
                </head>
                <body>
                    <div class="box">
                        <h2>❌ Datos Incompletos</h2>
                        <p>Por favor completa todos los campos</p>
                        <a href="/">← Volver al formulario</a>
                    </div>
                </body>
                </html>
                """,
                status_code=400
            )
        
        # Guardar registro
        data = {
            "nombre": nombre,
            "licencia": licencia,
            "vehiculo": vehiculo
        }
        saved = save_registro(data)
        
        return HTMLResponse(f"""
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * {{box-sizing:border-box;margin:0;padding:0;}}
                body {{
                    font-family:'Segoe UI',Arial,sans-serif;
                    background:linear-gradient(135deg,#11998e 0%,#38ef7d 100%);
                    min-height:100vh;
                    display:flex;
                    align-items:center;
                    justify-content:center;
                    padding:20px;
                }}
                .container {{
                    background:white;
                    border-radius:20px;
                    box-shadow:0 20px 60px rgba(0,0,0,0.3);
                    max-width:500px;
                    padding:40px;
                    text-align:center;
                }}
                h2 {{color:#11998e;margin-bottom:20px;}}
                .success-icon {{font-size:64px;margin-bottom:20px;}}
                .info {{background:#f0f0f0;padding:20px;border-radius:10px;margin:20px 0;text-align:left;}}
                .info p {{margin:10px 0;}}
                .info strong {{color:#11998e;}}
                .btn {{
                    display:inline-block;
                    padding:12px 30px;
                    background:linear-gradient(135deg,#11998e 0%,#38ef7d 100%);
                    color:white;
                    text-decoration:none;
                    border-radius:25px;
                    margin-top:20px;
                    transition:transform 0.2s;
                }}
                .btn:hover {{transform:translateY(-2px);}}
                .id {{color:#666;font-size:12px;margin-top:10px;}}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="success-icon">✅</div>
                <h2>Registro Exitoso</h2>
                <div class="info">
                    <p><strong>Nombre:</strong> {nombre}</p>
                    <p><strong>Licencia:</strong> {licencia}</p>
                    <p><strong>Vehículo:</strong> {vehiculo}</p>
                    <p class="id">ID: #{saved['id']} | {saved['timestamp'][:19]}</p>
                </div>
                <a href="/" class="btn">← Registrar otro conductor</a>
            </div>
        </body>
        </html>
        """)
        
    except Exception as e:
        return HTMLResponse(
            f"<h1>Error</h1><p>{str(e)}</p><a href='/'>Volver</a>",
            status_code=500
        )

@app.post("/api/registrar")
async def api_registrar(request: Request):
    try:
        data = await request.json()
        if not all(k in data for k in ["nombre","licencia","vehiculo"]):
            raise HTTPException(status_code=400, detail="Faltan campos requeridos")
        
        saved = save_registro(data)
        return JSONResponse({"ok": True, "data": saved})
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/registros")
def api_get_registros():
    return JSONResponse({"ok": True, "registros": load_registros()})
