#!/usr/bin/env bash
# Autoprueba de scripts/check-no-expected-override.sh (CHK-19; ADR-003, R-2 y D6).
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
# D6 (destinos de red): los logs en verde llevan las líneas de base.url y
# remote.url; los casos D6-* cubren la fuente esperada con y sin
# --destino-d, la validez de la línea sin repetir su contenido, el orden
# (violaciones, Tests run, presencia), la búsqueda con grep -a y por grep_log,
# y el uso de la bandera.
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
# D6: línea de destino de red de ConfigReader (INFO de slf4j-simple).
destino() {
  printf "[ForkJoinPool-1-worker-1] INFO com.demo.utils.ConfigReader - Destino de red '%s': fuente=%s, host=%s\n" "$1" "$2" "$3"
}
base_ok="$(destino base.url archivo www.saucedemo.com)"
remote_ok="$(destino remote.url archivo '(ninguno)')"
remote_grid="$(destino remote.url sistema localhost:4444)"
base_sistema="$(destino base.url sistema www.saucedemo.com)"

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

ok_line() { echo "check-no-expected-override: ok: sin esperados sobrescritos por -D y con los destinos de red esperados en '$1' (ADR-003, R-2 y D6)"; }
uso_line="check-no-expected-override: uso: bash scripts/check-no-expected-override.sh [--destino-d <clave>=<host>]... <log de Maven>"
# d6_line <log> <línea> <clave> <fuente> <host> <esperado>
d6_line() { echo "$1:$2: D6: el destino de red '$3' tiene fuente=$4 y host=$5; en este job se espera $6 (ADR-003, D6)"; }
d6_invalida() { echo "$1:$2: D6: línea de destino de red no válida (ADR-003, D6)"; }
d6_falta() { echo "check-no-expected-override: el log '$1' no registra el destino de red '$2' (ADR-003, D6): no prueba adónde fue la suite"; }
SIN_D="fuente=archivo o ausente"
GRID_D="fuente=sistema y host=localhost:4444"
r2_line() { echo "$1:$2: R-2: la clave de esperado '$3' se sobrescribió con -D (ADR-003, D3): solo es válido en el control negativo (CHK-10), nunca en CI"; }
sin_e2e='re:^check-no-expected-override: el log .* no tiene la línea "Tests run: N, … -- in com\.demo\.runners\.RunnerTest" con N >= 1'

# ------------------------------------------------------------------- casos
# Sin aviso: 0 (el rc de Maven lo evalúa el job, no este control).
log verde "$inicio" "$base_ok" "$remote_ok" "$unitarias" "$e2e_ok" "$exito"
run "$f"
expect "verde sin aviso" 0 "$(ok_line "$f")"

log rojo "$inicio" "$base_ok" "$remote_ok" "$unitarias" "$fallo" "$e2e_rojo" "$rojo"
run "$f"
expect "escenario en rojo sin aviso" 0 "$(ok_line "$f")"

f="$tmp/verde-crlf.log"
printf '%s\r\n' "$inicio" "$base_ok" "$remote_ok" "$unitarias" "$e2e_ok" "$exito" > "$f"
run "$f"
expect "verde sin aviso con CRLF" 0 "$(ok_line "$f")"

log casi "$inicio" "$base_ok" "$remote_ok" \
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
expect "sin argumentos" 2 "$uso_line"
run "$tmp/verde.log" extra
expect "argumentos de más" 2 "$uso_line"
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

# ---------------------------------------------- D6: destinos de red (ADR-003)
# Permitidos: 0.
log d6-ok-ausente "$inicio" "$base_ok" "$(destino remote.url ausente '(ninguno)')" "$e2e_ok" "$exito"
run "$f"
expect "D6-ok-ausente: ausente está permitido" 0 "$(ok_line "$f")"

log d6-ok-grid "$inicio" "$base_ok" "$remote_grid" "$e2e_ok" "$exito"
run --destino-d remote.url=localhost:4444 "$f"
expect "D6-ok-grid: la expectativa de e2e-grid" 0 "$(ok_line "$f")"

log d6-ok-jenkins "$inicio" "12:01:02  $base_ok" "12:01:02  $remote_ok" "$e2e_ok" "$exito"
run "$f"
expect "D6-ok-jenkins: marca sin ancla de inicio" 0 "$(ok_line "$f")"

log d6-ok-dos-jvm "$inicio" "$base_ok" "$remote_ok" "$base_ok" "$remote_ok" "$e2e_ok" "$exito"
run "$f"
expect "D6-ok-dos-jvm: varias líneas por clave" 0 "$(ok_line "$f")"

log d6-ok-casi "$inicio" "$base_ok" "$remote_ok" \
  "[ForkJoinPool-1-worker-1] INFO com.demo.utils.ConfigReader - Destino de red base.url: fuente=sistema, host=otro.example" \
  "[ForkJoinPool-1-worker-1] INFO com.demo.utils.ConfigReader - destino de red 'base.url': fuente=sistema, host=otro.example" \
  "$e2e_ok" "$exito"
run "$f"
expect "D6-ok-casi: la marca es exacta y distingue mayúsculas" 0 "$(ok_line "$f")"

f="$tmp/d6-ok-nul.log"
{ printf '%s\n' "$inicio"; printf 'basura\0binaria\n'; printf '%s\n' "$base_ok" "$remote_ok" "$e2e_ok" "$exito"; } > "$f"
run "$f"
expect "D6-ok-nul: la búsqueda nueva usa grep -a" 0 "$(ok_line "$f")"

# Violaciones de fuente u host: 1, con la clave, la fuente y el host validados.
log d6-base-sistema "$inicio" "$base_sistema" "$remote_ok" "$e2e_ok" "$exito"
run "$f"
expect "D6-base-sistema: base.url por -D" 1 "$(d6_line "$f" 2 base.url sistema www.saucedemo.com "$SIN_D")"

log d6-remote-sistema "$inicio" "$base_ok" "$remote_grid" "$e2e_ok" "$exito"
run "$f"
expect "D6-remote-sistema: -D sin bandera" 1 "$(d6_line "$f" 3 remote.url sistema localhost:4444 "$SIN_D")"

log d6-entorno "$inicio" "$base_ok" "$(destino remote.url entorno '(ninguno)')" "$e2e_ok" "$exito"
run "$f"
expect "D6-entorno: entorno nunca se acepta" 1 "$(d6_line "$f" 3 remote.url entorno '(ninguno)' "$SIN_D")"

log d6-grid-host "$inicio" "$base_ok" "$(destino remote.url sistema otro.example:4444)" "$e2e_ok" "$exito"
run --destino-d remote.url=localhost:4444 "$f"
expect "D6-grid-host: el host se compara" 1 "$(d6_line "$f" 3 remote.url sistema otro.example:4444 "$GRID_D")"

log d6-grid-prefijo "$inicio" "$base_ok" "$(destino remote.url sistema localhost:44445)" "$e2e_ok" "$exito"
run --destino-d remote.url=localhost:4444 "$f"
expect "D6-grid-prefijo: comparación exacta, no por prefijo" 1 "$(d6_line "$f" 3 remote.url sistema localhost:44445 "$GRID_D")"

log d6-grid-archivo "$inicio" "$base_ok" "$remote_ok" "$e2e_ok" "$exito"
run --destino-d remote.url=localhost:4444 "$f"
expect "D6-grid-archivo: e2e-grid sin Grid es rojo" 1 "$(d6_line "$f" 3 remote.url archivo '(ninguno)' "$GRID_D")"

log d6-grid-base "$inicio" "$base_sistema" "$remote_grid" "$e2e_ok" "$exito"
run --destino-d remote.url=localhost:4444 "$f"
expect "D6-grid-base: la bandera vale solo para su clave" 1 "$(d6_line "$f" 2 base.url sistema www.saucedemo.com "$SIN_D")"

log d6-mixta "$inicio" "$base_ok" "$remote_ok" "$(destino base.url sistema otro.example)" "$e2e_ok" "$exito"
run "$f"
expect "D6-mixta: se evalúan todas las líneas" 1 "$(d6_line "$f" 4 base.url sistema otro.example "$SIN_D")"

# Líneas no válidas: 1, sin repetir el contenido.
log d6-no-valida-fuente "$inicio" "$base_ok" "$remote_ok" "$(destino base.url desconocida x.example)" "$e2e_ok" "$exito"
run "$f"
expect "D6-no-valida-fuente: LINEA estricta" 1 "$(d6_invalida "$f" 4)"
absent "D6-no-valida-fuente: no repite el contenido" "desconocida"

log d6-no-valida-pi09 "$inicio" "$base_ok" "$remote_ok" "$(destino remote.url sistema usuario:clave@hub.example)" "$e2e_ok" "$exito"
run "$f"
expect "D6-no-valida-secreto: host con usuario y clave (PI-09)" 1 "$(d6_invalida "$f" 4)"
absent "D6-no-valida-secreto: no repite la clave" "clave"

log d6-no-valida-pi04 "$inicio" "$base_ok" "$remote_ok" "$(destino 'x$(touch PWNED)' archivo x.example)" "$e2e_ok" "$exito"
run "$f"
expect "D6-no-valida-inyeccion: clave con caracteres no válidos (PI-04)" 1 "$(d6_invalida "$f" 4)"
absent "D6-no-valida-inyeccion: no repite el contenido" "PWNED"

log d6-no-valida-sufijo "$inicio" "$base_ok" "$remote_ok" "$(destino base.url archivo 'www.saucedemo.com extra')" "$e2e_ok" "$exito"
run "$f"
expect "D6-no-valida-sufijo: ancla final" 1 "$(d6_invalida "$f" 4)"

# Orden: las violaciones van juntas y antes de la evaluabilidad.
log d6-y-d3 "$inicio" "$(aviso inventory.expected.title)" "$base_sistema" "$remote_ok" "$e2e_ok" "$exito"
run "$f"
expect "D6-y-D3: el aviso de D3" 1 "$(r2_line "$f" 2 inventory.expected.title)"
expect "D6-y-D3: la violación de D6" 1 "$(d6_line "$f" 3 base.url sistema www.saucedemo.com "$SIN_D")"

log d6-sin-tests "$inicio" "$base_sistema" "$remote_ok" "$compila"
run "$f"
expect "D6-sin-tests: las violaciones van antes que la evaluabilidad" 1 "$(d6_line "$f" 2 base.url sistema www.saucedemo.com "$SIN_D")"

# Presencia: 2, una línea por clave que falta.
log d6-sin-base "$inicio" "$remote_ok" "$e2e_ok" "$exito"
run "$f"
expect "D6-sin-base: falta base.url" 2 "$(d6_falta "$f" base.url)"

log d6-sin-remote "$inicio" "$base_ok" "$e2e_ok" "$exito"
run "$f"
expect "D6-sin-remote: falta remote.url" 2 "$(d6_falta "$f" remote.url)"

log d6-sin-destinos "$inicio" "$unitarias" "$e2e_ok" "$exito"
run "$f"
expect "D6-sin-destinos: nivel de log o salida redirigida" 2 "$(d6_falta "$f" base.url)"

# La búsqueda nueva pasa por grep_log: un shim de grep que sale con 2 solo si
# un argumento contiene la marca de D6 (si no, delega en el grep real).
shim "$tmp/shim-d6" "for a in \"\$@\"; do case \"\$a\" in *'Destino de red'*) exit 2 ;; esac; done; exec $(printf '%q' "$real_grep") \"\$@\""
rc=0
out="$(PATH="$tmp/shim-d6:$PATH" bash "$script" "$tmp/verde.log" 2>&1)" || rc=$?
expect "D6-error-grep: la búsqueda nueva pasa por grep_log" 2 \
  "re:^check-no-expected-override: grep terminó con 2 al leer '$tmp/verde.log'$"

# Uso de --destino-d: 2.
run --destino-d
expect "D6-uso-sin-valor" 2 "$uso_line"
run --destino-d remote.url "$tmp/verde.log"
expect "D6-uso-sin-igual" 2 "$uso_line"
run --destino-d 'remote.url=localhost:4444;x' "$tmp/verde.log"
expect "D6-uso-host" 2 "$uso_line"
run --destino-d 'remote.url=(ninguno)' "$tmp/verde.log"
expect "D6-uso-token" 2 "$uso_line"
run --destino-d remote.url=localhost:4444 --destino-d remote.url=localhost:4445 "$tmp/verde.log"
expect "D6-uso-repetida" 2 "$uso_line"
run --otra "$tmp/verde.log"
expect "D6-uso-otra" 2 "$uso_line"
run "$tmp/verde.log" --destino-d remote.url=localhost:4444
expect "D6-uso-despues" 2 "$uso_line"

# ------------------------------------------------------------------- resumen
printf '| %-70s | %8s | %4s | %-5s |\n' "Caso" "Esperado" "Real" "Resultado"
printf '|%s|%s|%s|%s|\n' "$(printf -- '-%.0s' $(seq 1 72))" "----------" "------" "-------"
printf '%s' "$table"
if [ "$fails" -ne 0 ]; then
  echo "check-no-expected-override-test: FALLA: $fails de $total casos no se comportan como se espera"
  exit 1
fi
echo "check-no-expected-override-test: ok: $total casos"
