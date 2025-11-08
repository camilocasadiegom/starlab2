import os
import shutil
import subprocess
import sys
import time
import urllib.request

# === CONFIGURACIÓN ===
CARPETA_BASE = os.path.join(os.path.expanduser("~"), "Documents", "Starlab2py")
CARPETA_APP = os.path.join(CARPETA_BASE, "app")
CARPETA_STATIC = os.path.join(CARPETA_APP, "static")
CARPETA_TEMPLATES = os.path.join(CARPETA_APP, "templates")
VENV_PATH = os.path.join(CARPETA_BASE, "venv")

print("🚀 Instalador Starlab2py iniciado...")
print("📁 Ruta destino:", CARPETA_BASE)

# === REINICIO DE INSTALACIÓN ===
if os.path.exists(CARPETA_BASE):
    print("⚠️ Carpeta existente detectada, reinstalando...")
    shutil.rmtree(CARPETA_BASE)

# === CREAR ESTRUCTURA ===
os.makedirs(CARPETA_STATIC, exist_ok=True)
os.makedirs(CARPETA_TEMPLATES, exist_ok=True)
print("✅ Estructura creada correctamente.")
# === CREAR ENTORNO VIRTUAL ===
print("🧩 Creando entorno virtual...")
subprocess.run([sys.executable, "-m", "venv", VENV_PATH], check=True)

# === INSTALAR DEPENDENCIAS ===
pip_path = os.path.join(VENV_PATH, "Scripts", "pip.exe") if os.name == "nt" else os.path.join(VENV_PATH, "bin", "pip")
print("📦 Instalando Flask y Requests...")
subprocess.run([pip_path, "install", "--upgrade", "pip"], check=True)
subprocess.run([pip_path, "install", "flask", "requests"], check=True)
print("✅ Dependencias instaladas correctamente.")
app_code = r'''
from flask import Flask, render_template, request
import os

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/enviar', methods=['POST'])
def enviar():
    nombre = request.form.get('nombre')
    mensaje = request.form.get('mensaje')
    print(f"📨 Mensaje recibido: {nombre} -> {mensaje}")
    return f"Gracias, {nombre}. Tu mensaje fue recibido correctamente."

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8000)
'''

html_code = r'''
<!DOCTYPE html>
<html>
<head>
    <title>🌌 Starlab2py</title>
    <style>
        body { font-family: Arial; background: #0c0c2d; color: #fff; text-align: center; padding: 50px; }
        form { background: #1a1a40; padding: 20px; border-radius: 10px; display: inline-block; }
        input, textarea { width: 250px; margin: 5px; padding: 8px; border-radius: 5px; border: none; }
        button { padding: 10px 20px; background: #00aaff; color: white; border: none; border-radius: 5px; cursor: pointer; }
    </style>
</head>
<body>
    <h1>Bienvenido a Starlab2py</h1>
    <form action="/enviar" method="POST">
        <input type="text" name="nombre" placeholder="Tu nombre" required><br>
        <textarea name="mensaje" placeholder="Tu mensaje" required></textarea><br>
        <button type="submit">Enviar</button>
    </form>
</body>
</html>
'''

# === GUARDAR ARCHIVOS ===
with open(os.path.join(CARPETA_APP, "app.py"), "w", encoding="utf-8") as f:
    f.write(app_code)

with open(os.path.join(CARPETA_TEMPLATES, "index.html"), "w", encoding="utf-8") as f:
    f.write(html_code)

print("🧠 Archivos Flask creados correctamente.")
python_path = os.path.join(VENV_PATH, "Scripts", "python.exe") if os.name == "nt" else os.path.join(VENV_PATH, "bin", "python")
flask_app = os.path.join(CARPETA_APP, "app.py")

print("🚀 Iniciando servidor local en http://127.0.0.1:8000 ...")
server = subprocess.Popen([python_path, flask_app])
time.sleep(5)
print("🌍 Creando túnel Cloudflare gratuito...")

# Descargar Cloudflared si no existe
cloudflared_path = os.path.join(CARPETA_BASE, "cloudflared.exe")
if not os.path.exists(cloudflared_path):
    print("📥 Descargando Cloudflared...")
    url = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
    urllib.request.urlretrieve(url, cloudflared_path)

print("🔗 Iniciando túnel, espera unos segundos...")
tunnel = subprocess.Popen(
    [cloudflared_path, "tunnel", "--url", "http://127.0.0.1:8000"],
    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
)

for line in tunnel.stdout:
    if "trycloudflare.com" in line:
        print("\n✅ Tu enlace público Starlab2py está listo:")
        print(line.strip())
        print("\nCópialo y ábrelo en tu navegador 🌐")
        break
print("\n📦 Instalación completa de Starlab2py ✅")
print("Servidor local y túnel Cloudflare activos.")
print("Usa Ctrl + C para detener el servidor cuando termines.")
input("\nPresiona ENTER para salir...")
