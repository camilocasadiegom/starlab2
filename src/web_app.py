from fastapi import FastAPI, Request, Form, HTTPException
from fastapi.responses import HTMLResponse, FileResponse
from fastapi.templating import Jinja2Templates
from pathlib import Path
import pandas as pd
from datetime import datetime
import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger("starlab2")

app = FastAPI(title="Starlab2", description="Sistema de Registro de Conductores", version="2.0.0")

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
    ensure_csv()
    logger.info("Aplicación iniciada")

@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    try:
        ensure_csv()
        df = pd.read_csv(CSV_PATH, encoding="utf-8")
        return templates.TemplateResponse("registro.html", {"request": request, "conductores": df.to_dict("records"), "mensaje": None, "total": len(df)})
    except Exception as e:
        logger.error(f"Error en home: {e}")
        raise HTTPException(status_code=500, detail=str(e))

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
        logger.error(f"Error al registrar: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/exportar")
async def exportar():
    try:
        ensure_csv()
        if not CSV_PATH.exists():
            raise HTTPException(status_code=404, detail="No hay datos para exportar")
        return FileResponse(path=CSV_PATH, media_type="text/csv", filename=f"conductores_{datetime.now().strftime('%Y%m%d')}.csv")
    except Exception as e:
        logger.error(f"Error al exportar: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health():
    return {"status":"healthy","timestamp":datetime.now().isoformat(),"registros":len(pd.read_csv(CSV_PATH,encoding="utf-8"))}
