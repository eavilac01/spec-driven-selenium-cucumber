#!/usr/bin/env bash
# ADR-003, R-2: un job E2E falla si su log de Maven contiene el aviso de D3.
#
# Uso: bash scripts/check-no-expected-override.sh <log de Maven>
#
# ConfigReader registra un WARN cuando una clave de esperado (*.expected*) viene
# de una propiedad del sistema (-D), una vez por clave y por JVM (ADR-003, D3):
#   La clave de esperado '<clave>' viene de una propiedad del sistema (-D): ...
# Solo es válido en el control negativo (CHK-10), que se ejecuta a mano. En CI
# significa que un esperado llegó por la línea de comandos o por el entorno
# (MAVEN_ARGS, JAVA_TOOL_OPTIONS, JDK_JAVA_OPTIONS), y la suite podría estar en
# verde comparando contra un valor manipulado.
#
# Se busca solo la parte ASCII del mensaje (sin "válido"): si el JVM escribe con
# otra codificación, la búsqueda no cambia. Se busca en cualquier parte de la
# línea, sin exigir el nivel ni el formato de slf4j-simple: falla cerrado.
#
# El log tiene que probar que la suite E2E corrió: al menos una línea de
# Surefire "Tests run: N, … -- in com.demo.runners.RunnerTest" con N >= 1. Un
# log vacío, cortado antes de las pruebas o de otra ejecución no puede dar
# verde, aunque no tenga el aviso.
#
# Salida:
#   0  sin el aviso, y la suite E2E corrió.
#   1  el log contiene el aviso; una línea por aparición, con la clave y nunca
#      un valor (el mensaje de D3 no lo incluye):
#      "<log>:<línea>: R-2: la clave de esperado '<clave>' se sobrescribió con -D …"
#      Una clave con caracteres fuera de [A-Za-z0-9._-] (o de más de 200) no se
#      repite: se informa como "(clave no válida)".
#   2  no se puede evaluar (falla cerrado): argumentos, log ausente, que no es
#      un archivo regular, ilegible o vacío, error de lectura (grep con rc >= 2
#      o con texto en stderr), o sin la línea "Tests run" de RunnerTest.
# El aviso se informa antes que la falta de "Tests run": las dos son rojo, y la
# clave es lo que hay que investigar.
#
# El texto del log es dato (Regla 03): solo se compara y se cita la clave
# validada; nunca se evalúa ni se usa para construir un comando (PI-04).
# Solo bash, coreutils, grep y sed (sin awk).
set -euo pipefail
export LC_ALL=C

me="check-no-expected-override"
err() { echo "$me: $*" >&2; exit 2; }

[ "$#" -eq 1 ] || err "uso: bash scripts/check-no-expected-override.sh <log de Maven>"
log="$1"
[ -e "$log" ] || err "no existe el log '$log'"
[ -f "$log" ] || err "'$log' no es un archivo regular"
[ -r "$log" ] || err "no se puede leer el log '$log'"
[ -s "$log" ] || err "el log '$log' está vacío: no prueba que la suite corriera"

errf="$(mktemp)"
trap 'rm -f "$errf"' EXIT

# grep_log <variable> <opciones y patrón…>: deja la salida en <variable>.
# 0 = coincide, 1 = no coincide; >= 2 o stderr = error de lectura (2).
# -a: un byte NUL en el log no lo convierte en "binario" (que ocultaría líneas).
grep_rc=0
grep_log() {
  local __var="$1" __out
  shift
  grep_rc=0
  __out="$(grep -a "$@" -- "$log" 2>"$errf")" || grep_rc=$?
  if [ "$grep_rc" -ge 2 ] || [ -s "$errf" ]; then
    cat "$errf" >&2
    err "grep terminó con $grep_rc al leer '$log'"
  fi
  printf -v "$__var" '%s' "$__out"
}

marca="La clave de esperado '[^']*' viene de una propiedad del sistema \\(-D\\)"
hits=""
grep_log hits -n -E "$marca"
if [ "$grep_rc" -eq 0 ]; then
  while IFS= read -r hit; do
    num="${hit%%:*}"
    clave="$(printf '%s\n' "${hit#*:}" \
      | sed -n "s/.*La clave de esperado '\\([^']*\\)' viene de una propiedad del sistema (-D).*/\\1/p")"
    if ! [[ "$clave" =~ ^[A-Za-z0-9._-]{1,200}$ ]]; then
      clave="(clave no válida)"
    fi
    echo "$log:$num: R-2: la clave de esperado '$clave' se sobrescribió con -D (ADR-003, D3): solo es válido en el control negativo (CHK-10), nunca en CI"
  done <<< "$hits"
  exit 1
fi

corrida=""
grep_log corrida -c -E \
  'Tests run: 0*[1-9][0-9]*, Failures: [0-9]+, Errors: [0-9]+, Skipped: [0-9]+, Time elapsed: .* -- in com\.demo\.runners\.RunnerTest([^A-Za-z0-9_$.]|$)'
if [ "$grep_rc" -ne 0 ]; then
  err "el log '$log' no tiene la línea \"Tests run: N, … -- in com.demo.runners.RunnerTest\" con N >= 1: la suite E2E no corrió o el log está incompleto"
fi

echo "$me: ok: sin esperados sobrescritos por -D en '$log' (ADR-003, R-2)"
exit 0
