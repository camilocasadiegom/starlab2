import os
import subprocess
import shutil
from pathlib import Path

# 🟢 Ruta base del proyecto
BASE_DIR = Path.home() / "Documents" / "Starlab2Py"

# 🟢 Carpetas que queremos crear (si existen, se sobrescriben)
folders = [
    "src",
    "data",
    "logs",
    "config",
    "backups",
    "modules",
    "scripts"
]

def crear_estructura():
    print("📁 Creando estructura de carpetas...")
    for folder in folders:
        path = BASE_DIR / folder
        if path.exists():
            shutil.rmtree(path)
        path.mkdir(parents=True, exist_ok=True)
        print(f"✅ {folder}/ lista")

def crear_entorno_virtual():
    venv_path = BASE_DIR / "venv"
    if venv_path.exists():
        print("♻️ Eliminando entorno virtual anterior...")
        shutil.rmtree(venv_path)

    print("⚙️ Creando entorno virtual...")
    subprocess.run(["python", "-m", "venv", str(venv_path)], check=True)
    print("✅ Entorno virtual creado.")

def instalar_dependencias():
    print("📦 Instalando dependencias principales...")
    requirements = [
        "flask",
        "requests",
        "pandas",
        "openpyxl",
        "twilio"
    ]
    pip_path = BASE_DIR / "venv" / "Scripts" / "pip.exe"
    for pkg in requirements:
        subprocess.run([str(pip_path), "install", pkg])
    print("✅ Dependencias instaladas.")

def crear_archivo_inicio():
    start_script = BASE_DIR / "start_starlab2py.py"
    content = """import os
import subprocess
print('🚀 Iniciando Starlab2Py...')
os.system('python src/main.py')
"""
    with open(start_script, "w", encoding="utf-8") as f:
        f.write(content)
    print("🟢 Archivo de inicio creado: start_starlab2py.py")

def crear_main_base():
    main_file = BASE_DIR / "src" / "main.py"
    content = """print('Bienvenido a Starlab 2.0 en Python')
print('Sistema iniciado correctamente ✅')
"""
    with open(main_file, "w", encoding="utf-8") as f:
        f.write(content)
    print("🧠 Archivo principal creado: src/main.py")

def main():
    print("🚀 Instalador Starlab2Py iniciado...")
    crear_estructura()
    crear_entorno_virtual()
    instalar_dependencias()
    crear_archivo_inicio()
    crear_main_base()
    print("🎉 Instalación completada correctamente.")

if __name__ == "__main__":
    main()
