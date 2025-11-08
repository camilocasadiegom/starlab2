from fastapi import FastAPI, HTMLResponse, Request
app = FastAPI(title="Starlab2 - Formulario en LÃ­nea")

@app.get("/health")
def health_check():
    return {"status": "healthy"}

@app.get("/", response_class=HTMLResponse)
async def home():
    return """
    <html><body>
    <h1>ðŸŒŸ Starlab2</h1>
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
