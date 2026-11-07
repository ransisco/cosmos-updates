#!/bin/sh
# NotFox - lanzador
# Desactiva el informe de fallos de Mozilla y lanza una comprobación de
# actualizaciones en segundo plano como máximo una vez al día.

export MOZ_CRASHREPORTER_DISABLE=1

STAMP="${XDG_CACHE_HOME:-$HOME/.cache}/notfox/last-update-check"
if [ ! -f "$STAMP" ] || [ -n "$(find "$STAMP" -mtime +1 2>/dev/null)" ]; then
  mkdir -p "$(dirname "$STAMP")" 2>/dev/null
  touch "$STAMP" 2>/dev/null
  ( sleep 15; /opt/notfox/notfox-updater --check >/dev/null 2>&1 ) &
fi

exec /opt/notfox/firefox -app /opt/notfox/browser/application.ini "$@"
