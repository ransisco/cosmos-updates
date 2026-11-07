#!/bin/sh
# NotFox - actualizador propio.
# Comprueba un manifiesto JSON y, si hay versión nueva, descarga el .deb,
# verifica su sha256 y lo instala con pkexec. Sin dependencias extra:
# usa curl, sed, sha256sum, pgrep, zenity/notify-send, pkexec y dpkg,
# todo presente en Linux Mint.

set -u

MANIFEST_URL="${NOTFOX_MANIFEST_URL:-https://raw.githubusercontent.com/ransisco/cosmos-updates/refs/heads/main/notfox/manifest.json}"
VERSION_FILE="/opt/notfox/notfox-version"
DEB_URL_BASE="https://github.com/ransisco/cosmos-updates/releases/download"

current_version() {
  if [ -f "$VERSION_FILE" ]; then cat "$VERSION_FILE"; else echo "0"; fi
}

json_field() {
  # json_field <clave>  (lee JSON de una línea por stdin)
  sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"
}

is_newer() {
  # is_newer <actual> <nueva> -> 0 si nueva > actual
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" = "$2" ]
}

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send -i notfox "NotFox" "$1" 2>/dev/null || true
}

fetch_manifest() {
  curl -fsSL --max-time 25 "$MANIFEST_URL?cb=$(date +%s)" 2>/dev/null
}

cmd_check() {
  M=$(fetch_manifest) || exit 0
  [ -n "$M" ] || exit 0
  NEW=$(printf '%s' "$M" | json_field version)
  URL=$(printf '%s' "$M" | json_field url)
  SHA=$(printf '%s' "$M" | json_field sha256)
  CUR=$(current_version)
  [ -n "$NEW" ] && [ -n "$URL" ] || exit 0
  if is_newer "$CUR" "$NEW"; then
    notify "Hay una nueva versión: $NEW"
    if command -v zenity >/dev/null 2>&1; then
      if zenity --question --title="Actualización de NotFox" \
          --text="Hay una nueva versión de NotFox: <b>$NEW</b> (tienes $CUR).\n\n¿Instalar ahora? El navegador se cerrará un momento." \
          --ok-label="Actualizar" --cancel-label="Más tarde" 2>/dev/null; then
        do_apply "$URL" "$SHA" "$NEW"
      fi
    fi
  fi
}

cmd_manual() {
  M=$(fetch_manifest) || { zenity --error --title="NotFox" --text="No se pudo comprobar si hay actualizaciones.\nRevisa tu conexión." 2>/dev/null; exit 1; }
  NEW=$(printf '%s' "$M" | json_field version)
  URL=$(printf '%s' "$M" | json_field url)
  SHA=$(printf '%s' "$M" | json_field sha256)
  CUR=$(current_version)
  if [ -n "$NEW" ] && is_newer "$CUR" "$NEW"; then
    if zenity --question --title="Actualización de NotFox" \
        --text="Hay una nueva versión de NotFox: <b>$NEW</b> (tienes $CUR).\n\n¿Instalar ahora? El navegador se cerrará un momento." \
        --ok-label="Actualizar" --cancel-label="Más tarde" 2>/dev/null; then
      do_apply "$URL" "$SHA" "$NEW"
    fi
  else
    zenity --info --title="NotFox" --text="NotFox está al día (versión $CUR)." 2>/dev/null
  fi
}

do_apply() {
  URL="$1"; SHA="$2"; NEW="$3"
  TMP=$(mktemp /tmp/notfox-update-XXXXXX.deb) || exit 1
  notify "Descargando NotFox $NEW..."
  if ! curl -fL --max-time 600 -o "$TMP" "$URL" 2>/dev/null; then
    rm -f "$TMP"
    zenity --error --title="NotFox" --text="No se pudo descargar la actualización.\nInténtalo de nuevo más tarde." 2>/dev/null
    exit 1
  fi
  if [ -n "$SHA" ]; then
    GOT=$(sha256sum "$TMP" | awk '{print $1}')
    if [ "$GOT" != "$SHA" ]; then
      rm -f "$TMP"
      zenity --error --title="NotFox" --text="La descarga no pasó la verificación de integridad.\nNo se ha instalado nada." 2>/dev/null
      exit 1
    fi
  fi
  # Esperar a que el navegador cierre (máx. 90 s)
  if pgrep -f '/opt/notfox/firefox' >/dev/null 2>&1; then
    zenity --info --title="NotFox" --text="Cierra NotFox para terminar la actualización.\nSe instalará en cuanto cierres el navegador." 2>/dev/null &
    ZPID=$!
    N=0
    while pgrep -f '/opt/notfox/firefox' >/dev/null 2>&1 && [ $N -lt 90 ]; do
      sleep 1; N=$((N+1))
    done
    kill $ZPID 2>/dev/null
  fi
  if pgrep -f '/opt/notfox/firefox' >/dev/null 2>&1; then
    rm -f "$TMP"
    zenity --error --title="NotFox" --text="El navegador sigue abierto.\nActualización cancelada; se te avisará de nuevo." 2>/dev/null
    exit 1
  fi
  if pkexec dpkg -i "$TMP"; then
    rm -f "$TMP"
    notify "NotFox $NEW instalado"
    if zenity --question --title="NotFox" --text="Actualización a <b>$NEW</b> instalada.\n\n¿Abrir NotFox ahora?" --ok-label="Abrir" --cancel-label="Cerrar" 2>/dev/null; then
      ( /usr/bin/notfox >/dev/null 2>&1 & )
    fi
  else
    rm -f "$TMP"
    zenity --error --title="NotFox" --text="La instalación falló o se canceló.\nTu versión actual sigue intacta." 2>/dev/null
    exit 1
  fi
}

case "${1:-}" in
  --check)  cmd_check ;;
  --manual) cmd_manual ;;
  --apply)  shift; do_apply "$@" ;;
  *) echo "Uso: notfox-updater [--check|--manual]" >&2; exit 2 ;;
esac
exit 0
