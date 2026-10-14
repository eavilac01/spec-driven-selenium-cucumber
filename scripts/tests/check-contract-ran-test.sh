#!/usr/bin/env bash
# Autoprueba de CHK-20 (scripts/check-contract-ran.sh; ADR-004, D5).
#
# Uso: bash scripts/tests/check-contract-ran-test.sh
#
# Crea en un directorio temporal fuera del repositorio (mktemp -d) un repo git
# mínimo con una clase de contrato versionada y su reporte de Surefire, y
# exige, con la línea "<ruta>: CHK-20: <motivo>" esperada en cada exit 1:
#   - exit 0 con un reporte válido, con una clase en un subpaquete, con un
#     archivo de contract que no es *Test.java, con un *Test.java sin
#     versionar, desde un subdirectorio, con los atributos en otro orden y
#     en varias líneas, y con ceros a la izquierda (base 10);
#   - exit 1 sin clases versionadas, sin reporte (también con el directorio
#     de reportes ausente o con un directorio en lugar del reporte), sin el
#     elemento <testsuite>, con tests="0" o "00", skipped="1", failures="1",
#     errors="1", sin cada uno de los cuatro atributos, con un valor que no es
#     un entero, con "tests" solo como sufijo de otro atributo o solo en un
#     elemento interior, con dos clases de las que falta un reporte y con
#     una clase de nombre no ASCII sin reporte (git ls-files -z);
#   - exit 2 con argumentos de más, sin argumentos, con un argumento vacío,
#     fuera de un repositorio, con un índice corrupto y con un git ls-files
#     que termina con rc distinto de 0 sin stderr, o con 0 y stderr (shim).
#
# Sale con 0 solo si todos los casos se comportan como se espera; con 1 si
# alguno falla; con 2 ante un error de preparación. Imprime la tabla
# caso → esperado → real. El temporal se borra al salir (trap). Sin awk.
set -euo pipefail
export LC_ALL=C

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
script="$here/../check-contract-ran.sh"
repo_root="$(cd "$here/../.." && pwd -P)"
if [ ! -f "$script" ]; then
  echo "check-contract-ran-test: no existe $script" >&2
  exit 2
fi

# Git aislado de la configuración del usuario y del sistema, sin
# mantenimiento automático (ver check-layers-test.sh).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE GIT_COMMON_DIR \
  GIT_CONFIG_PARAMETERS GIT_TRACE
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_COUNT=4
export GIT_CONFIG_KEY_0=maintenance.auto GIT_CONFIG_VALUE_0=false
export GIT_CONFIG_KEY_1=gc.auto GIT_CONFIG_VALUE_1=0
export GIT_CONFIG_KEY_2=maintenance.autoDetach GIT_CONFIG_VALUE_2=false
export GIT_CONFIG_KEY_3=gc.autoDetach GIT_CONFIG_VALUE_3=false
export GIT_AUTHOR_NAME=autoprueba GIT_AUTHOR_EMAIL=autoprueba@localhost
export GIT_COMMITTER_NAME=autoprueba GIT_COMMITTER_EMAIL=autoprueba@localhost

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
tmp="$(cd "$tmp" && pwd -P)"
case "$tmp/" in
  "$repo_root"/*)
    echo "check-contract-ran-test: el temporal $tmp está dentro del repositorio" >&2
    exit 2
    ;;
esac
export GIT_CEILING_DIRECTORIES="$tmp"

CT=src/test/java/com/demo/contract
R=target/surefire-reports
CLASE=com.demo.contract.NavegadorContractTest
REP="$R/TEST-$CLASE.xml"
CABECERA_XML='<?xml version="1.0" encoding="UTF-8"?>'
XSI='xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.0.2"'

put() {
  local path="$1"
  shift
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$@" > "$path"
}

# reporte <ruta> <clase> <atributos de testsuite>: reporte mínimo de Surefire.
reporte() {
  put "$1" "$CABECERA_XML" \
    "<testsuite $XSI name=\"$2\" time=\"1.5\" $3>" \
    "  <testcase name=\"ct01\" classname=\"$2\" time=\"0.5\"/>" \
    '</testsuite>'
}
VALIDOS='tests="8" errors="0" skipped="0" failures="0"'

# ---------------------------------------------------------------- repo base
base="$tmp/base"
mkdir -p "$base"
(
  cd "$base"
  git init -q .
  put "$CT/NavegadorContractTest.java" 'package com.demo.contract;' 'class NavegadorContractTest {' '}'
  put src/test/java/com/demo/config/OtroTest.java 'package com.demo.config;' 'class OtroTest {' '}'
  git add -A
  git -c commit.gpgsign=false commit -q -m base
  reporte "$REP" "$CLASE" "$VALIDOS"
) || { echo "check-contract-ran-test: no se pudo crear el repositorio base" >&2; exit 2; }

# ------------------------------------------------------------------- arnés
n=0
total=0
fails=0
table=""
dir=""
rc=0
out=""

new_case() {
  n=$((n + 1))
  dir="$tmp/case-$n"
  cp -a "$base" "$dir" || {
    echo "check-contract-ran-test: no se pudo copiar el repositorio base al caso $n" >&2
    exit 2
  }
}

# run_in <directorio> <argumentos…>: ejecuta el control desde ese directorio.
run_in() {
  local cwd="$1"
  shift
  rc=0
  out="$(cd "$cwd" && bash "$script" "$@" 2>&1)" || rc=$?
}

# expect <caso> <exit esperado> [línea exacta que debe aparecer en la salida]
expect() {
  local name="$1" want="$2" needle="${3:-}" verdict=ok
  [ "$rc" -eq "$want" ] || verdict=FALLA
  total=$((total + 1))
  if [ -n "$needle" ]; then
    grep -qxF -- "$needle" <<<"$out" || verdict=FALLA
  fi
  if [ "$verdict" != ok ]; then
    fails=$((fails + 1))
    {
      echo "--- FALLA: $name (esperado $want, real $rc)"
      [ -z "$needle" ] || echo "    línea esperada: $needle"
      printf '%s\n' "$out" | sed 's/^/    | /'
    } >&2
  fi
  table="${table}$(printf '| %-70s | %8s | %4s | %-5s |' "$name" "$want" "$rc" "$verdict")"$'\n'
}

OK1="check-contract-ran: ok: 1 clase(s) de contrato con su reporte en '$R' (CHK-20)"
OK2="check-contract-ran: ok: 2 clase(s) de contrato con su reporte en '$R' (CHK-20)"
# falla_atributos <id> <atributos> <motivo>: reporte de la clase base con esos
# atributos; exit 1 con "<reporte>: CHK-20: <motivo>".
falla_atributos() {
  new_case
  reporte "$dir/$REP" "$CLASE" "$2"
  run_in "$dir" "$R"
  expect "$1" 1 "$REP: CHK-20: $3"
}

# ------------------------------------------------------------------- casos
new_case
run_in "$dir" "$R"
expect "ok-1 reporte válido" 0 "$OK1"

new_case
put "$dir/$CT/sub/OtroContractTest.java" 'package com.demo.contract.sub;' 'class OtroContractTest {' '}'
git -C "$dir" add -- "$CT/sub/OtroContractTest.java"
reporte "$dir/$R/TEST-com.demo.contract.sub.OtroContractTest.xml" com.demo.contract.sub.OtroContractTest "$VALIDOS"
run_in "$dir" "$R"
expect "ok-2 clase en un subpaquete (nombre calificado)" 0 "$OK2"

new_case
put "$dir/$CT/Paginas.java" 'package com.demo.contract;' 'final class Paginas {' '}'
git -C "$dir" add -- "$CT/Paginas.java"
run_in "$dir" "$R"
expect "ok-3 archivo de contract que no es *Test.java" 0 "$OK1"

new_case
put "$dir/$CT/SinVersionarTest.java" 'package com.demo.contract;' 'class SinVersionarTest {' '}'
run_in "$dir" "$R"
expect "ok-4 *Test.java sin versionar" 0 "$OK1"

new_case
run_in "$dir/src" "$dir/$R"
expect "ok-5 desde un subdirectorio" 0 \
  "check-contract-ran: ok: 1 clase(s) de contrato con su reporte en '$dir/$R' (CHK-20)"

new_case
put "$dir/$REP" "$CABECERA_XML" \
  "<testsuite name=\"$CLASE\"" \
  '    failures="0" errors="0"' \
  '    skipped="0" tests="3">' \
  '</testsuite>'
run_in "$dir" "$R"
expect "ok-6 atributos en otro orden y en varias líneas" 0 "$OK1"

new_case
reporte "$dir/$REP" "$CLASE" 'tests="08" errors="00" skipped="0" failures="0"'
run_in "$dir" "$R"
expect "ok-7 enteros con ceros a la izquierda (base 10, no octal)" 0 "$OK1"

new_case
git -C "$dir" rm -q -- "$CT/NavegadorContractTest.java"
run_in "$dir" "$R"
expect "f-1 sin clases versionadas" 1 "$CT: CHK-20: ningún *Test.java versionado en contract"

new_case
rm -- "$dir/$REP"
run_in "$dir" "$R"
expect "f-2 sin reporte" 1 "$REP: CHK-20: falta el reporte de Surefire de $CLASE"

new_case
run_in "$dir" no-existe
expect "f-2b directorio de reportes ausente" 1 \
  "no-existe/TEST-$CLASE.xml: CHK-20: falta el reporte de Surefire de $CLASE"

new_case
rm -- "$dir/$REP"
mkdir -p "$dir/$REP"
run_in "$dir" "$R"
expect "f-2c un directorio en lugar del reporte" 1 "$REP: CHK-20: falta el reporte de Surefire de $CLASE"

new_case
put "$dir/$REP" "$CABECERA_XML" "<testsuites $VALIDOS>" '</testsuites>'
run_in "$dir" "$R"
expect "f-3 sin el elemento <testsuite> (solo <testsuites>)" 1 \
  "$REP: CHK-20: sin el elemento <testsuite> de $CLASE"

falla_atributos "f-4 tests=0" 'tests="0" errors="0" skipped="0" failures="0"' \
  "tests=0: no se ejecutó ninguna prueba de $CLASE"
falla_atributos "f-4b tests=00 (solo ceros)" 'tests="00" errors="0" skipped="0" failures="0"' \
  "tests=0: no se ejecutó ninguna prueba de $CLASE"
falla_atributos "f-5 skipped=1" 'tests="8" errors="0" skipped="1" failures="0"' "skipped=1 en $CLASE"
falla_atributos "f-6 failures=1" 'tests="8" errors="0" skipped="0" failures="1"' "failures=1 en $CLASE"
falla_atributos "f-7 errors=1" 'tests="8" errors="1" skipped="0" failures="0"' "errors=1 en $CLASE"
falla_atributos "f-8 sin el atributo tests" 'errors="0" skipped="0" failures="0"' \
  "falta el atributo tests en <testsuite> de $CLASE"
falla_atributos "f-8b sin el atributo skipped" 'tests="8" errors="0" failures="0"' \
  "falta el atributo skipped en <testsuite> de $CLASE"
falla_atributos "f-8c sin el atributo failures" 'tests="8" errors="0" skipped="0"' \
  "falta el atributo failures en <testsuite> de $CLASE"
falla_atributos "f-8d sin el atributo errors" 'tests="8" skipped="0" failures="0"' \
  "falta el atributo errors en <testsuite> de $CLASE"
falla_atributos "f-9 valor que no es un entero" 'tests="ocho" errors="0" skipped="0" failures="0"' \
  "el atributo tests de $CLASE no es un entero"
falla_atributos "f-9b valor vacío" 'tests="8" errors="" skipped="0" failures="0"' \
  "el atributo errors de $CLASE no es un entero"
falla_atributos "f-10 tests solo como sufijo de otro atributo" 'xtests="8" errors="0" skipped="0" failures="0"' \
  "falta el atributo tests en <testsuite> de $CLASE"

new_case
put "$dir/$REP" "$CABECERA_XML" \
  "<testsuite name=\"$CLASE\" errors=\"0\" skipped=\"0\" failures=\"0\">" \
  '  <properties tests="8"/>' \
  '</testsuite>'
run_in "$dir" "$R"
expect "f-10b tests solo en un elemento interior" 1 \
  "$REP: CHK-20: falta el atributo tests en <testsuite> de $CLASE"

new_case
put "$dir/$CT/SegundoContractTest.java" 'package com.demo.contract;' 'class SegundoContractTest {' '}'
git -C "$dir" add -- "$CT/SegundoContractTest.java"
run_in "$dir" "$R"
expect "f-11 dos clases y falta un reporte" 1 \
  "$R/TEST-com.demo.contract.SegundoContractTest.xml: CHK-20: falta el reporte de Surefire de com.demo.contract.SegundoContractTest"

new_case
put "$dir/$CT/sub/OtroContractTest.java" 'package com.demo.contract.sub;' 'class OtroContractTest {' '}'
git -C "$dir" add -- "$CT/sub/OtroContractTest.java"
reporte "$dir/$R/TEST-OtroContractTest.xml" OtroContractTest "$VALIDOS"
run_in "$dir" "$R"
expect "f-12 subpaquete con el reporte sin calificar" 1 \
  "$R/TEST-com.demo.contract.sub.OtroContractTest.xml: CHK-20: falta el reporte de Surefire de com.demo.contract.sub.OtroContractTest"

# Sin -z, git ls-files entrecomilla una ruta no ASCII (core.quotePath) y la
# clase se omitiría: falla abierto.
new_case
put "$dir/$CT/PáginaContractTest.java" 'package com.demo.contract;' 'class PáginaContractTest {' '}'
git -C "$dir" add -- "$CT/PáginaContractTest.java"
run_in "$dir" "$R"
expect "f-13 clase con un nombre no ASCII y sin reporte" 1 \
  "$R/TEST-com.demo.contract.PáginaContractTest.xml: CHK-20: falta el reporte de Surefire de com.demo.contract.PáginaContractTest"

USO="check-contract-ran: uso: bash scripts/check-contract-ran.sh <directorio de reportes de Surefire>"
new_case
run_in "$dir" "$R" otro
expect "e-1 argumentos de más" 2 "$USO"
run_in "$dir"
expect "e-2 sin argumentos" 2 "$USO"
run_in "$dir" ""
expect "e-3 argumento vacío" 2 "$USO"

mkdir -p "$tmp/no-repo"
run_in "$tmp/no-repo" "$R"
expect "e-4 fuera de un repositorio" 2 "check-contract-ran: no es un repositorio git"

new_case
printf 'corrupto' > "$dir/.git/index"
run_in "$dir" "$R"
expect "e-5 índice corrupto (git ls-files rc >= 2)" 2 "check-contract-ran: git ls-files terminó con 128"

# Shim de git en el PATH: ls-files falla sin stderr, o termina con 0 y stderr;
# el resto de órdenes van al git real.
real_git="$(command -v git)"
shim="$tmp/shim"
mkdir -p "$shim"
cat > "$shim/git" <<EOF
#!/usr/bin/env bash
for a in "\$@"; do
  if [ "\$a" = ls-files ]; then
    case "\${SHIM_MODO:-}" in
      rc) exit 3 ;;
      stderr) echo "aviso del shim" >&2; exec "$real_git" "\$@" ;;
    esac
  fi
done
exec "$real_git" "\$@"
EOF
chmod +x "$shim/git"
new_case
rc=0
out="$(cd "$dir" && PATH="$shim:$PATH" SHIM_MODO=rc bash "$script" "$R" 2>&1)" || rc=$?
expect "e-6 git ls-files con rc 3 sin stderr" 2 "check-contract-ran: git ls-files terminó con 3"
rc=0
out="$(cd "$dir" && PATH="$shim:$PATH" SHIM_MODO=stderr bash "$script" "$R" 2>&1)" || rc=$?
expect "e-7 git ls-files con rc 0 y stderr" 2 "check-contract-ran: git ls-files terminó con 0"
# Control del shim: sin modo, el mismo caso da 0 (el shim no rompe nada más).
rc=0
out="$(cd "$dir" && PATH="$shim:$PATH" bash "$script" "$R" 2>&1)" || rc=$?
expect "control: el shim sin modo da 0" 0 "$OK1"

# ------------------------------------------------------------------- resumen
printf '| %-70s | %8s | %4s | %-5s |\n' caso esperado real ok
printf '%s' "$table"
if [ "$fails" -ne 0 ]; then
  echo "check-contract-ran-test: FALLA: $fails de $total casos no se comportan como se espera"
  exit 1
fi
echo "check-contract-ran-test: ok: $total casos"
