#!/usr/bin/env bash
# CHK-17 — Comprobación de capas (ADR-002, D4, D6 y D7: reglas R1–R6).
#
# Uso: bash scripts/check-layers.sh [raíz]   (raíz por defecto: .)
#
# Ejecuta los comandos de D7 tal como están especificados (git grep
# --untracked -nP, con exclusiones ":!") más una ampliación de R3 y la
# restricción de ResultadoClic de D1 (ver abajo).
# Cada comando pasa si no produce salida.
#
# Cada comando corre en dos pasadas, y la salida se une sin duplicados:
#   - con --untracked, como en D7: incluye lo no versionado (respetando
#     .gitignore), para que una violación se vea antes del commit;
#   - sin --untracked (archivos del índice). Con git 2.53, --untracked recorre el
#     árbol de trabajo sin leer el índice y omite los archivos versionados que
#     coinciden con .gitignore (p. ej. "._*" o "*.log"): sin esta pasada, un
#     archivo así pasaría sin salida, y un índice corrupto no daría error.
# Cualquier texto en stderr de git grep también es un error (2): con un archivo
# ilegible, git grep imprime "failed to stat" pero termina con 0 o 1.
#
# Salida:
#   0  ninguna violación.
#   1  violaciones; una por línea como "archivo:línea: R<n>: motivo".
#      Un directorio de capa sin archivos versionados se imprime como
#      "directorio:0: D6: motivo".
#   2  no se pudo evaluar (falla cerrado): argumentos de más, la raíz no es un
#      directorio o no es la raíz de un repositorio git, git grep terminó con
#      un código >= 2 o escribió en stderr (índice corrupto, configuración
#      inválida, git sin PCRE, archivo ilegible), o git ls-files falló.
#
# Por qué un directorio de capa ausente es 1 y no 2: es una violación de la
# estructura que verifica CHK-17 (D6 lo exige como una comprobación más, el
# último comando de D7), no una incapacidad de la herramienta para evaluar.
# Sin esa comprobación, un directorio renombrado haría pasar sin salida a
# todos los comandos que lo nombran (una ruta inexistente da rc=1, R-4).
# Si falta todo src/test/java/com/demo, git grep --untracked avisa en stderr
# ("could not open directory") y el resultado es 2: también falla cerrado.
# Las dos guardas de error (rc >= 2 y stderr) se solapan a propósito: con
# git 2.53, todo rc >= 2 observado viene con un "fatal:" en stderr.
#
# La presencia de los directorios de capa usa git ls-files: exige archivos
# versionados (o en el índice).
#
# Ampliación de R3 (separada de D7 a propósito; el arquitecto enmendará D7):
# el comando de D7 '^\s*public\b[^(]*\b\w+Page\b[^(]*\(' solo detecta una
# página en el tipo de retorno: no ve "public void usar(LoginPage pagina) {".
# El comando adicional busca un tipo *Page (en mayúscula, para no confundirlo
# con un nombre de variable) después del "(" de un método público de actions.
# Los constructores sí deben recibir páginas (D3), así que se excluyen con
# (?!\s+\w+\s*\(): un constructor es el único miembro con un solo
# identificador entre "public" y "("; un método lleva además el tipo de
# retorno. Busca hasta el final de la línea (no se detiene en ")"), así que una
# anotación con argumentos no oculta el parámetro; a cambio, una línea con
# cuerpo que cree una página da un falso positivo, que falla cerrado.
# Riesgo residual aceptado (D6, R-5): firmas partidas en varias líneas.
#
# Restricción de D1 (enmienda 2026-10-13), en la fila de pages de R6: ningún
# miembro público de una página recibe ni devuelve Navegador.ResultadoClic.
# Si una página lo expusiera, una acción podría recibirlo con "var" sin nombrar
# com.demo.transport, y la línea de actions de R6 no lo vería. La expresión
# '^\s*public\b.*\bResultadoClic\b' cubre el tipo de retorno, los parámetros y
# los campos públicos, calificado (Navegador.ResultadoClic) o importado. El uso
# dentro del cuerpo o en un método privado no empieza por "public" y pasa.
# Mismo riesgo residual: una firma pública partida en varias líneas.
#
# Solo bash, coreutils, git (con PCRE), grep y awk POSIX (compatible con mawk).
set -euo pipefail
export LC_ALL=C

root="${1:-.}"
if [ "$#" -gt 1 ]; then
  echo "check-layers: uso: bash scripts/check-layers.sh [raíz]" >&2
  exit 2
fi
if [ ! -d "$root" ]; then
  echo "check-layers: la raíz '$root' no es un directorio" >&2
  exit 2
fi
cd "$root"

# Falla cerrado si la raíz no es la raíz de un repositorio: fuera de un repo,
# git grep puede caer a --no-index (grep.fallbackToNoIndex) o fallar, y en un
# subdirectorio las rutas de D7 no existirían y todo pasaría sin salida.
toplevel="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "check-layers: '$root' no es un repositorio git" >&2
  exit 2
}
if [ "$(cd "$toplevel" && pwd -P)" != "$(pwd -P)" ]; then
  echo "check-layers: '$root' no es la raíz del repositorio ($toplevel)" >&2
  exit 2
fi

T=src/test/java/com/demo
status=0

errf="$(mktemp)"
trap 'rm -f "$errf"' EXIT

# git grep: 0 = hay coincidencias (violación), 1 = sin coincidencias, >= 2 = error.
# -z separa ruta, línea y contenido con NUL; se reescribe como
# "archivo:línea: R<n>: motivo". --no-color y --no-column aíslan el formato
# de la configuración del usuario.
check() {
  local rule="$1" reason="$2"
  shift 2
  local pass rc part out=""
  for pass in --untracked versionados; do
    rc=0
    if [ "$pass" = --untracked ]; then
      part="$(git grep --untracked -nP -z --no-color --no-column "$@" 2>"$errf" | tr '\0' '\t')" || rc=$?
    else
      part="$(git grep -nP -z --no-color --no-column "$@" 2>"$errf" | tr '\0' '\t')" || rc=$?
    fi
    if [ "$rc" -ge 2 ] || [ -s "$errf" ]; then
      cat "$errf" >&2
      echo "check-layers: ERROR: git grep terminó con $rc ($rule: $reason)" >&2
      exit 2
    fi
    if [ "$rc" -eq 0 ]; then
      out="${out}${part}"$'\n'
    fi
  done
  if [ -n "$out" ]; then
    printf '%s' "$out" | awk -F'\t' -v r="$rule" -v m="$reason" \
      'NF >= 2 { print $1 ":" $2 ": " r ": " m }' | sort -t: -k1,1 -k2,2n | uniq
    status=1
  fi
}

# R1: Selenium solo en transport; en pages, solo el import de By
check R1 "Selenium fuera de transport y pages" \
  'org\.openqa' -- src ":!$T/transport" ":!$T/pages"
check R1 "en pages solo se permite 'import org.openqa.selenium.By;'" \
  'org\.openqa(?!\.selenium\.By;$)' -- "$T/pages"
# R1: firmas públicas
check R1 "tipo de Selenium en una firma pública del transporte" \
  '^\s*public\b.*\b(Web[A-Z]\w*|SearchContext|JavascriptExecutor|TakesScreenshot|Capabilities|\w+Options)\b' -- "$T/transport"
check R1 "By en una firma pública de una página" \
  '^\s*public\b.*\bBy\b' -- "$T/pages"
# R3: steps sin páginas ni transporte; acciones sin páginas en sus firmas públicas
check R3 "steps nombran pages o transport" \
  'com\.demo\.(pages|transport)\b' -- "$T/steps"
check R3 "página en el tipo de retorno de un método público de actions" \
  '^\s*public\b[^(]*\b\w+Page\b[^(]*\(' -- "$T/actions"
# R3 (ampliación, fuera de D7): página como parámetro; constructores exceptuados
check R3 "página como parámetro de un método público de actions" \
  '^\s*public\b(?!\s+\w+\s*\()[^(]*\(.*\b[A-Z]\w*Page\b' -- "$T/actions"
# R4: JUnit, Cucumber y esperados en su sitio
check R4 "JUnit fuera de steps, runners y las pruebas unitarias" \
  'org\.junit' -- src ":!$T/steps" ":!$T/runners" ":!$T/config" ":!$T/data"
check R4 "Cucumber fuera de steps, hooks y runners" \
  'io\.cucumber' -- src ":!$T/steps" ":!$T/hooks" ":!$T/runners"
check R4 "clave *.expected* en transport, pages o actions" \
  '\.expected' -- "$T/transport" "$T/pages" "$T/actions"
# R5: localización y scripts solo en transport; páginas por composición
check R5 "findElement(s) o executeScript fuera de transport" \
  '\bfindElements?\s*\(|\bexecute(Async)?Script\b' -- src ":!$T/transport"
check R5 "una página extiende una clase" \
  '\bextends\b' -- "$T/pages"
# R6: una línea por fila de D4 (runners excluido; src/main lo garantiza Maven)
check R6 "transport nombra un paquete fuera de su fila de D4" \
  'com\.demo\.(pages|actions|steps|hooks|runners|data)\b' -- "$T/transport"
check R6 "transport o pages nombran utils distinto de ConfigReader" \
  'com\.demo\.utils\.(?!ConfigReader\b)' -- "$T/transport" "$T/pages"
check R6 "pages nombra un paquete fuera de su fila de D4" \
  'com\.demo\.(actions|steps|hooks|runners|config|data)\b' -- "$T/pages"
# R6 (restricción de D1, enmienda 2026-10-13): ResultadoClic no sale de pages
check R6 "ResultadoClic en un miembro público de una página" \
  '^\s*public\b.*\bResultadoClic\b' -- "$T/pages"
check R6 "actions nombra un paquete fuera de su fila de D4" \
  'com\.demo\.(transport|utils|steps|hooks|runners|config)\b' -- "$T/actions"
check R6 "steps nombra un paquete fuera de su fila de D4" \
  'com\.demo\.(hooks|runners|config)\b' -- "$T/steps"
check R6 "utils nombra un paquete fuera de su fila de D4" \
  'com\.demo\.(transport|pages|actions|steps|hooks|runners)\b' -- "$T/utils"
check R6 "hooks nombra un paquete fuera de su fila de D4" \
  'com\.demo\.(pages|actions|steps|runners|config|data)\b' -- "$T/hooks"
check R6 "SecretReader o CredentialsProvider fuera de utils y steps" \
  '\b(SecretReader|CredentialsProvider)\b' -- src ":!$T/utils" ":!$T/steps" ":!$T/config" ":!$T/data"

# Directorios de capa presentes: cada uno debe listar al menos un archivo.
for dir in "$T/transport" "$T/pages" "$T/actions" "$T/steps"; do
  rc=0
  listing="$(git ls-files -- "$dir")" || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "check-layers: ERROR: git ls-files terminó con $rc ($dir)" >&2
    exit 2
  fi
  if [ -z "$listing" ]; then
    echo "$dir:0: D6: directorio de capa sin archivos versionados"
    status=1
  fi
done

if [ "$status" -eq 0 ]; then
  echo "check-layers: ok: CHK-17 (R1–R6) sin violaciones"
fi
exit "$status"
