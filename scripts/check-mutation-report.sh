#!/usr/bin/env bash
# CHK-11 — Guarda contra el fallo abierto de PIT (ADR-001, D5 y Enmiendas).
#
# Uso: bash scripts/check-mutation-report.sh <log-de-pit> [raíz]   (raíz por defecto: .)
#      La ruta del log es relativa al directorio actual, no a la raíz.
#
# PIT 1.30.0, sin target/classes, imprime "Skipping project" y termina en
# BUILD SUCCESS. Este script se ejecuta después de PIT (que ya falló si el
# puntaje quedó bajo el umbral) y exige que el reporte exista y sea de esa
# ejecución. Sale con 1 y un mensaje de una línea si:
#   (b) el log contiene "Skipping project";
#   (e) la raíz no tiene src/main/java con al menos un .java (falla cerrada:
#       una raíz equivocada o el retiro de src/main no deben dar verde; retirar
#       el código mutable exige una enmienda del ADR-001 que retire el job);
#   (a) falta target/pit-reports/mutations.xml;
#   (c) mutations.xml no tiene ninguna mutación;
#   (d) mutations.xml está truncado, o el log no tiene el resumen de PIT
#       ("Generated N mutations"), o N no coincide con las mutaciones del
#       reporte (reporte de otra ejecución).
# Sale con 0 si todo está en orden y con 2 ante un error de uso.
# Solo bash, coreutils, find, grep y awk POSIX (compatible con mawk y gawk).
# El log y el reporte son datos: solo se cuentan y se buscan literales.
set -euo pipefail
export LC_ALL=C

me="check-mutation-report"

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "$me: uso: bash scripts/check-mutation-report.sh <log-de-pit> [raíz]" >&2
  exit 2
fi
log="$1"
root="${2:-.}"

if [ ! -f "$log" ] || [ ! -r "$log" ]; then
  echo "$me: el log '$log' no existe o no se puede leer" >&2
  exit 2
fi
if [ ! -d "$root" ]; then
  echo "$me: la raíz '$root' no es un directorio" >&2
  exit 2
fi

report="$root/target/pit-reports/mutations.xml"

fail() {
  echo "$me: FALLA ($1): $2"
  exit 1
}

# (b) PIT omitió el proyecto: BUILD SUCCESS sin haber mutado nada.
if grep -qF "Skipping project" "$log"; then
  fail "b" "el log de PIT contiene 'Skipping project' (no se mutó nada)"
fi

# (e) Sin código mutable no hay CHK-11 que aprobar.
main_java=""
if [ -d "$root/src/main/java" ]; then
  main_java="$(find "$root/src/main/java" -type f -name '*.java' ! -name '._*' -print -quit)"
fi
if [ -z "$main_java" ]; then
  fail "e" "no hay ningún .java en $root/src/main/java; retirar el código mutable exige enmendar el ADR-001"
fi

# (a) Existe código mutable y falta el reporte.
if [ ! -f "$report" ]; then
  fail "a" "existe src/main/java con código y falta $report"
fi

# (c) Reporte sin mutaciones. Se cuentan las etiquetas <mutation ...>
# (no <mutations>); los atributos usan comillas simples y no se interpretan.
count="$(awk '{ n += gsub(/<mutation[ \t>]/, "") } END { print n + 0 }' "$report")"
if [ "$count" -eq 0 ]; then
  fail "c" "$report no contiene ninguna mutación"
fi

# (d) Reporte completo y de esta ejecución.
if ! grep -qF "</mutations>" "$report"; then
  fail "d" "$report está truncado (falta </mutations>)"
fi
generated="$(awk '
  /Generated [0-9]+ mutations/ {
    s = $0
    sub(/.*Generated /, "", s)
    sub(/ mutations.*/, "", s)
    if (s ~ /^[0-9]+$/) { last = s }
  }
  END { print last }
' "$log")"
if [ -z "$generated" ]; then
  fail "d" "el log no contiene el resumen 'Generated N mutations' de PIT"
fi
if [ "$generated" -ne "$count" ]; then
  fail "d" "el log dice $generated mutaciones y $report tiene $count (reporte de otra ejecución)"
fi

echo "$me: ok: $count mutaciones en $report, coinciden con el log"
exit 0
