# ============================================================
# 📱 Módulo: validar_whatsapp.ps1
# Descripción: Abre WhatsApp Desktop o Web con interfaz gráfica
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 🔹 Función para guardar log automáticamente
function Guardar-Log {
    param(
        [string]$Mensaje,
        [string]$Tipo = "INFO"
    )
    
    $RutaLog = "C:\Users\Camilo C\Documents\starlab2\logs\validaciones.log"
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Linea = "[$Timestamp] [$Tipo] $Mensaje"
    
    Add-Content -Path $RutaLog -Value $Linea -Encoding UTF8
    
    # También mostrar en consola con colores
    switch ($Tipo) {
        "ERROR" { Write-Host $Linea -ForegroundColor Red }
        "SUCCESS" { Write-Host $Linea -ForegroundColor Green }
        "WARNING" { Write-Host $Linea -ForegroundColor Yellow }
        default { Write-Host $Linea -ForegroundColor Cyan }
    }
}

# 🔹 Iniciar sesión de validación
Guardar-Log "==================== NUEVA SESIÓN DE VALIDACIÓN ====================" "INFO"
Guardar-Log "Sistema de validación de WhatsApp iniciado" "INFO"

# 🔹 Crear ventana emergente para ingresar número
$form = New-Object System.Windows.Forms.Form
$form.Text = "📱 Validación WhatsApp - Starlab 2.0"
$form.Size = New-Object System.Drawing.Size(500, 280)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)

# Título
$label1 = New-Object System.Windows.Forms.Label
$label1.Location = New-Object System.Drawing.Point(20, 20)
$label1.Size = New-Object System.Drawing.Size(460, 30)
$label1.Text = "🌟 Ingrese el número de WhatsApp a validar"
$label1.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$label1.ForeColor = [System.Drawing.Color]::FromArgb(0, 102, 204)
$form.Controls.Add($label1)

# Instrucciones
$label2 = New-Object System.Windows.Forms.Label
$label2.Location = New-Object System.Drawing.Point(20, 55)
$label2.Size = New-Object System.Drawing.Size(460, 40)
$label2.Text = "Incluya el código de país sin el símbolo '+'" + [Environment]::NewLine + "Ejemplo: 573216549870 (Colombia) o 5491112345678 (Argentina)"
$label2.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$label2.ForeColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
$form.Controls.Add($label2)

# Campo de texto
$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(20, 105)
$textBox.Size = New-Object System.Drawing.Size(440, 30)
$textBox.Font = New-Object System.Drawing.Font("Segoe UI", 14)
$textBox.MaxLength = 15
$form.Controls.Add($textBox)

# Label de estado
$labelEstado = New-Object System.Windows.Forms.Label
$labelEstado.Location = New-Object System.Drawing.Point(20, 145)
$labelEstado.Size = New-Object System.Drawing.Size(460, 20)
$labelEstado.Text = ""
$labelEstado.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$labelEstado.ForeColor = [System.Drawing.Color]::Gray
$form.Controls.Add($labelEstado)

# Botón Validar
$buttonValidar = New-Object System.Windows.Forms.Button
$buttonValidar.Location = New-Object System.Drawing.Point(250, 180)
$buttonValidar.Size = New-Object System.Drawing.Size(210, 40)
$buttonValidar.Text = "✅ Validar y Abrir WhatsApp"
$buttonValidar.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$buttonValidar.BackColor = [System.Drawing.Color]::FromArgb(37, 211, 102)
$buttonValidar.ForeColor = [System.Drawing.Color]::White
$buttonValidar.FlatStyle = "Flat"
$buttonValidar.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($buttonValidar)

# Botón Cancelar
$buttonCancelar = New-Object System.Windows.Forms.Button
$buttonCancelar.Location = New-Object System.Drawing.Point(20, 180)
$buttonCancelar.Size = New-Object System.Drawing.Size(210, 40)
$buttonCancelar.Text = "❌ Cancelar"
$buttonCancelar.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$buttonCancelar.BackColor = [System.Drawing.Color]::FromArgb(220, 53, 69)
$buttonCancelar.ForeColor = [System.Drawing.Color]::White
$buttonCancelar.FlatStyle = "Flat"
$buttonCancelar.Cursor = [System.Windows.Forms.Cursors]::Hand
$buttonCancelar.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.Add($buttonCancelar)

# 🔹 Evento del botón Validar
$buttonValidar.Add_Click({
    $Numero = $textBox.Text
    $NumeroLimpio = $Numero -replace "\D", ""
    
    Guardar-Log "Número ingresado por usuario: $Numero" "INFO"
    Guardar-Log "Número limpio procesado: $NumeroLimpio" "INFO"
    
    # Validaciones
    if ([string]::IsNullOrWhiteSpace($NumeroLimpio)) {
        $labelEstado.Text = "⚠️ Por favor, ingrese un número"
        $labelEstado.ForeColor = [System.Drawing.Color]::Red
        Guardar-Log "Error: Campo vacío" "ERROR"
        return
    }
    
    if ($NumeroLimpio.Length -lt 10) {
        $labelEstado.Text = "⚠️ El número debe tener al menos 10 dígitos"
        $labelEstado.ForeColor = [System.Drawing.Color]::Red
        Guardar-Log "Error: Número muy corto ($($NumeroLimpio.Length) dígitos)" "ERROR"
        return
    }
    
    if ($NumeroLimpio -notmatch "^\d{10,15}$") {
        $labelEstado.Text = "⚠️ Solo se permiten números (10-15 dígitos)"
        $labelEstado.ForeColor = [System.Drawing.Color]::Red
        Guardar-Log "Error: Formato inválido" "ERROR"
        return
    }
    
    # Validación exitosa
    $labelEstado.Text = "✅ Número válido. Abriendo WhatsApp..."
    $labelEstado.ForeColor = [System.Drawing.Color]::Green
    Guardar-Log "Número validado exitosamente: +$NumeroLimpio" "SUCCESS"
    
    # Buscar WhatsApp Desktop
    $PosiblesRutas = @(
        "$env:LOCALAPPDATA\WhatsApp\WhatsApp.exe",
        "$env:PROGRAMFILES\WhatsApp\WhatsApp.exe",
        "$env:ProgramFiles(x86)\WhatsApp\WhatsApp.exe"
    )
    
    $RutaEncontrada = $null
    foreach ($ruta in $PosiblesRutas) {
        if (Test-Path $ruta) {
            $RutaEncontrada = $ruta
            Guardar-Log "WhatsApp Desktop encontrado en: $ruta" "INFO"
            break
        }
    }
    
    # Crear enlace
    $Enlace = "https://wa.me/$NumeroLimpio"
    Guardar-Log "Enlace generado: $Enlace" "INFO"
    
    # Abrir WhatsApp
    if ($RutaEncontrada) {
        Guardar-Log "Abriendo WhatsApp Desktop..." "INFO"
        Start-Process -FilePath $RutaEncontrada
        Start-Sleep -Seconds 3
        Guardar-Log "Abriendo chat en navegador..." "INFO"
        Start-Process $Enlace
    } else {
        Guardar-Log "WhatsApp Desktop no encontrado. Abriendo WhatsApp Web" "WARNING"
        Start-Process $Enlace
    }
    
    Guardar-Log "Validación completada exitosamente" "SUCCESS"
    Guardar-Log "====================================================================" "INFO"
    
    $form.Close()
})

# 🔹 Evento del botón Cancelar
$buttonCancelar.Add_Click({
    Guardar-Log "Validación cancelada por el usuario" "WARNING"
    Guardar-Log "====================================================================" "INFO"
    $form.Close()
})

# 🔹 Permitir ENTER para validar
$form.AcceptButton = $buttonValidar
$form.CancelButton = $buttonCancelar

# 🔹 Mostrar ventana
$form.Add_Shown({$textBox.Focus()})
[void]$form.ShowDialog()
