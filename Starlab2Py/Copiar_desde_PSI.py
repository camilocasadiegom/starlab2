import os
import shutil
from pathlib import Path

# 🟢 Carpetas de origen y destino
PSI_DIR = Path.home() / "Documents" / "Starlab2"
PY_DIR = Path.home() / "Documents" / "Starlab2Py" / "PSI_Backup"

def copiar_archivos(origen, destino):
    if destino.exists():
        print("♻️ Eliminando copia anterior...")
        shutil.rmtree(destino)
    print("📂 Creando nueva copia desde PSI...")
    shutil.copytree(origen, destino)
    print("✅ Copia completada correctamente.")

def listar_archivos(destino):
    print("\n📜 Archivos copiados:")
    for root, dirs, files in os.walk(destino):
        for file in files:
            print(f" - {os.path.relpath(os.path.join(root, file), destino)}")

def main():
    print("🚀 Iniciando sincronización manual Starlab2 → Starlab2Py")
    if not PSI_DIR.exists():
        print(f"❌ Carpeta origen no encontrada: {PSI_DIR}")
        return
    copiar_archivos(PSI_DIR, PY_DIR)
    listar_archivos(PY_DIR)
    print("\n🎉 Sincronización finalizada sin errores.")

if __name__ == "__main__":
    main()
