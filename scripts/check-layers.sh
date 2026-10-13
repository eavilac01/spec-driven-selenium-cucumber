#!/usr/bin/env bash
# CHK-17 — Comprobación de capas (ADR-002, D4, D6 y D7: reglas R1–R6).
#
# Uso: bash scripts/check-layers.sh [raíz]   (raíz por defecto: .)
#
# Ejecuta los comandos de D7 tal como están especificados (git grep
# --untracked -nP, con exclusiones ":!"), incluidas la ampliación de R3, la
# restricción de ResultadoClic de D1 y las firmas expuestas (ver abajo).
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
#      "directorio:0: D6: motivo", y una línea de presencia que falta (o su
#      archivo), como "archivo:0: D8: motivo".
#   2  no se pudo evaluar (falla cerrado): argumentos de más (también en
#      require, que recibe una sola ruta), la raíz no es un
#      directorio o no es la raíz de un repositorio git, git grep terminó con
#      un código >= 2 o escribió en stderr (índice corrupto, configuración
#      inválida, git sin PCRE, archivo ilegible), git ls-files falló, o el awk
#      de la unión por imports terminó con un código distinto de 0.
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
# Firmas expuestas (D7, enmienda 2026-10-13). En R1, R3 y R6, una firma o un
# miembro "público" es una declaración expuesta: una línea que, después de
# espacios, anotaciones y modificadores, lleva public o protected (EXP). MOD es
# un elemento de ese prefijo: una anotación, simple o calificada, con o sin
# argumentos, o un modificador (non-sealed o cualquier palabra en minúsculas;
# una lista cerrada fallaría abierto ante un modificador nuevo). TIPO es una
# interfaz, una anotación (@interface) o un record expuestos: sus miembros son
# públicos sin escribir public, así que en transport, pages y actions se
# rechazan (R1-tipos y R3-tipos). MOD, EXP y TIPO se definen una sola vez, y
# las siete comprobaciones de firmas y tipos los usan.
# Una línea que empieza por "//", "*", una cadena o un nombre en mayúscula no
# coincide con EXP: pasan comentarios, cadenas, variables locales y miembros
# privados o de paquete.
#
# R3 en acciones: el tipo de retorno se busca hasta el primer "("; la página
# como parámetro, como un tipo *Page (en mayúscula, para no confundirlo con un
# nombre de variable) después del "(" de un método expuesto. Los constructores
# sí reciben páginas (D3) y se excluyen con (?!\s+\w+\s*\(): un constructor es
# el único miembro con un solo identificador entre el modificador de acceso y
# "(". Busca hasta el final de la línea, así que una anotación con argumentos
# no oculta el parámetro; a cambio, una línea con cuerpo que cree una página da
# un falso positivo, que falla cerrado.
#
# Restricción de D1 (enmienda 2026-10-13), en la fila de pages de R6: ningún
# miembro expuesto de una página recibe ni devuelve Navegador.ResultadoClic.
# Si una página lo expusiera, una acción podría recibirlo con "var" sin nombrar
# com.demo.transport, y la línea de actions de R6 no lo vería.
#
# Selenium en el transporte y herencia (D7, enmienda 2026-10-13, parte 2). En
# transport, los nombres de Selenium se derivan de los imports de cada archivo
# (IMP): una línea expuesta (R1-imp) o de herencia (HER, R1-her) incumple si
# alguno de sus tokens es "openqa" o el nombre simple de un import de org.openqa
# del mismo archivo, salvo By (union_imports, con awk). Los comodines de
# Selenium se rechazan (R1-wild), porque no dan nombre; By solo puede ir como
# parámetro (R1-by); transport, actions y utils no extienden otra clase
# (R5-ext), como pages (D7-11). Si awk termina con un código distinto de 0, el
# resultado es 2.
#
# Clic nativo único, scripts cerrados y preferencias de Chrome (D7, enmienda
# 2026-10-13, parte 4). En transport: executeScript solo con un script de la
# lista cerrada JS_LISTA y nunca executeAsyncScript (R5-js); ningún evento
# sintético ni otra vía de entrada: teclado, envío de formularios, Actions, CDP
# y BiDi (EVT, R5-evt); toda línea de clic es exactamente "elemento.click();"
# (FORMA, R5-clic) y hay una como mucho (check_max, R5-clic-max). Además,
# DriverFactory.java aplica las preferencias de Chrome de BrowserSettings
# (PREFS, regla de presencia D8-prefs, con require). Los comentarios cuentan
# como texto (D6).
#
# Conteo y presencia: check_max y require usan el ejecutor de dos pasadas con
# sus guardas (grep2), sin awk. check_max cuenta las líneas distintas
# (archivo:línea) de las dos pasadas; require falla si ninguna pasada encuentra
# la línea, y sin el archivo también (no hay coincidencias: falla cerrado).
#
# Riesgo residual aceptado (D6, R-5): firmas, cabeceras y anotaciones partidas
# en varias líneas, y texto que no sea espacio, anotación ni modificador antes
# del modificador de acceso.
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
# Declaración expuesta (Firmas expuestas, D7): espacios, anotaciones y
# modificadores antes de public o protected.
MOD='(?:@[\w.]+(?:\(.*\))?|non-sealed|[a-z]+)\s+'
EXP='^\s*(?:'"$MOD"')*(?:public|protected)\b'
TIPO="$EXP"'.*\b(?:interface|record)\s+\w'
# Clic nativo único y scripts cerrados (D7, parte 4): la lista cerrada de
# scripts, las llamadas a scripts fuera de ella, las vías de entrada distintas
# del clic nativo, la línea de clic y su forma exacta.
JS_LISTA='SCRIPT_DESPLAZAR_AL_CENTRO|SCRIPT_LEER_CODIGO_PAGINA_ERROR'
JS='\bexecuteAsyncScript\b|\bexecuteScript\b(?!\((?:'"$JS_LISTA"')[,)])'
EVT='\bKeys\b|dispatch\w*Event|executeCdpCommand|(?:\.|::)(?:requestSubmit|submit)\b|org\.openqa\.selenium\.(?:interactions|devtools|bidi)'
CLIC='(?:\.|::)click\b'
FORMA='^(?!\s*elemento\.click\(\);\s*$).*'"$CLIC"
status=0

errf="$(mktemp)"
trap 'rm -f "$errf"' EXIT

# Ejecutor de dos pasadas, con guardas: grep2 <regla> <motivo> <git grep…> deja
# en $grep_out las coincidencias de las dos pasadas, una por línea, como
# "archivo<TAB>línea<TAB>contenido" (-z separa ruta, línea y contenido con NUL).
# git grep: 0 = hay coincidencias, 1 = sin coincidencias, >= 2 = error; rc >= 2
# o texto en stderr salen con 2. --no-color y --no-column aíslan el formato de
# la configuración del usuario. Se llama directamente, nunca en $(…), para que
# su exit 2 termine el script.
grep_out=""
grep2() {
  local rule="$1" reason="$2"
  shift 2
  local pass rc part
  grep_out=""
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
      grep_out="${grep_out}${part}"$'\n'
    fi
  done
}

# check <regla> <motivo> <git grep…>: cada coincidencia es una violación,
# impresa como "archivo:línea: R<n>: motivo".
check() {
  local rule="$1" reason="$2"
  shift 2
  grep2 "$rule" "$reason" "$@"
  if [ -n "$grep_out" ]; then
    printf '%s' "$grep_out" | awk -F'\t' -v r="$rule" -v m="$reason" \
      'NF >= 2 { print $1 ":" $2 ": " r ": " m }' | sort -t: -k1,1 -k2,2n | uniq
    status=1
  fi
}

# check_max <regla> <motivo> <máximo> <git grep…> (Conteo y presencia, D7):
# cuenta las líneas distintas (archivo:línea) de las dos pasadas juntas; si son
# más que el máximo, imprime cada una como "archivo:línea: <regla>: <motivo>",
# ordenadas como en check. Sin awk (CHK-18) y sin comandos cuyo rc=1 sea normal
# (grep -c) dentro de una sustitución con set -e.
check_max() {
  local rule="$1" reason="$2" max="$3"
  shift 3
  local lines count f l
  grep2 "$rule" "$reason" "$@"
  lines="$(printf '%s' "$grep_out" | cut -f1,2 | sed '/^$/d' | sort -u)"
  count=0
  if [ -n "$lines" ]; then
    count=$(($(printf '%s\n' "$lines" | wc -l)))
  fi
  if [ "$count" -gt "$max" ]; then
    printf '%s\n' "$lines" | while IFS=$'\t' read -r f l; do
      printf '%s:%s: %s: %s\n' "$f" "$l" "$rule" "$reason"
    done | sort -t: -k1,1 -k2,2n | uniq
    status=1
  fi
}

# require <regla> <motivo> <expresión> -- <archivo> (Conteo y presencia, D7):
# una sola ruta (otra cantidad es un error de uso: 2). Si ninguna de las dos
# pasadas encuentra la línea, imprime "<archivo>:0: <regla>: <motivo>". Sin el
# archivo no hay coincidencias, y eso también es la violación (falla cerrado).
# Guarda del directorio padre: sin él, la misma línea y estado 1, sin ejecutar
# git grep. Con --untracked, git grep avisa en stderr ("could not open
# directory") ante un archivo dentro de un directorio inexistente, y grep2 lo
# daría como error (2): la ausencia es una violación, como un directorio de
# capa (D6). Registra la violación; nunca deja pasar.
require() {
  local rule="$1" reason="$2" expr="$3"
  shift 3
  if [ "$#" -ne 2 ] || [ "$1" != -- ]; then
    echo "check-layers: ERROR: require recibe una sola ruta ($rule: $reason)" >&2
    exit 2
  fi
  local file="$2"
  if [ ! -d "$(dirname "$file")" ]; then
    echo "$file:0: $rule: $reason"
    status=1
    return 0
  fi
  grep2 "$rule" "$reason" "$expr" -- "$file"
  if [ -z "$grep_out" ]; then
    echo "$file:0: $rule: $reason"
    status=1
  fi
}

# prefix <tipo> <líneas>: antepone "<tipo><TAB>" a cada línea no vacía.
prefix() {
  local line
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      printf '%s\t%s\n' "$1" "$line"
    fi
  done <<< "$2"
}

# Unión por imports (D7, Selenium en el transporte y herencia): une los imports
# de org.openqa (I) con las líneas candidatas (L) de su mismo archivo. Entrada:
# tipo<TAB>archivo<TAB>línea<TAB>contenido (el contenido puede tener
# tabuladores). Variables: -v r=<regla> -v m=<motivo>. Salida:
# "archivo:línea: <regla>: <motivo>". Un registro de otro tipo sale con 3.
# Solo awk POSIX (CHK-18).
UNION_AWK='
BEGIN { FS = "\t" }
NF == 0 { next }
{
  c = $4
  for (i = 5; i <= NF; i++) c = c "\t" $i
}
$1 == "I" {
  n = split(c, seg, ";")
  for (j = 1; j <= n; j++) {
    if (match(seg[j], /import[ \t]+(static[ \t]+)?org\.openqa\.[A-Za-z0-9_.]+/)) {
      t = substr(seg[j], RSTART, RLENGTH)
      sub(/.*\./, "", t)
      if (t != "" && t != "By") sel[$2 SUBSEP t] = 1
    }
  }
  next
}
$1 == "L" { k++; fa[k] = $2; li[k] = $3; co[k] = c; next }
{ malo = 1 }
END {
  if (malo) exit 3
  for (x = 1; x <= k; x++) {
    n = split(co[x], tok, "[^A-Za-z0-9_]+")
    for (j = 1; j <= n; j++) {
      if (tok[j] == "openqa" || ((fa[x] SUBSEP tok[j]) in sel)) {
        print fa[x] ":" li[x] ": " r ": " m
        break
      }
    }
  }
}
'

# union_imports <regla> <motivo> <candidatas> -- <rutas>: los dos git grep (IMP y
# candidatas) pasan por grep2; los registros llegan a awk por una tubería, y un
# código de awk distinto de 0 sale con 2.
union_imports() {
  local rule="$1" reason="$2" cand="$3"
  shift 3
  local imps cands recs rc out
  grep2 "$rule" "$reason" "$IMP" "$@"
  imps="$grep_out"
  grep2 "$rule" "$reason" "$cand" "$@"
  cands="$grep_out"
  recs="$(prefix I "$imps")"$'\n'"$(prefix L "$cands")"
  rc=0
  out="$(printf '%s\n' "$recs" | awk -v r="$rule" -v m="$reason" "$UNION_AWK")" || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "check-layers: ERROR: awk terminó con $rc ($rule: $reason)" >&2
    exit 2
  fi
  if [ -n "$out" ]; then
    printf '%s\n' "$out" | sort -t: -k1,1 -k2,2n | uniq
    status=1
  fi
}

# R1: Selenium solo en transport; en pages, solo el import de By
check R1 "Selenium fuera de transport y pages" \
  'org\.openqa' -- src ":!$T/transport" ":!$T/pages"
check R1 "en pages solo se permite 'import org.openqa.selenium.By;'" \
  'org\.openqa(?!\.selenium\.By;$)' -- "$T/pages"
# R1: firmas públicas (expuestas)
check R1 "tipo de Selenium en una firma pública del transporte" \
  "$EXP"'.*\b(Web[A-Z]\w*|SearchContext|JavascriptExecutor|TakesScreenshot|Capabilities|\w+Options)\b' -- "$T/transport"
check R1 "By en una firma pública de una página" \
  "$EXP"'.*\bBy\b' -- "$T/pages"
#   … sin interfaces, anotaciones ni records expuestos
check R1 "interfaz, anotación o record expuesto en transport o pages" \
  "$TIPO" -- "$T/transport" "$T/pages"
# R1 en transport (Selenium en el transporte y herencia): import de Selenium y línea de herencia
IMP='\bimport\s+(?:static\s+)?org\.openqa\.'
HER='\b(?:extends|implements)\b'
#   … sin comodines de Selenium (los nombres de la unión salen de los imports)
check R1 "import con comodín de Selenium en transport" \
  '\bimport\s+(?:static\s+)?org\.openqa\.[\w.\s]*\*' -- "$T/transport"
#   … By solo como parámetro (después del primer paréntesis)
check R1 "By fuera de los parámetros de una firma pública del transporte" \
  "$EXP"'[^(]*\bBy\b' -- "$T/transport"
#   … unión por imports: candidata con el token openqa o con un nombre importado de org.openqa en su archivo (salvo By)
union_imports R1 "tipo de Selenium importado o calificado en una firma pública del transporte" \
  "$EXP" -- "$T/transport"
union_imports R1 "transport hereda o implementa un tipo de Selenium" \
  "$HER" -- "$T/transport"
# R3: steps sin páginas ni transporte; acciones sin páginas en sus firmas públicas
check R3 "steps nombran pages o transport" \
  'com\.demo\.(pages|transport)\b' -- "$T/steps"
#   … página como tipo de retorno
check R3 "página en el tipo de retorno de un método público de actions" \
  "$EXP"'[^(]*\b\w+Page\b[^(]*\(' -- "$T/actions"
#   … página como parámetro (constructores exceptuados)
check R3 "página como parámetro de un método público de actions" \
  "$EXP"'(?!\s+\w+\s*\()[^(]*\(.*\b[A-Z]\w*Page\b' -- "$T/actions"
#   … sin interfaces, anotaciones ni records expuestos
check R3 "interfaz, anotación o record expuesto en actions" \
  "$TIPO" -- "$T/actions"
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
#   … transport, actions y utils tampoco heredan (Selenium en el transporte y herencia)
check R5 "una clase de transport, actions o utils extiende otra" \
  '\bextends\b' -- "$T/transport" "$T/actions" "$T/utils"
# R5 en transport (Clic nativo único, scripts cerrados y preferencias de Chrome, parte 4)
#   … executeScript solo con un script de la lista cerrada; executeAsyncScript nunca
check R5 "executeScript fuera de la lista cerrada de scripts del transporte" \
  "$JS" -- "$T/transport"
#   … sin eventos sintéticos ni otras vías de entrada (teclado, envío, Actions, CDP, BiDi)
check R5 "evento sintético o vía de entrada distinta del clic nativo en transport" \
  "$EVT" -- "$T/transport"
#   … toda línea de clic es exactamente elemento.click();
check R5 "clic distinto de la línea de clic nativo del transporte" \
  "$FORMA" -- "$T/transport"
#   … y hay una como mucho (líneas distintas de las dos pasadas)
check_max R5 "más de un clic nativo en transport" 1 \
  "$CLIC" -- "$T/transport"
# R6: una línea por fila de D4 (runners excluido; src/main lo garantiza Maven)
check R6 "transport nombra un paquete fuera de su fila de D4" \
  'com\.demo\.(pages|actions|steps|hooks|runners|data)\b' -- "$T/transport"
check R6 "transport o pages nombran utils distinto de ConfigReader" \
  'com\.demo\.utils\.(?!ConfigReader\b)' -- "$T/transport" "$T/pages"
check R6 "pages nombra un paquete fuera de su fila de D4" \
  'com\.demo\.(actions|steps|hooks|runners|config|data)\b' -- "$T/pages"
# R6 (restricción de D1, enmienda 2026-10-13): ResultadoClic no sale de pages
check R6 "ResultadoClic en un miembro público de una página" \
  "$EXP"'.*\bResultadoClic\b' -- "$T/pages"
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

# D8 (presencia, parte 4): DriverFactory aplica las preferencias de Chrome; sin
# la línea o sin el archivo, es violación.
PREFS='^\s*\w+\.setExperimentalOption\(\s*"prefs"\s*,\s*\w+\.chromePreferences\(\)\s*\)\s*;'
require D8 "DriverFactory no aplica las preferencias de Chrome de BrowserSettings" \
  "$PREFS" -- "$T/transport/DriverFactory.java"

if [ "$status" -eq 0 ]; then
  echo "check-layers: ok: CHK-17 (R1–R6) sin violaciones"
fi
exit "$status"
