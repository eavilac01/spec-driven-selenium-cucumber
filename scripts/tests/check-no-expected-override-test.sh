#!/usr/bin/env bash
# Autoprueba de scripts/check-no-expected-override.sh (ADR-003, R-2).
#
# Uso: bash scripts/tests/check-no-expected-override-test.sh
#
# Con logs sintéticos en un temporal fuera del repositorio (mktemp -d), exige:
#   - 0 sin el aviso de D3, con la suite E2E corrida (verde o roja);
#   - 1 con el aviso, con la línea exacta que nombra la clave y sin el valor:
#     en un build verde, en un escenario que falla, sin "Tests run" (el aviso
#     va primero), con dos claves, con timestamps de Jenkins, CRLF, un byte
#     NUL o el acento del mensaje perdido por la codificación; una clave con
#     caracteres no válidos no se repite;
#   - 2 (falla cerrado) sin argumentos o con argumentos de más, con el log
#     ausente, un directorio, ilegible o vacío, sin la línea "Tests run" de
#     RunnerTest, con "Tests run: 0", solo con las unitarias, con otra clase
#     cuyo nombre empieza por RunnerTest, y cuando grep falla (rc >= 2 sin
#     stderr, o stderr con rc 1; shim de grep en el PATH).
# Las casi-coincidencias (otro mensaje parecido) dan 0.
#
# Sale con 0 solo si todos los casos se comportan como se espera; con 1 si
# alguno falla; con 2 ante un error de preparación. Imprime la tabla
# caso → esperado → real. El temporal se borra al salir (trap).
set -euo pipefail
export LC_ALL=C

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
script="$here/../check-no-expected-override.sh"
repo_root="$(cd "$here/../.." && pwd -P)"
[ -f "$script" ] || { echo "check-no-expected-override-test: no existe $script" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'chmod -R u+rwx "$tmp" 2>/dev/null || true; rm -rf "$tmp"' EXIT
tmp="$(cd "$tmp" && pwd -P)"
case "$tmp/" in
  "$repo_root"/*) echo "check-no-expected-override-test: el temporal $tmp está dentro del repositorio" >&2; exit 2 ;;
esac

# ------------------------------------------------------------- piezas de log
# Formato de slf4j-simple (hilo, nivel, logger) y de Surefire 3.5 con -B.
aviso() {
  printf "[ForkJoinPool-1-worker-1] WARN com.demo.utils.ConfigReader - La clave de esperado '%s' viene de una propiedad del sistema (-D): solo es v\xc3\xa1lido en el control negativo (CHK-10)\n" "$1"
}
inicio='[INFO] --- surefire:3.5.3:test (default-test) @ spec-driven-selenium-cucumber ---'
unitarias='[INFO] Tests run: 27, Failures: 0, Errors: 0, Skipped: 0, Time elapsed: 0.081 s -- in com.demo.config.BrowserSettingsTest'
e2e_ok='[INFO] Tests run: 22, Failures: 0, Errors: 0, Skipped: 1, Time elapsed: 61.20 s -- in com.demo.runners.RunnerTest'
e2e_rojo='[ERROR] Tests run: 22, Failures: 1, Errors: 0, Skipped: 1, Time elapsed: 63.02 s <<< FAILURE! -- in com.demo.runners.RunnerTest'
fallo='[ERROR]   el acceso es rechazado: expected: <__VALOR_MANIPULADO__> but was: <Products>'
exito='[INFO] BUILD SUCCESS'
rojo='[ERROR] Failed to execute goal org.apache.maven.plugins:maven-surefire-plugin:3.5.3:test (default-test) on project spec-driven-selenium-cucumber: There are test failures.'
compila='[ERROR] COMPILATION ERROR :'

# log <nombre> <líneas…>: escribe $tmp/<nombre>.log y deja su ruta en $f.
f=""
log() {
  f="$tmp/$1.log"
  shift
  printf '%s\n' "$@" > "$f"
}

# ------------------------------------------------------------------- arnés
total=0
fails=0
table=""
rc=0
out=""

run() {
  rc=0
  out="$(bash "$script" "$@" 2>&1)" || rc=$?
}

# expect <caso> <rc esperado> [línea exacta | re:<regex extendida>]
expect() {
  local name="$1" want="$2" needle="${3:-}" verdict=ok
  [ "$rc" -eq "$want" ] || verdict=FALLA
  case "$needle" in
    "") ;;
    re:*) grep -qE -- "${needle#re:}" <<<"$out" || verdict=FALLA ;;
    *) grep -qxF -- "$needle" <<<"$out" || verdict=FALLA ;;
  esac
  record "$name" "$want" "$verdict"
}

# absent <caso> <texto>: el texto no aparece en la salida del último run.
absent() {
  local verdict=ok
  if grep -qF -- "$2" <<<"$out"; then verdict=FALLA; fi
  record "$1" "-" "$verdict"
}

record() {
  total=$((total + 1))
  if [ "$3" != ok ]; then
    fails=$((fails + 1))
    {
      echo "--- FALLA: $1 (esperado $2, real $rc)"
      printf '%s\n' "$out" | sed 's/^/    | /'
    } >&2
  fi
  table="${table}$(printf '| %-70s | %8s | %4s | %-5s |' "$1" "$2" "$rc" "$3")"$'\n'
}

ok_line() { echo "check-no-expected-override: ok: sin esperados sobrescritos por -D en '$1' (ADR-003, R-2)"; }
r2_line() { echo "$1:$2: R-2: la clave de esperado '$3' se sobrescribió con -D (ADR-003, D3): solo es válido en el control negativo (CHK-10), nunca en CI"; }
sin_e2e='re:^check-no-expected-override: el log .* no tiene la línea "Tests run: N, … -- in com\.demo\.runners\.RunnerTest" con N >= 1'

# ------------------------------------------------------------------- casos
# Sin aviso: 0 (el rc de Maven lo evalúa el job, no este control).
log verde "$inicio" "$unitarias" "$e2e_ok" "$exito"
run "$f"
expect "verde sin aviso" 0 "$(ok_line "$f")"

log rojo "$inicio" "$unitarias" "$fallo" "$e2e_rojo" "$rojo"
run "$f"
expect "escenario en rojo sin aviso" 0 "$(ok_line "$f")"

f="$tmp/verde-crlf.log"
printf '%s\r\n' "$inicio" "$unitarias" "$e2e_ok" "$exito" > "$f"
run "$f"
expect "verde sin aviso con CRLF" 0 "$(ok_line "$f")"

log casi "$inicio" \
  "[INFO] La clave de configuración 'inventory.expected.title' viene de config.properties" \
  "[INFO] La clave de esperado 'inventory.expected.title' viene de config.properties" \
  "[INFO] solo es válido en el control negativo (CHK-10)" \
  "$e2e_ok" "$exito"
run "$f"
expect "casi-coincidencias del mensaje (sin -D)" 0 "$(ok_line "$f")"

# Con aviso: 1, la clave y nunca el valor.
log aviso-verde "$inicio" "$(aviso inventory.expected.title)" "$e2e_ok" "$exito" \
  '[INFO] -Dinventory.expected.title=__VALOR_MANIPULADO__'
run "$f"
expect "verde con aviso" 1 "$(r2_line "$f" 2 inventory.expected.title)"
absent "verde con aviso: sin el valor" "__VALOR_MANIPULADO__"
absent "verde con aviso: sin el ok" "ok: sin esperados"

log aviso-rojo "$inicio" "$unitarias" "$(aviso inventory.expected.title)" "$fallo" "$e2e_rojo" "$rojo"
run "$f"
expect "aviso en un escenario que falla" 1 "$(r2_line "$f" 3 inventory.expected.title)"
absent "aviso en un escenario que falla: sin el valor" "__VALOR_MANIPULADO__"

log aviso-sin-tests "$inicio" "$(aviso cart.expected.count)" "$compila"
run "$f"
expect "aviso sin Tests run (el aviso va primero)" 1 "$(r2_line "$f" 2 cart.expected.count)"

log dos-claves "$inicio" "$(aviso cart.expected.count)" "$unitarias" \
  "$(aviso test.login.cases.locked-user.expected-error)" "$e2e_ok" "$exito"
run "$f"
expect "dos claves: la primera" 1 "$(r2_line "$f" 2 cart.expected.count)"
expect "dos claves: la segunda" 1 "$(r2_line "$f" 4 test.login.cases.locked-user.expected-error)"

log jenkins "$inicio" "12:01:02  $(aviso checkout.expected.confirmation)" "$e2e_ok" "$exito"
run "$f"
expect "aviso con timestamps de Jenkins" 1 "$(r2_line "$f" 2 checkout.expected.confirmation)"

f="$tmp/crlf.log"
printf '%s\r\n' "$inicio" "$(aviso cart.expected.products)" "$e2e_ok" "$exito" > "$f"
run "$f"
expect "aviso con CRLF" 1 "$(r2_line "$f" 2 cart.expected.products)"

f="$tmp/nul.log"
{ printf '%s\n' "$inicio"; printf 'basura\0binaria\n'; aviso cart.expected.count; printf '%s\n' "$e2e_ok" "$exito"; } > "$f"
run "$f"
expect "aviso tras un byte NUL (grep -a)" 1 "$(r2_line "$f" 3 cart.expected.count)"

log codificacion "$inicio" \
  "[main] WARN com.demo.utils.ConfigReader - La clave de esperado 'inventory.expected.title' viene de una propiedad del sistema (-D): solo es v?lido en el control negativo (CHK-10)" \
  "$e2e_ok" "$exito"
run "$f"
expect "aviso con el acento perdido por la codificación" 1 "$(r2_line "$f" 2 inventory.expected.title)"

log clave-rara "$inicio" "$(aviso 'x.expected$(touch PWNED)')" "$e2e_ok" "$exito"
run "$f"
expect "clave con caracteres no válidos" 1 "$(r2_line "$f" 2 "(clave no válida)")"
absent "clave con caracteres no válidos: no se repite" "PWNED"

log clave-larga "$inicio" "$(aviso "$(printf 'a%.0s' $(seq 1 201))")" "$e2e_ok" "$exito"
run "$f"
expect "clave de más de 200 caracteres" 1 "$(r2_line "$f" 2 "(clave no válida)")"

# Sin prueba de que la suite E2E corrió: 2.
log vacio
: > "$f"
run "$f"
expect "log vacío" 2 "check-no-expected-override: el log '$f' está vacío: no prueba que la suite corriera"

log compilacion "$inicio" "$compila" "[INFO] BUILD FAILURE"
run "$f"
expect "sin Tests run (fallo de compilación)" 2 "$sin_e2e"

log solo-unitarias "$inicio" "$unitarias" "$exito"
run "$f"
expect "solo las unitarias (sin RunnerTest)" 2 "$sin_e2e"

log cero "$inicio" "[INFO] Tests run: 0, Failures: 0, Errors: 0, Skipped: 0, Time elapsed: 0.5 s -- in com.demo.runners.RunnerTest" "$exito"
run "$f"
expect "RunnerTest con Tests run: 0" 2 "$sin_e2e"

log otra-clase "$inicio" "[INFO] Tests run: 5, Failures: 0, Errors: 0, Skipped: 0, Time elapsed: 0.5 s -- in com.demo.runners.RunnerTestViejo" "$exito"
run "$f"
expect "otra clase que empieza por RunnerTest" 2 "$sin_e2e"

log resumen "$inicio" "[INFO] Tests run: 22, Failures: 0, Errors: 0, Skipped: 1" "$exito"
run "$f"
expect "solo el bloque Results (sin la línea por clase)" 2 "$sin_e2e"

run
expect "sin argumentos" 2 "check-no-expected-override: uso: bash scripts/check-no-expected-override.sh <log de Maven>"
run "$tmp/verde.log" extra
expect "argumentos de más" 2 "check-no-expected-override: uso: bash scripts/check-no-expected-override.sh <log de Maven>"
run "$tmp/no-existe.log"
expect "log ausente" 2 "check-no-expected-override: no existe el log '$tmp/no-existe.log'"
mkdir -p "$tmp/dir.log"
run "$tmp/dir.log"
expect "el log es un directorio" 2 "check-no-expected-override: '$tmp/dir.log' no es un archivo regular"

if [ "$(id -u)" -ne 0 ]; then
  log ilegible "$inicio" "$e2e_ok" "$exito"
  chmod 000 "$f"
  run "$f"
  chmod 644 "$f"
  expect "log ilegible" 2 "check-no-expected-override: no se puede leer el log '$f'"
else
  table="${table}$(printf '| %-70s | %8s | %4s | %-5s |' "log ilegible (no aplica como root)" "2" "-" "n/a")"$'\n'
fi

# grep falla al leer: solo la guarda lo detecta. Shim de grep en el PATH.
real_grep="$(command -v grep)"
case "$real_grep" in
  /*) ;;
  *) echo "check-no-expected-override-test: grep no es un ejecutable con ruta absoluta" >&2; exit 2 ;;
esac
shim() {
  mkdir -p "$1"
  printf '#!/usr/bin/env bash\n%s\n' "$2" > "$1/grep"
  chmod +x "$1/grep"
}
shim "$tmp/shim-rc2" 'exit 2'
shim "$tmp/shim-stderr" 'echo "grep: error de lectura" >&2; exit 1'
for s in rc2 stderr; do
  rc=0
  out="$(PATH="$tmp/shim-$s:$PATH" bash "$script" "$tmp/verde.log" 2>&1)" || rc=$?
  expect "grep falla al leer ($s)" 2 \
    "re:^check-no-expected-override: grep terminó con [0-9]+ al leer '$tmp/verde.log'$"
done

# ------------------------------------------------------------------- resumen
printf '| %-70s | %8s | %4s | %-5s |\n' "Caso" "Esperado" "Real" "Resultado"
printf '|%s|%s|%s|%s|\n' "$(printf -- '-%.0s' $(seq 1 72))" "----------" "------" "-------"
printf '%s' "$table"
if [ "$fails" -ne 0 ]; then
  echo "check-no-expected-override-test: FALLA: $fails de $total casos no se comportan como se espera"
  exit 1
fi
echo "check-no-expected-override-test: ok: $total casos"
