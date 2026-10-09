#!/usr/bin/env bash
# CHK-15 y CHK-16 (Regla 04; ADR-001, D2 y D3), con los comandos de la Regla 04.
#
# Uso: bash scripts/check-unit-purity.sh [raíz]   (raíz por defecto: .)
#
#   CHK-15: src/main/java no usa entorno, archivos, Selenium, Cucumber ni JUnit.
#   CHK-16: las pruebas unitarias (com.demo.config y com.demo.data) no usan
#           Selenium, Cucumber, capas de prueba, entorno ni .env, y esos
#           directorios solo contienen *Test.java.
#
# Pasa si los tres comandos no tienen salida. Falla cerrada: un error de
# git grep (código > 1, p. ej. una raíz que no es un repositorio) también es 1.
# Existe como script para que GitHub Actions y Jenkins ejecuten lo mismo sin
# reescribir las expresiones regulares en YAML y en Groovy.
set -euo pipefail
export LC_ALL=C

root="${1:-.}"
if [ ! -d "$root" ]; then
  echo "check-unit-purity: la raíz '$root' no es un directorio" >&2
  exit 2
fi
cd "$root"

status=0

# git grep: 0 = hay coincidencias (falla), 1 = sin coincidencias (pasa), > 1 = error.
check_grep() {
  local id="$1"
  shift
  local rc=0
  git grep "$@" || rc=$?
  case "$rc" in
    1) ;;
    0) echo "$id: FALLA: coincidencias arriba"; status=1 ;;
    *) echo "$id: FALLA: git grep terminó con $rc"; status=1 ;;
  esac
}

check_grep CHK-15 -nE 'System\.(getenv|getProperty)|java\.nio\.file|java\.io\.File|getResource|org\.openqa|io\.cucumber|org\.junit' -- src/main/java
check_grep CHK-16 -nE 'org\.openqa|io\.cucumber|com\.demo\.(utils|pages|steps|hooks|runners)|System\.getenv|"\.env"' -- src/test/java/com/demo/config src/test/java/com/demo/data

listing="$(git ls-files src/test/java/com/demo/config src/test/java/com/demo/data)"
extra="$(printf '%s\n' "$listing" | grep -v -e 'Test\.java$' -e '^$' || true)"
if [ -n "$extra" ]; then
  printf '%s\n' "$extra"
  echo "CHK-16: FALLA: archivos que no son *Test.java en los directorios de pruebas unitarias"
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "check-unit-purity: ok: CHK-15 y CHK-16 sin salida"
fi
exit "$status"
