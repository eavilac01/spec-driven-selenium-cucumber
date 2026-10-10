#!/usr/bin/env bash
# Espera a que Selenium Grid informe `value.ready == true` en /status.
#
# Uso: bash scripts/wait-for-grid.sh [url-del-grid] [timeout-segundos]
#      (por defecto: http://localhost:4444 y 120)
#
# Consulta /status cada 2 s hasta que el Grid esté listo. Falla cerrado:
#   0 = listo · 1 = no estuvo listo dentro del plazo · 2 = uso inválido.
# Un Grid que responde sin nodos registrados tiene `ready: false` y no pasa.
# Solo consulta la URL que recibe (el Grid local); no imprime secretos.
set -euo pipefail
export LC_ALL=C

grid_url="${1:-http://localhost:4444}"
timeout_s="${2:-120}"

case "$timeout_s" in
  '' | *[!0-9]*)
    echo "wait-for-grid: el timeout '$timeout_s' no es un entero positivo" >&2
    exit 2
    ;;
esac
if [ "$timeout_s" -le 0 ]; then
  echo "wait-for-grid: el timeout debe ser mayor que 0" >&2
  exit 2
fi
for tool in curl python3; do
  if ! command -v "$tool" > /dev/null 2>&1; then
    echo "wait-for-grid: falta '$tool'" >&2
    exit 2
  fi
done

status_url="${grid_url%/}/status"

grid_ready() {
  local body
  body=$(curl -fsS --max-time 5 "$status_url" 2> /dev/null) || return 1
  printf '%s' "$body" | python3 -I -c '
import json, sys
try:
    ready = json.load(sys.stdin)["value"]["ready"]
except Exception:
    sys.exit(1)
sys.exit(0 if ready is True else 1)
'
}

deadline=$((SECONDS + timeout_s))
until grid_ready; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "wait-for-grid: $status_url no estuvo listo en ${timeout_s} s" >&2
    exit 1
  fi
  sleep 2
done
echo "wait-for-grid: $status_url listo tras ${SECONDS} s"
