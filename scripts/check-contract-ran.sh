#!/usr/bin/env bash
# CHK-20 (ADR-004, D5): las pruebas de contrato del transporte corrieron.
#
# Uso: bash scripts/check-contract-ran.sh <directorio de reportes de Surefire>
#      (en CI y en local: target/surefire-reports, después de Maven)
#
# Por cada *Test.java versionado (en el índice) bajo
# src/test/java/com/demo/contract, su reporte TEST-<clase>.xml existe en el
# directorio indicado y su elemento <testsuite> tiene tests > 0 y skipped,
# failures y errors en 0. <clase> es el nombre calificado: la ruta relativa a
# src/test/java con "/" cambiado por "." y sin ".java" (también en
# subpaquetes). Las clases se leen con git ls-files desde la raíz del
# repositorio, así que da igual desde qué directorio se invoque; la ruta de
# los reportes es relativa al directorio actual.
#
# Motivo: sin este control, un include borrado del pom.xml, un -Dtest mal
# escrito en el job e2e-firefox (Surefire no falla si otro patrón sí encuentra
# pruebas), un @Disabled o una clase renombrada dejan el job en verde sin
# ejecutar el contrato. Es el mismo fallo abierto que cubren la guarda de PIT
# (check-mutation-report.sh) y la línea "Tests run" de RunnerTest en CHK-19.
#
# Salida:
#   0  cada clase de contrato tiene su reporte con tests > 0 y sin omitidas,
#      fallos ni errores.
#   1  falla cerrado; una línea por motivo, como "<ruta>: CHK-20: <motivo>":
#      ninguna clase versionada, falta el reporte (o no es un archivo regular
#      legible), no tiene el elemento <testsuite>, le falta un atributo, un
#      valor no es un entero o no cumple.
#   2  no se puede evaluar: argumentos de menos o de más, no es un
#      repositorio git, o git ls-files terminó con rc distinto de 0 o
#      escribió en stderr (índice corrupto, configuración inválida).
#
# El contenido de los reportes es dato (Regla 03): solo se comparan enteros
# validados y nunca se repite otro texto del reporte ni se evalúa (PI-04).
# Solo bash, coreutils y git (sin awk).
set -euo pipefail
export LC_ALL=C

me="check-contract-ran"
err() { echo "$me: $*" >&2; exit 2; }
uso="uso: bash scripts/check-contract-ran.sh <directorio de reportes de Surefire>"

[ "$#" -eq 1 ] || err "$uso"
reportes="$1"
[ -n "$reportes" ] || err "$uso"

CT=src/test/java/com/demo/contract
# Las expresiones van en variables: sin comillas a la derecha de =~, y sin
# "\<" ni "\>", que en las regex de GNU son límites de palabra.
SUITE_RE='<testsuite[[:space:]]([^>]*)>'
RAIZ_JAVA=src/test/java/

top="$(git rev-parse --show-toplevel 2>/dev/null)" || err "no es un repositorio git"

errf="$(mktemp)"
trap 'rm -f "$errf"' EXIT

# Clases versionadas: -z para que ninguna ruta se interprete; rc distinto de 0
# o texto en stderr es un error (2), nunca "sin clases".
rc=0
listado="$(git -C "$top" ls-files -z -- "$CT" 2>"$errf" | tr '\0' '\n')" || rc=$?
if [ "$rc" -ne 0 ] || [ -s "$errf" ]; then
  cat "$errf" >&2
  err "git ls-files terminó con $rc"
fi

clases=()
while IFS= read -r ruta; do
  case "$ruta" in
    "$CT"/*Test.java) clases+=("$ruta") ;;
  esac
done <<< "$listado"

if [ "${#clases[@]}" -eq 0 ]; then
  echo "$CT: CHK-20: ningún *Test.java versionado en contract"
  exit 1
fi

status=0
falla() {
  echo "$1: CHK-20: $2"
  status=1
}

# evaluar <ruta>: compara el reporte de una clase. Sin aritmética: el valor se
# valida como dígitos y se compara como texto (cero = solo ceros), así que no
# hay base octal ni desbordamiento.
evaluar() {
  local ruta="$1" clase reporte contenido cabecera atributo atributo_re valor
  clase="${ruta#"$RAIZ_JAVA"}"
  clase="${clase%.java}"
  clase="${clase//\//.}"
  reporte="$reportes/TEST-$clase.xml"
  if [ ! -f "$reporte" ] || [ ! -r "$reporte" ]; then
    falla "$reporte" "falta el reporte de Surefire de $clase"
    return 0
  fi
  contenido="$(cat -- "$reporte")" || { falla "$reporte" "no se pudo leer el reporte de $clase"; return 0; }
  # Primer elemento <testsuite …> (no <testsuites>), hasta su ">".
  if [[ ! "$contenido" =~ $SUITE_RE ]]; then
    falla "$reporte" "sin el elemento <testsuite> de $clase"
    return 0
  fi
  cabecera=" ${BASH_REMATCH[1]}"
  for atributo in tests skipped failures errors; do
    atributo_re="[[:space:]]$atributo=\"([^\"]*)\""
    if [[ ! "$cabecera" =~ $atributo_re ]]; then
      falla "$reporte" "falta el atributo $atributo en <testsuite> de $clase"
      continue
    fi
    valor="${BASH_REMATCH[1]}"
    if [[ ! "$valor" =~ ^[0-9]{1,9}$ ]]; then
      falla "$reporte" "el atributo $atributo de $clase no es un entero"
      continue
    fi
    if [ "$atributo" = tests ]; then
      if [[ "$valor" =~ ^0+$ ]]; then
        falla "$reporte" "tests=0: no se ejecutó ninguna prueba de $clase"
      fi
    elif [[ ! "$valor" =~ ^0+$ ]]; then
      falla "$reporte" "$atributo=$valor en $clase"
    fi
  done
}

# Cada clase evaluada se cuenta después de evaluar: si bash abandonara el lazo
# por un error de expansión (vuelve al nivel superior sin pasar por set -e),
# el recuento no cuadra y el resultado es 2, nunca un verde.
evaluadas=0
for ruta in "${clases[@]}"; do
  evaluar "$ruta"
  evaluadas=$((evaluadas + 1))
done
if [ "$evaluadas" -ne "${#clases[@]}" ]; then
  err "solo se evaluaron $evaluadas de ${#clases[@]} clases"
fi

if [ "$status" -eq 0 ]; then
  echo "$me: ok: ${#clases[@]} clase(s) de contrato con su reporte en '$reportes' (CHK-20)"
fi
exit "$status"
