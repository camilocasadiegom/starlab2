#!/usr/bin/env python3
# ===================== STARLAB3 - SETUP + LAUNCH (Python) =====================
import os, sys, subprocess, platform, shutil, time, urllib.request, socket
from pathlib import Path
from datetime import datetime

class C:
    CYAN='\033[96m'; GREEN='\033[92m'; YELLOW='\033[93m'; RED='\033[91m'; RESET='\033[0m'; BOLD='\033[1m'
def step(m): print(f"\n{C.CYAN}==> {m}{C.RESET}")
def ok(m): print(f"{C.GREEN}✅ {m}{C.RESET}")
def err(m): print(f"{C.RED}❌ {m}{C.RESET}")
def warn(m): print(f"{C.YELLOW}⚠️  {m}{C.RESET}")

def check_python():
    if sys.version_info < (3,8):
        err(f"Python 3.8+ requerido. Actual: {sys.version}")
        sys.exit(1)
    ok(f"Python {sys.version.split()[0]} detectado")

def port_free(port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('127.0.0.1', port)) != 0

def backup(project):
    if not project.exists(): return
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    dst = project.parent / f"starlab3_backup_{ts}"
    step("Creando backup...")
    try:
        shutil.copytree(project, dst)
        shutil.make_archive(str(dst), 'zip', dst)
        shutil.rmtree(dst)
        ok(f"Backup: {dst}.zip")
    except Exception as e:
        warn(f"No se pudo crear backup: {e}")

def write(path:Path, content:str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")

WEB_APP = """from fastapi import FastAPI, Request, Form, HTTPException
from fastapi.responses import HTMLResponse, FileResponse
from fastapi.templating import Jinja2Templates
from pathlib import Path
import pandas as pd
from datetime import datetime
import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger("starlab3")

app = FastAPI(title="Starlab3", description="Sistema de Registro de Conductores", version="3.0.0")

BASE_DIR = Path(__file__).resolve().parent
TEMPLATES_DIR = BASE_DIR / "templates"
DATA_DIR = BASE_DIR.parent / "data"
CSV_PATH = DATA_DIR / "registro.csv"
templates = Jinja2Templates(directory=str(TEMPLATES_DIR))

def ensure_csv():
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if not CSV_PATH.exists():
        pd.DataFrame(columns=["Nombre","Licencia","Vehiculo","FechaRegistro"]).to_csv(CSV_PATH,index=False,encoding="utf-8")
        logger.info(f"CSV creado: {CSV_PATH}")

@app.on_event("startup")
async def startup_event():
    ensure_csv(); logger.info("Aplicación iniciada")

@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    try:
        ensure_csv()
        df = pd.read_csv(CSV_PATH, encoding="utf-8")
        return templates.TemplateResponse("registro.html", {"request": request, "conductores": df.to_dict("records"), "mensaje": None, "total": len(df)})
    except Exception as e:
        logger.error(f"Error en home: {e}"); raise HTTPException(status_code=500, detail=str(e))

@app.post("/registrar", response_class=HTMLResponse)
async def registrar(request: Request, nombre: str = Form(..., min_length=2, max_length=100), licencia: str = Form(..., min_length=5, max_length=20), vehiculo: str = Form(..., min_length=2, max_length=50)):
    try:
        ensure_csv()
        df = pd.read_csv(CSV_PATH, encoding="utf-8")
        if licencia in df["Licencia"].values:
            return templates.TemplateResponse("registro.html", {"request": request, "conductores": df.to_dict("records"), "mensaje": f"⚠️ La licencia {licencia} ya está registrada", "mensaje_tipo": "warning", "total": len(df)})
        nuevo = {"Nombre": nombre.strip().title(), "Licencia": licencia.strip().upper(), "Vehiculo": vehiculo.strip().title(), "FechaRegistro": datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
        df = pd.concat([df, pd.DataFrame([nuevo])], ignore_index=True)
        df.to_csv(CSV_PATH, index=False, encoding="utf-8")
        logger.info(f"Conductor registrado: {nombre} - {licencia}")
        return templates.TemplateResponse("registro.html", {"request": request, "conductores": df.to_dict("records"), "mensaje": f"✅ Conductor {nombre} registrado correctamente", "mensaje_tipo": "success", "total": len(df)})
    except Exception as e:
        logger.error(f"Error al registrar: {e}"); raise HTTPException(status_code=500, detail=str(e))

@app.get("/exportar")
async def exportar():
    try:
        ensure_csv()
        if not CSV_PATH.exists(): raise HTTPException(status_code=404, detail="No hay datos para exportar")
        return FileResponse(path=CSV_PATH, media_type="text/csv", filename=f"conductores_{datetime.now().strftime('%Y%m%d')}.csv")
    except Exception as e:
        logger.error(f"Error al exportar: {e}"); raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health():
    return {"status":"healthy","timestamp":datetime.now().isoformat(),"registros":len(pd.read_csv(CSV_PATH,encoding="utf-8"))}
"""

HTML = """<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Starlab3 - Registro de Conductores</title>
<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);min-height:100vh;padding:20px}.container{max-width:1200px;margin:0 auto;background:#fff;border-radius:20px;box-shadow:0 20px 60px rgba(0,0,0,.3);overflow:hidden}header{background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:#fff;padding:30px;text-align:center}header h1{font-size:2.2em;margin-bottom:10px}header p{opacity:.9;font-size:1.1em}.stats{display:flex;justify-content:center;gap:20px;margin-top:20px}.stat-box{background:rgba(255,255,255,.2);padding:12px 24px;border-radius:10px;backdrop-filter:blur(10px)}.stat-box strong{display:block;font-size:1.6em}.content{padding:34px}.form-section{background:#f8f9fa;padding:24px;border-radius:15px;margin-bottom:30px}.form-section h2{color:#667eea;margin-bottom:14px}form{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:12px}input{padding:12px 14px;border:2px solid #e1e8ed;border-radius:10px;font-size:1em;transition:all .3s}input:focus{outline:none;border-color:#667eea;box-shadow:0 0 0 3px rgba(102,126,234,.1)}button{padding:12px 30px;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:#fff;border:none;border-radius:10px;font-size:1em;font-weight:600;cursor:pointer;transition:transform .2s,box-shadow .2s}button:hover{transform:translateY(-2px);box-shadow:0 5px 15px rgba(102,126,234,.4)}.mensaje{padding:15px 20px;border-radius:10px;margin-bottom:20px;font-weight:500}.mensaje.success{background:#d4edda;color:#155724;border-left:4px solid #28a745}.mensaje.warning{background:#fff3cd;color:#856404;border-left:4px solid #ffc107}.table-section h2{color:#667eea;margin-bottom:16px;display:flex;justify-content:space-between;align-items:center}.export-btn{padding:10px 20px;background:#28a745;color:#fff;text-decoration:none;border-radius:8px;font-size:.9em;transition:all .3s}.export-btn:hover{background:#218838;transform:translateY(-2px)}table{width:100%;border-collapse:collapse;background:#fff;border-radius:10px;overflow:hidden;box-shadow:0 0 20px rgba(0,0,0,.05)}thead{background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:#fff}th,td{padding:12px;text-align:left}tbody tr{border-bottom:1px solid #f0f0f0;transition:background .2s}tbody tr:hover{background:#f8f9fa}tbody tr:last-child{border-bottom:none}.empty-state{text-align:center;padding:50px 20px;color:#6c757d}.empty-state svg{width:120px;height:120px;margin-bottom:16px;opacity:.3}@media (max-width:768px){header h1{font-size:1.6em}.content{padding:18px}form{grid-template-columns:1fr}table{font-size:.9em}th,td{padding:10px}}</style></head><body><div class='container'><header><h1>🚗 Starlab3</h1><p>Sistema de Registro de Conductores</p><div class='stats'><div class='stat-box'><strong>{{ total }}</strong><span>Conductores</span></div></div></header><div class='content'><div class='form-section'><h2>➕ Nuevo Registro</h2><form action='/registrar' method='post'><input type='text' name='nombre' placeholder='Nombre completo' required minlength='2' maxlength='100'><input type='text' name='licencia' placeholder='N° Licencia' required minlength='5' maxlength='20'><input type='text' name='vehiculo' placeholder='Vehículo' required minlength='2' maxlength='50'><button type='submit'>Registrar</button></form></div>{% if mensaje %}<div class='mensaje {{ mensaje_tipo or 'success' }}'>{{ mensaje }}</div>{% endif %}<div class='table-section'><h2>📋 Conductores Registrados <a href='/exportar' class='export-btn'>📥 Exportar CSV</a></h2>{% if conductores %}<table><thead><tr><th>Nombre</th><th>Licencia</th><th>Vehículo</th><th>Fecha de Registro</th></tr></thead><tbody>{% for c in conductores %}<tr><td>{{ c.Nombre }}</td><td>{{ c.Licencia }}</td><td>{{ c.Vehiculo }}</td><td>{{ c.FechaRegistro }}</td></tr>{% endfor %}</tbody></table>{% else %}<div class='empty-state'><svg fill='currentColor' viewBox='0 0 20 20'><path d='M9 2a1 1 0 000 2h2a1 1 0 100-2H9z'/><path fill-rule='evenodd' d='M4 5a2 2 0 012-2 3 3 0 003 3h2a3 3 0 003-3 2 2 0 012 2v11a2 2 0 01-2 2H6a2 2 0 01-2-2V5zm3 4a1 1 0 000 2h.01a1 1 0 100-2H7zm3 0a1 1 0 000 2h3a1 1 0 100-2h-3zm-3 4a1 1 0 100 2h.01a1 1 0 100-2H7zm3 0a1 1 0 100 2h3a1 1 0 100-2h-3z' clip-rule='evenodd'/></svg><h3>No hay conductores registrados</h3><p>Comienza registrando el primer conductor usando el formulario arriba</p></div>{% endif %}</div></div></div></body></html>"""

REQ = "fastapi>=0.100.0\nuvicorn[standard]>=0.23.0\njinja2>=3.1.2\npandas>=2.0.0\npython-multipart>=0.0.6\n"

def main():
    print(f"""\n{C.CYAN}╔═══════════════════════════════════════╗
║     STARLAB3 - Setup & Launch         ║
║     Registro de Conductores           ║
╚═══════════════════════════════════════╝{C.RESET}\n""")
    check_python()
    port = 8000
    if not port_free(port):
        err(f"Puerto {port} no disponible"); sys.exit(1)

    # Directorio base: Documents en Windows, HOME en Linux/macOS
    base = Path.home() / ("Documents" if platform.system()=="Windows" else "")
    project = base / "starlab3"
    src = project/"src"; tpl = src/"templates"; data = project/"data"; logs = project/"logs"; venv = project/".venv"

    # Backup + limpieza si ya existe
    if project.exists():
        backup(project)
        shutil.rmtree(project, ignore_errors=True)

    # Estructura y archivos
    step("Creando estructura...")
    for d in (src, tpl, data, logs): d.mkdir(parents=True, exist_ok=True)
    (src/"__init__.py").write_text("", encoding="utf-8")
    write(src/"web_app.py", WEB_APP)
    write(tpl/"registro.html", HTML)
    write(project/"requirements.txt", REQ)
    ok("Estructura creada")

    # Entorno virtual
    step("Creando entorno virtual...")
    subprocess.run([sys.executable, "-m", "venv", str(venv)], check=True)
    if platform.system()=="Windows":
        pyv = venv/"Scripts"/"python.exe"; pipv = venv/"Scripts"/"pip.exe"
    else:
        pyv = venv/"bin"/"python"; pipv = venv/"bin"/"pip"
    ok(".venv creado")

    # Dependencias
    step("Instalando dependencias...")
    subprocess.run([str(pipv), "install", "--upgrade", "pip"], check=True)
    subprocess.run([str(pipv), "install", "-r", str(project/"requirements.txt")], check=True)
    ok("Dependencias instaladas")

    # Arranque
    step(f"Iniciando servidor en puerto {port}...")
    env=os.environ.copy(); env["PYTHONIOENCODING"]="utf-8"; env["PYTHONUNBUFFERED"]="1"
    proc=subprocess.Popen([str(pyv), "-m", "uvicorn","src.web_app:app","--host","127.0.0.1","--port",str(port),"--reload"], cwd=str(project), env=env)
    (project/"server.pid").write_text(str(proc.pid), encoding="utf-8")

    # Healthcheck
    step("Verificando /health ...")
    url=f"http://127.0.0.1:{port}/health"
    for _ in range(30):
        time.sleep(1)
        try:
            with urllib.request.urlopen(url, timeout=2) as r:
                if r.status==200: ok("Servidor OK"); break
        except Exception:
            print(".", end="", flush=True)
    else:
        err("El servidor no respondió"); proc.kill(); sys.exit(1)

    print(f"\n{C.GREEN}{C.BOLD}✅ INSTALACIÓN COMPLETADA{C.RESET}\nURL: http://127.0.0.1:{port}\nPID: {proc.pid}\nDirectorio: {project}\nCtrl+C para detener")
    try:
        proc.wait()
    except KeyboardInterrupt:
        print("\nDeteniendo servidor..."); proc.terminate(); ok("Servidor detenido")

if __name__ == "__main__":
    main()
# =================== FIN STARLAB3 (Python) ===================
