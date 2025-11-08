# ===============================================
# Módulo: validar_whatsapp.ps1
# Función: Validar número de WhatsApp sin costos
# Autor: Starlab 2.0
# ===============================================

param(
    [string]$Numero
)

# Limpieza del número (eliminar espacios, guiones, etc.)
$NumeroLimpio = $Numero -replace '\D', ''

# Validación básica de longitud y formato internacional
if ($NumeroLimpio.Length -lt 10) {
    Write-Host "❌ Número inválido. Debe tener al menos 10 dígitos." -ForegroundColor Red
    exit
}

if ($NumeroLimpio -notmatch '^(\d{10,15})$') {
    Write-Host "❌ Formato incorrecto. Solo se permiten números." -ForegroundColor Red
    exit
}

# Generar enlace de validación (sin costos)
$Enlace = "https://wa.me/$NumeroLimpio"
Write-Host "✅ Número válido. Abriendo WhatsApp..." -ForegroundColor Green

# Abrir WhatsApp Web o la app del sistema
Start-Process $Enlace
