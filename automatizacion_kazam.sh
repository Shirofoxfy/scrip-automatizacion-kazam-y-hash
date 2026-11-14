#!/bin/bash

DEST_DIR="/home/tsurugi/Desktop/Grabacion_pericial_pantalla"
mkdir -p "$DEST_DIR"

# 1. Verificar dependencias criticas antes de iniciar la pericia
for cmd in inotifywait kazam sha256sum sha512sum; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[!] ERROR CRÍTICO: La herramienta '$cmd' no está instalada."
        echo "[i] Si falta inotifywait, instálalo con: sudo apt install inotify-tools"
        read -r -p "Presiona ENTER para salir..."
        exit 1
    fi
done

FECHA_INICIO_LOCAL=$(date '+%Y-%m-%d %H:%M:%S %Z')
FECHA_INICIO_UTC=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

echo "========================================================"
echo "   [+] INICIANDO ADQUISICIÓN DE VIDEO FORENSE (KAZAM)   "
echo "========================================================"
echo "[i] Fecha de inicio (Local) : $FECHA_INICIO_LOCAL"
echo "[i] Fecha de inicio (UTC)   : $FECHA_INICIO_UTC"
echo "[i] Directorio de resguardo : $DEST_DIR"
echo "[i] Lanzando entorno de grabación..."

kazam >/dev/null 2>&1 &
KAZAM_PID=$!

echo "[i] Kazam iniciado (PID: $KAZAM_PID). Presiona 'Capture' cuando estés listo."
echo "[i] Al terminar, presiona 'Finish recording' en la barra superior."

# Monitorear tanto escritura directa (close_write) como movimiento de temporales (moved_to)
while read -r NUEVO_ARCHIVO; do
    # Ignorar archivos temporales u ocultos que Kazam crea mientras procesa (.tmp, .part, etc.)
    NOMBRE_BASE=$(basename "$NUEVO_ARCHIVO")
    if [[ ! "$NOMBRE_BASE" =~ ^\. ]] && [[ "$NOMBRE_BASE" =~ \.(mp4|mkv|webm|avi|ogv)$ ]]; then
        # Breve pausa de seguridad para asegurar que el buffer de disco terminó de volcarse
        sleep 1
        
        FECHA_FIN_LOCAL=$(date '+%Y-%m-%d %H:%M:%S %Z')
        FECHA_FIN_UTC=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
        TAMANO=$(du -h "$NUEVO_ARCHIVO" | cut -f1)

        echo "--------------------------------------------------------"
        echo "[+] Grabación finalizada y detectada en el disco."
        echo "[+] Archivo : $NUEVO_ARCHIVO"
        echo "[+] Tamaño  : $TAMANO"
        echo "[+] Calculando hashes (SHA-256 y SHA-512) para garantía de inmutabilidad..."
        
        HASH_FILE="${NUEVO_ARCHIVO}.sha256"
        ACTA_FILE="${NUEVO_ARCHIVO}.info_pericial.txt"

        # Generar archivo estandar .sha256 (compatible con sha256sum -c)
        sha256sum "$NUEVO_ARCHIVO" > "$HASH_FILE"

        # Generar reporte pericial completo con marcas de tiempo de inicio/fin y hashes
        {
            echo "========================================================"
            echo "         REPORTE DE ADQUISICIÓN DE VIDEO FORENSE        "
            echo "========================================================"
            echo "Archivo adquirido   : $NOMBRE_BASE"
            echo "Ruta completa       : $NUEVO_ARCHIVO"
            echo "Tamaño              : $TAMANO ($(stat -c%s "$NUEVO_ARCHIVO") bytes)"
            echo "Fecha inicio (Local): $FECHA_INICIO_LOCAL"
            echo "Fecha inicio (UTC)  : $FECHA_INICIO_UTC"
            echo "Fecha fin (Local)   : $FECHA_FIN_LOCAL"
            echo "Fecha fin (UTC)     : $FECHA_FIN_UTC"
            echo "Usuario / Host      : $(whoami)@$(hostname)"
            echo "--------------------------------------------------------"
            echo "HASH SHA-256:"
            cat "$HASH_FILE"
            echo "--------------------------------------------------------"
            echo "HASH SHA-512:"
            sha512sum "$NUEVO_ARCHIVO"
            echo "========================================================"
        } > "$ACTA_FILE"

        # Proteger evidencia contra escritura accidental (solo lectura)
        chmod 444 "$NUEVO_ARCHIVO" "$HASH_FILE" "$ACTA_FILE"
        
        echo ""
        echo "[✓] CADENA DE CUSTODIA ASEGURADA (Archivos protegidos en modo Solo Lectura):"
        cat "$HASH_FILE"
        echo "[✓] Acta técnica generada en: $ACTA_FILE"
        echo "--------------------------------------------------------"
        echo "[i] Proceso finalizado. Puedes cerrar esta ventana presionando ENTER."
        break
    fi
done < <(inotifywait -m -e close_write -e moved_to --format "%w%f" "$DEST_DIR" 2>/dev/null)

read -r -p ""
