#!/usr/bin/env bash
# Autoprueba de CHK-14 (scripts/check-quarantine.sh; Regla 04).
#
# Uso: bash scripts/tests/check-quarantine-test.sh
#
# Cada caso crea en un temporal fuera del repositorio (mktemp -d) un árbol
# mínimo (features, docs/quarantine.md y una spec) y exige el código de salida
# y la salida estándar EXACTA (rc 0 y 1), o el mensaje de error esperado en
# stderr (rc 2). Con rc 0 y 1, stderr debe quedar vacío. Así un mensaje
# equivocado, una línea de más o de menos, o una regla anulada hacen fallar
# al menos un caso, no solo un rc distinto.
#
# Las fechas son deterministas: CHK14_TODAY=2026-10-10 salvo en los casos que
# prueban otra fecha o la fecha del sistema.
#
# check-quarantine.sh no invoca git (lee el árbol de trabajo con find, como
# CHK-12 y como Cucumber). Por eso los árboles temporales no son repositorios y
# no hay commits ni mantenimiento automático que aislar. Aun así, git queda
# aislado de la configuración del usuario por si una versión futura del script
# lo usara.
#
# Sale con 0 solo si todos los casos se comportan como se espera; con 1 si
# alguno falla; con 2 ante un error de preparación. Imprime la tabla
# caso → esperado → real. El temporal se borra al salir (trap).
set -euo pipefail
export LC_ALL=C

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
script="$here/../check-quarantine.sh"
repo_root="$(cd "$here/../.." && pwd -P)"
if [ ! -f "$script" ]; then
  echo "check-quarantine-test: no existe $script" >&2
  exit 2
fi

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_CONFIG_PARAMETERS CHK14_TODAY
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_COUNT=4
export GIT_CONFIG_KEY_0=maintenance.auto GIT_CONFIG_VALUE_0=false
export GIT_CONFIG_KEY_1=gc.auto GIT_CONFIG_VALUE_1=0
export GIT_CONFIG_KEY_2=maintenance.autoDetach GIT_CONFIG_VALUE_2=false
export GIT_CONFIG_KEY_3=gc.autoDetach GIT_CONFIG_VALUE_3=false

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
tmp="$(cd "$tmp" && pwd -P)"
case "$tmp/" in
  "$repo_root"/*)
    echo "check-quarantine-test: el temporal $tmp está dentro del repositorio" >&2
    exit 2
    ;;
esac
export GIT_CEILING_DIRECTORIES="$tmp"

TODAY=2026-10-10
F=src/test/resources/features
Q=docs/quarantine.md
HI='| Tipo | Escenario | Dueño | Ingreso | Límite | Issue | Diagnóstico |'
SI='|---|---|---|---|---|---|---|'
HD='| Tipo | Escenario | Dueño | Ingreso | Referencia | Esperado | Observado | Próxima revisión |'
SD='|---|---|---|---|---|---|---|---|'

# ------------------------------------------------------------------ fixtures
n_case=0
# new: crea un árbol vacío (features y una spec) y deja su ruta en $d.
new() {
  n_case=$((n_case + 1))
  d="$tmp/c$n_case"
  mkdir -p "$d/$F" "$d/docs/specs"
  printf '%s\n' '# Spec de compra' '| Estado | aprobada |' > "$d/docs/specs/compra.md"
}

# feat <archivo> <líneas…>: escribe una feature en $d.
feat() {
  local path="$d/$F/$1"
  shift
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$@" > "$path"
}

# raw <líneas…>: escribe docs/quarantine.md tal cual en $d.
raw() { printf '%s\n' "$@" > "$d/$Q"; }

# reg <filas…>: escribe docs/quarantine.md con el formato del repositorio. Las
# filas que empiezan por "| inestable" van a la primera tabla; el resto, a la
# segunda. Incluye tablas con columnas Tipo y Escenario FUERA de "## Registro"
# (antes y después), que el script debe ignorar.
# Numeración: las filas de la primera tabla empiezan en la línea 15; con k
# filas en ella, las de la segunda empiezan en la línea 20 + k.
reg() {
  local r ri=() rd=()
  for r in "$@"; do
    case "$r" in
      "| inestable "*) ri+=("$r") ;;
      *) rd+=("$r") ;;
    esac
  done
  {
    printf '%s\n' '# Cuarentena' '' '## Tipos' '' \
      '| Tipo | Escenario | Nota |' '|---|---|---|' \
      '| inestable | `@AC-ZZZ-99` | ejemplo fuera del registro |' '' \
      '## Registro' '' '### `inestable`' '' "$HI" "$SI"
    [ "${#ri[@]}" -eq 0 ] || printf '%s\n' "${ri[@]}"
    printf '%s\n' '' '### `defecto-sut`' '' "$HD" "$SD"
    [ "${#rd[@]}" -eq 0 ] || printf '%s\n' "${rd[@]}"
    printf '%s\n' '' '## Historial' '' "$HD" "$SD" \
      '| defecto-sut | `@AC-ZZZ-98` | Ana | 2020-01-01 | `docs/specs/nada.md` | a | b | 2020-01-02 |'
  } > "$d/$Q"
}

# Filas: <AC> <ingreso> <límite o revisión>
ri() { printf '| inestable | `%s` | Ana | %s | %s | #12 | Espera insuficiente tras la navegación |' "$1" "$2" "$3"; }
rd() { printf '| defecto-sut | `%s` | Ana | %s | `docs/specs/compra.md`, sección "Defecto conocido" | No avanza | Avanza sin mensaje | %s |' "$1" "$2" "$3"; }

# Feature con un escenario normal (línea 6) y uno en cuarentena (línea 10).
feat_q() {
  feat compra.feature \
    'Feature: Compra' \
    '' \
    '  Spec: docs/specs/compra.md' \
    '' \
    '  @AC-COMPRA-01 @tec-equivalencia' \
    '  Scenario: Compra normal' \
    '    Given algo' \
    '' \
    "  @e2e @quarantine ${1:-@AC-COMPRA-09} @tec-estados" \
    '  Scenario: Compra en cuarentena' \
    '    Given algo'
}
# Feature sin ningún @quarantine.
feat_plain() {
  feat compra.feature \
    'Feature: Compra' \
    '' \
    '  Spec: docs/specs/compra.md' \
    '' \
    '  @AC-COMPRA-01 @AC-COMPRA-09 @tec-equivalencia' \
    '  Scenario: Compra normal' \
    '    Given algo'
}

# ------------------------------------------------------------------ ejecución
fails=0
rows=()
lines() { printf '%s\n' "$@"; }

# expect <caso> <rc> <stdout exacto> <subcadena de stderr o ""> -- <comando…>
expect() {
  local name="$1" exp_rc="$2" exp_out="$3" exp_err="$4"
  shift 5
  local out err rc=0 ok=1 why=""
  out="$("$@" 2>"$tmp/stderr")" || rc=$?
  err="$(cat "$tmp/stderr")"
  if [ "$rc" -ne "$exp_rc" ]; then ok=0; why="rc $rc"; fi
  if [ "$out" != "$exp_out" ]; then ok=0; why="${why:+$why, }stdout distinto"; fi
  if [ -z "$exp_err" ]; then
    [ -z "$err" ] || { ok=0; why="${why:+$why, }stderr inesperado"; }
  else
    case "$err" in
      *"$exp_err"*) ;;
      *) ok=0; why="${why:+$why, }stderr sin el mensaje esperado" ;;
    esac
  fi
  if [ "$ok" -eq 1 ]; then
    rows+=("$(printf '%-62s | %s | %s | ok' "$name" "$exp_rc" "$rc")")
  else
    fails=$((fails + 1))
    rows+=("$(printf '%-62s | %s | %s | FALLA (%s)' "$name" "$exp_rc" "$rc" "$why")")
    {
      echo "--- $name"
      echo "esperado:"; printf '%s\n' "$exp_out"
      echo "real:"; printf '%s\n' "$out"
      [ -z "$err" ] || { echo "stderr:"; printf '%s\n' "$err"; }
    } >> "$tmp/detalle"
  fi
}

# chk: ejecuta el script sobre $d con la fecha fija.
chk() { env CHK14_TODAY="$TODAY" bash "$script" "$d"; }

L_FILA="docs/quarantine.md"
L_FEAT="src/test/resources/features/compra.feature"

# ------------------------------------------------------------------ válidos
new; feat_q; reg "$(ri @AC-COMPRA-09 2026-10-05 2026-10-12)"
expect "válido: inestable" 0 "" "" -- chk

new; feat_q; reg "$(rd @AC-COMPRA-09 2026-10-10 2026-12-31)"
expect "válido: defecto-sut" 0 "" "" -- chk

new
feat_q
feat otra.feature 'Feature: Otra' '' '  @quarantine @AC-LOGIN-02 @tec-x' '  Scenario: Otra' '    Given algo'
reg "$(ri @AC-LOGIN-02 2026-10-10 2026-10-10)" "$(rd @AC-COMPRA-09 2026-10-01 2026-10-30)"
expect "válido: ambos tipos en dos features" 0 "" "" -- chk

new; feat_q; reg "$(ri @AC-COMPRA-09 2026-10-05 2026-10-12)"
expect "válido: raíz por defecto (.)" 0 "" "" -- \
  env CHK14_TODAY="$TODAY" bash -c 'cd "$1" && bash "$2"' _ "$d" "$script"

new; feat_q; reg "$(ri @AC-COMPRA-09 2026-10-05 2026-10-12)"
mkdir -p "$d/$F/a/b/c/d/e"; mv "$d/$F/compra.feature" "$d/$F/a/b/c/d/e/"
expect "válido: feature a 6 niveles de profundidad" 0 "" "" -- chk

new; feat_q; reg "$(rd @AC-COMPRA-09 2026-10-10 2026-12-31)"
sed -i 's/$/\r/' "$d/$Q" "$d/$F/compra.feature"
expect "válido: fin de línea CRLF" 0 "" "" -- chk

new; feat_plain; reg
expect "válido: registro vacío y sin @quarantine" 0 "" "" -- chk

# ------------------------------------------------------------------ archivo ausente
new; feat_plain
expect "archivo ausente sin @quarantine (0: nada que registrar)" 0 "" "" -- chk

new; feat_q
expect "archivo ausente con @quarantine" 1 \
  "$L_FEAT:10: unidad con @quarantine sin fila en docs/quarantine.md: @AC-COMPRA-09 (archivo ausente)" "" -- chk

new
expect "sin features ni archivo" 0 "" "" -- chk

# ------------------------------------------------------------------ cruce
new; feat_plain; reg "$(rd @AC-COMPRA-09 2026-10-10 2026-12-31)"
expect "fila sin escenario" 1 \
  "$L_FILA:20: fila de @AC-COMPRA-09 sin escenario con @quarantine" "" -- chk

new; feat_q; reg "$(rd @AC-COMPRA-10 2026-10-10 2026-12-31)"
expect "escenario sin fila (y fila de otro AC)" 1 "$(lines \
  "$L_FILA:20: fila de @AC-COMPRA-10 sin escenario con @quarantine" \
  "$L_FEAT:10: unidad con @quarantine sin fila en docs/quarantine.md: @AC-COMPRA-09")" "" -- chk

new; feat_q; reg "$(ri @AC-COMPRA-09 2026-10-05 2026-10-12)" "$(rd @AC-COMPRA-09 2026-10-10 2026-12-31)"
expect "dos filas para el mismo AC" 1 \
  "$L_FILA:21: más de una fila para @AC-COMPRA-09 (la primera en la línea 15)" "" -- chk

new; feat_q '@AC-COMPRA-09 @AC-COMPRA-10'; reg "$(rd @AC-COMPRA-09 2026-10-10 2026-12-31)"
expect "unidad con dos AC y fila para uno solo" 1 \
  "$L_FEAT:10: unidad con @quarantine sin fila en docs/quarantine.md: @AC-COMPRA-10" "" -- chk

new; feat_q '@AC-COMPRA-09 @AC-COMPRA-10'
reg "$(rd @AC-COMPRA-09 2026-10-10 2026-12-31)" "$(rd @AC-COMPRA-10 2026-10-10 2026-12-31)"
expect "unidad con dos AC y una fila por AC" 0 "" "" -- chk

new; feat_q '@AC-compra-09'; reg
expect "unidad con @quarantine sin @AC- válido" 1 \
  "$L_FEAT:10: unidad con @quarantine sin @AC-<DOMINIO>-<NN>: no se puede identificar su fila en docs/quarantine.md" "" -- chk

new; feat_q; reg '| defecto-sut | `@AC-COMPRA-09 @AC-COMPRA-10` | Ana | 2026-10-10 | `docs/specs/compra.md` | a | b | 2026-12-31 |'
expect "Escenario con dos etiquetas en la fila" 1 "$(lines \
  "$L_FILA:20: Escenario debe ser una sola etiqueta @AC-<DOMINIO>-<NN>" \
  "$L_FEAT:10: unidad con @quarantine sin fila en docs/quarantine.md: @AC-COMPRA-09")" "" -- chk

# ------------------------------------------------------------------ herencia
new
feat compra.feature \
  '@quarantine @AC-COMPRA-09' \
  'Feature: Compra' \
  '' \
  '  @tec-estados' \
  '  Scenario: Uno' \
  '    Given algo' \
  '' \
  '  @tec-frontera' \
  '  Scenario: Dos' \
  '    Given algo'
reg
expect "tag heredado de la Feature, sin fila" 1 "$(lines \
  "$L_FEAT:5: unidad con @quarantine sin fila en docs/quarantine.md: @AC-COMPRA-09" \
  "$L_FEAT:9: unidad con @quarantine sin fila en docs/quarantine.md: @AC-COMPRA-09")" "" -- chk
reg "$(rd @AC-COMPRA-09 2026-10-10 2026-12-31)"
expect "tag heredado de la Feature, con una fila compartida" 0 "" "" -- chk

new
feat compra.feature \
  'Feature: Compra' \
  '' \
  '  @quarantine' \
  '  Rule: Carrito' \
  '' \
  '    @AC-COMPRA-09 @tec-estados' \
  '    Scenario: Bajo la regla' \
  '      Given algo' \
  '' \
  '  Rule: Envío' \
  '' \
  '    @AC-COMPRA-10 @tec-x' \
  '    Scenario: Fuera de la cuarentena' \
  '      Given algo'
reg
expect "tag heredado de la Rule (solo esa Rule)" 1 \
  "$L_FEAT:7: unidad con @quarantine sin fila en docs/quarantine.md: @AC-COMPRA-09" "" -- chk

# ------------------------------------------------------------------ Examples
outline() {
  feat compra.feature \
    'Feature: Compra' \
    '' \
    "  @AC-COMPRA-10 @tec-equivalencia $1" \
    '  Scenario Outline: Envío incompleto' \
    '    Given <dato>' \
    '' \
    "    $2" \
    '    Examples: Nombre' \
    '      | dato |' \
    '      | a    |' \
    '' \
    "    $3" \
    '    Examples: Apellido' \
    '      | dato |' \
    '      | b    |'
}
new; outline '' '' '@quarantine'; reg
expect "@quarantine en un bloque Examples, sin fila" 1 \
  "$L_FEAT:13: unidad con @quarantine sin fila en docs/quarantine.md: @AC-COMPRA-10" "" -- chk
reg "$(ri @AC-COMPRA-10 2026-10-05 2026-10-12)"
expect "@quarantine en un bloque Examples, con fila" 0 "" "" -- chk

new; outline '' '@quarantine @AC-COMPRA-11' ''; reg "$(ri @AC-COMPRA-10 2026-10-05 2026-10-12)"
# El bloque hereda AC-COMPRA-10 del Outline y suma AC-COMPRA-11: la fila de
# AC-COMPRA-10 lo cubre en parte y falta la de AC-COMPRA-11. El segundo bloque
# no está en cuarentena.
expect "Examples en cuarentena con AC propio y heredado" 1 \
  "$L_FEAT:8: unidad con @quarantine sin fila en docs/quarantine.md: @AC-COMPRA-11" "" -- chk

new; outline '@quarantine' '' ''; reg
expect "@quarantine en el Outline: cada Examples es una unidad" 1 "$(lines \
  "$L_FEAT:8: unidad con @quarantine sin fila en docs/quarantine.md: @AC-COMPRA-10" \
  "$L_FEAT:13: unidad con @quarantine sin fila en docs/quarantine.md: @AC-COMPRA-10")" "" -- chk

new
feat compra.feature \
  '@quarantine' \
  'Feature: Compra' \
  '' \
  '  @AC-COMPRA-10 @tec-x' \
  '  Scenario Outline: Hereda de la Feature' \
  '    Given <dato>' \
  '' \
  '    Examples:' \
  '      | dato |' \
  '      | a    |'
reg
expect "Examples que hereda @quarantine de la Feature" 1 \
  "$L_FEAT:8: unidad con @quarantine sin fila en docs/quarantine.md: @AC-COMPRA-10" "" -- chk

new
feat compra.feature \
  'Feature: Compra' \
  '' \
  '  @quarantine @AC-COMPRA-10 @tec-x' \
  '  Scenario Outline: Sin bloques' \
  '    Given <dato>'
reg
expect "Outline en cuarentena sin bloques Examples" 1 \
  "$L_FEAT:4: unidad con @quarantine sin fila en docs/quarantine.md: @AC-COMPRA-10" "" -- chk

# ------------------------------------------------------------------ falsos positivos
new
feat compra.feature \
  'Feature: Compra' \
  '' \
  '  # @quarantine @AC-COMPRA-09 (comentario)' \
  '  @AC-COMPRA-09 @tec-x @quarantined' \
  '  Scenario: Etiqueta parecida' \
  '    Given un texto' \
  '      """' \
  '      @quarantine' \
  '      Scenario: dentro del docstring' \
  '      """' \
  '' \
  '  @AC-COMPRA-10 @tec-x # @quarantine en un comentario de línea' \
  '  Scenario: Comentario al final' \
  '    Given algo'
reg
expect "comentarios, docstring y @quarantined no cuentan" 0 "" "" -- chk

# ------------------------------------------------------------------ campos
new; feat_q; reg '| inestable | `@AC-COMPRA-09` | Ana | 2026-10-05 | 2026-10-12 | — | Diagnóstico |'
expect "campo ausente: Issue con — (inestable)" 1 \
  "$L_FILA:15: campo ausente para inestable: Issue" "" -- chk

new; feat_q; reg '| inestable | `@AC-COMPRA-09` | — | 2026-10-05 | 2026-10-12 | #1 | d |'
expect "campo ausente: Dueño (inestable)" 1 \
  "$L_FILA:15: campo ausente para inestable: Dueño" "" -- chk

new; feat_q; reg '| defecto-sut | `@AC-COMPRA-09` | Ana | 2026-10-10 | — | a | b | 2026-12-31 |'
expect "campo ausente: Referencia (defecto-sut)" 1 \
  "$L_FILA:20: campo ausente para defecto-sut: Referencia" "" -- chk

new; feat_q; reg '| defecto-sut | `@AC-COMPRA-09` |  | 2026-10-10 | `docs/specs/compra.md` | a |  | 2026-12-31 |'
expect "campos ausentes: Dueño y Observado vacíos (defecto-sut)" 1 "$(lines \
  "$L_FILA:20: campo ausente para defecto-sut: Dueño" \
  "$L_FILA:20: campo ausente para defecto-sut: Observado")" "" -- chk

new; feat_q
raw '## Registro' '' \
  '| Tipo | Escenario | Dueño | Ingreso | Límite | Issue |' \
  '|---|---|---|---|---|---|' \
  '| inestable | `@AC-COMPRA-09` | Ana | 2026-10-05 | 2026-10-12 | #1 |'
expect "campo ausente: columna Diagnóstico inexistente" 1 \
  "$L_FILA:5: campo ausente para inestable: Diagnóstico" "" -- chk

new; feat_q; reg '| defecto-sut | `@AC-COMPRA-09` | Ana | 2026-10-10 | `docs/specs/compra.md` | a | b |'
expect "campo ausente: fila más corta que la cabecera" 1 \
  "$L_FILA:20: campo ausente para defecto-sut: Próxima revisión" "" -- chk

new; feat_q; reg '| defecto-sut | - | Ana | 2026-10-10 | `docs/specs/compra.md` | a | b | 2026-12-31 |'
expect "campo ausente: Escenario" 1 "$(lines \
  "$L_FILA:20: campo ausente: Escenario" \
  "$L_FEAT:10: unidad con @quarantine sin fila en docs/quarantine.md: @AC-COMPRA-09")" "" -- chk

new; feat_q; reg '| defecto-sut | `@AC-COMPRA-09` | Ana | 2026-10-10 | `docs/specs/nada.md` | a | b | 2026-12-31 |'
expect "Referencia a una spec inexistente" 1 \
  "$L_FILA:20: Referencia apunta a una spec inexistente: docs/specs/nada.md" "" -- chk

new; feat_q; reg '| defecto-sut | `@AC-COMPRA-09` | Ana | 2026-10-10 | spec de compra | a | b | 2026-12-31 |'
expect "Referencia sin ruta de spec" 1 \
  "$L_FILA:20: Referencia sin ruta docs/specs/<dominio>.md" "" -- chk

# ------------------------------------------------------------------ tipo
new; feat_q; reg '| flaky | `@AC-COMPRA-09` | Ana | 2026-10-05 | 2026-10-12 | #1 | d |'
expect "tipo desconocido" 1 \
  "$L_FILA:20: tipo desconocido (se espera inestable o defecto-sut)" "" -- chk

new; feat_q; reg '|  | `@AC-COMPRA-09` | Ana | 2026-10-05 | 2026-10-12 | #1 | d |'
expect "tipo ausente" 1 "$L_FILA:20: campo ausente: Tipo" "" -- chk

# ------------------------------------------------------------------ plazos
new; feat_q; reg "$(ri @AC-COMPRA-09 2026-10-01 2026-10-15)"
expect "inestable: límite a 14 días (frontera, pasa)" 0 "" "" -- chk

new; feat_q; reg "$(ri @AC-COMPRA-09 2026-10-01 2026-10-16)"
expect "inestable: límite a 15 días" 1 \
  "$L_FILA:15: Límite a 15 días de Ingreso (máximo 14 para inestable)" "" -- chk

new; feat_q; reg "$(rd @AC-COMPRA-09 2026-10-10 2027-01-08)"
expect "defecto-sut: revisión a 90 días (frontera, pasa)" 0 "" "" -- chk

new; feat_q; reg "$(rd @AC-COMPRA-09 2026-10-10 2027-01-09)"
expect "defecto-sut: revisión a 91 días" 1 \
  "$L_FILA:20: Próxima revisión a 91 días de Ingreso (máximo 90 para defecto-sut)" "" -- chk

new; feat_q; reg "$(ri @AC-COMPRA-09 2026-10-01 2026-10-10)"
expect "inestable: límite = hoy (frontera, pasa)" 0 "" "" -- chk

new; feat_q; reg "$(ri @AC-COMPRA-09 2026-10-01 2026-10-09)"
expect "inestable: límite vencido (hoy − 1)" 1 \
  "$L_FILA:15: Límite vencido: 2026-10-09 (hoy 2026-10-10)" "" -- chk

new; feat_q; reg "$(rd @AC-COMPRA-09 2026-08-01 2026-10-10)"
expect "defecto-sut: revisión = hoy (frontera, pasa)" 0 "" "" -- chk

new; feat_q; reg "$(rd @AC-COMPRA-09 2026-08-01 2026-10-09)"
expect "defecto-sut: revisión vencida (hoy − 1)" 1 \
  "$L_FILA:20: Próxima revisión vencida: 2026-10-09 (hoy 2026-10-10)" "" -- chk

new; feat_q; reg "$(ri @AC-COMPRA-09 2026-10-11 2026-10-12)"
expect "Ingreso posterior a hoy" 1 \
  "$L_FILA:15: Ingreso 2026-10-11 posterior a hoy (2026-10-10)" "" -- chk

new; feat_q; reg "$(rd @AC-COMPRA-09 2026-10-10 2026-10-09)"
expect "fecha final anterior a Ingreso" 1 "$(lines \
  "$L_FILA:20: Próxima revisión 2026-10-09 anterior a Ingreso 2026-10-10" \
  "$L_FILA:20: Próxima revisión vencida: 2026-10-09 (hoy 2026-10-10)")" "" -- chk

# Aritmética de fechas a través de febrero y del cambio de año.
new; feat_q; reg "$(ri @AC-COMPRA-09 2028-02-20 2028-03-05)"
expect "inestable: 14 días con 29 de febrero (bisiesto)" 0 "" "" -- \
  env CHK14_TODAY=2028-02-20 bash "$script" "$d"
new; feat_q; reg "$(ri @AC-COMPRA-09 2028-02-20 2028-03-06)"
expect "inestable: 15 días con 29 de febrero (bisiesto)" 1 \
  "$L_FILA:15: Límite a 15 días de Ingreso (máximo 14 para inestable)" "" -- \
  env CHK14_TODAY=2028-02-20 bash "$script" "$d"
new; feat_q; reg "$(ri @AC-COMPRA-09 2027-02-20 2027-03-06)"
expect "inestable: 14 días con febrero de 28 días" 0 "" "" -- \
  env CHK14_TODAY=2027-02-20 bash "$script" "$d"
new; feat_q; reg "$(ri @AC-COMPRA-09 2026-12-25 2027-01-09)"
expect "inestable: 15 días a través del cambio de año" 1 \
  "$L_FILA:15: Límite a 15 días de Ingreso (máximo 14 para inestable)" "" -- \
  env CHK14_TODAY=2026-12-25 bash "$script" "$d"

# ------------------------------------------------------------------ formato de fecha
new; feat_q; reg "$(ri @AC-COMPRA-09 2026-10-5 2026-10-12)"
expect "fecha mal formada: Ingreso 2026-10-5" 1 \
  "$L_FILA:15: Ingreso con formato inválido (se espera YYYY-MM-DD de calendario)" "" -- chk

new; feat_q; reg "$(ri @AC-COMPRA-09 2026-10-05 12/10/2026)"
expect "fecha mal formada: Límite 12/10/2026" 1 \
  "$L_FILA:15: Límite con formato inválido (se espera YYYY-MM-DD de calendario)" "" -- chk

new; feat_q; reg "$(rd @AC-COMPRA-09 2026-10-10 2026-11-31)"
expect "fecha mal formada: revisión 2026-11-31 (no existe)" 1 \
  "$L_FILA:20: Próxima revisión con formato inválido (se espera YYYY-MM-DD de calendario)" "" -- chk

new; feat_q; reg "$(rd @AC-COMPRA-09 2026-10-10 2027-02-29)"
expect "fecha mal formada: 2027-02-29 (no bisiesto)" 1 \
  "$L_FILA:20: Próxima revisión con formato inválido (se espera YYYY-MM-DD de calendario)" "" -- chk

new; feat_q; reg "$(rd @AC-COMPRA-09 2026-10-10 '2026-12-31 o antes')"
expect "fecha con texto adicional" 1 \
  "$L_FILA:20: Próxima revisión con formato inválido (se espera YYYY-MM-DD de calendario)" "" -- chk

# ------------------------------------------------------------------ estructura del registro
new; feat_plain; raw '# Cuarentena' '' '| Tipo | Escenario |' '|---|---|'
expect "sin sección ## Registro" 1 "$L_FILA:1: sin sección \"## Registro\"" "" -- chk

new; feat_plain; raw '# Registro' '' '| Tipo | Escenario |' '|---|---|'
expect "un título # Registro (nivel 1) no es la sección" 1 "$L_FILA:1: sin sección \"## Registro\"" "" -- chk

new; feat_plain; raw '## Registro' '' '| Tipo | Escenario |' '|---|---|' '' '## Registro' ''
expect "dos secciones ## Registro" 1 "$L_FILA:6: más de una sección \"## Registro\"" "" -- chk

new; feat_q
raw '## Registro' '' '| Clase | Escenario | Dueño |' '|---|---|---|' \
  '| inestable | `@AC-COMPRA-09` | Ana |'
expect "tabla del Registro sin columna Tipo" 1 "$(lines \
  "$L_FILA:3: tabla del Registro sin columnas Tipo y Escenario" \
  "$L_FEAT:10: unidad con @quarantine sin fila en docs/quarantine.md: @AC-COMPRA-09")" "" -- chk

new; feat_q
raw '## Registro' '' '| Tipo | AC | Dueño |' '|---|---|---|' \
  '| inestable | `@AC-COMPRA-09` | Ana |'
expect "tabla del Registro sin columna Escenario" 1 "$(lines \
  "$L_FILA:3: tabla del Registro sin columnas Tipo y Escenario" \
  "$L_FEAT:10: unidad con @quarantine sin fila en docs/quarantine.md: @AC-COMPRA-09")" "" -- chk

new; feat_q
raw '## Registro' '' "$HI" \
  '| inestable | `@AC-COMPRA-09` | Ana | 2026-10-05 | 2026-10-12 | #1 | d |'
expect "tabla del Registro sin fila separadora" 1 "$(lines \
  "$L_FILA:3: tabla del Registro sin fila separadora" \
  "$L_FEAT:10: unidad con @quarantine sin fila en docs/quarantine.md: @AC-COMPRA-09")" "" -- chk

new; feat_plain; raw '## Registro' '' "$HI"
expect "cabecera sin separadora al final del archivo" 1 \
  "$L_FILA:3: tabla del Registro sin fila separadora" "" -- chk

new; feat_q
raw '## Registro' '' '```' "$HI" "$SI" "$(ri @AC-COMPRA-09 2026-10-05 2026-10-12)" '```'
expect "tabla dentro de un bloque de código no cuenta" 1 \
  "$L_FEAT:10: unidad con @quarantine sin fila en docs/quarantine.md: @AC-COMPRA-09" "" -- chk

# ------------------------------------------------------------------ fecha del sistema
sys_today="$(date +%Y-%m-%d)"
new; feat_q; reg "$(ri @AC-COMPRA-09 "$sys_today" "$sys_today")"
expect "sin CHK14_TODAY: usa la fecha del sistema (pasa)" 0 "" "" -- bash "$script" "$d"
new; feat_q; reg "$(ri @AC-COMPRA-09 2000-01-01 2000-01-10)"
expect "sin CHK14_TODAY: usa la fecha del sistema (vencido)" 1 \
  "$L_FILA:15: Límite vencido: 2000-01-10 (hoy $sys_today)" "" -- bash "$script" "$d"

new; feat_plain
expect "CHK14_TODAY 2028-02-29 (bisiesto) es válida" 0 "" "" -- env CHK14_TODAY=2028-02-29 bash "$script" "$d"
expect "CHK14_TODAY 2000-02-29 (bisiesto por 400) es válida" 0 "" "" -- env CHK14_TODAY=2000-02-29 bash "$script" "$d"

# ------------------------------------------------------------------ exit 2
expect "exit 2: CHK14_TODAY 2100-02-29 (no bisiesto)" 2 "" "no es una fecha de calendario" -- \
  env CHK14_TODAY=2100-02-29 bash "$script" "$d"
expect "exit 2: CHK14_TODAY 0000-01-01 (año 0)" 2 "" "no es una fecha de calendario" -- \
  env CHK14_TODAY=0000-01-01 bash "$script" "$d"
expect "exit 2: CHK14_TODAY 2026-13-01" 2 "" "no es una fecha de calendario" -- \
  env CHK14_TODAY=2026-13-01 bash "$script" "$d"
expect "exit 2: CHK14_TODAY con formato inválido" 2 "" "no tiene formato YYYY-MM-DD" -- \
  env CHK14_TODAY=10/10/2026 bash "$script" "$d"
expect "exit 2: CHK14_TODAY vacía" 2 "" "no tiene formato YYYY-MM-DD" -- \
  env CHK14_TODAY= bash "$script" "$d"
expect "exit 2: raíz inexistente" 2 "" "no es un directorio" -- \
  env CHK14_TODAY="$TODAY" bash "$script" "$tmp/no-existe"
expect "exit 2: argumentos de más" 2 "" "uso:" -- \
  env CHK14_TODAY="$TODAY" bash "$script" "$d" "$d"

new; rm -rf "${d:?}/src"; reg
expect "exit 2: sin directorio de features" 2 "" "no existe src/test/resources/features" -- chk

new; feat_plain; mkdir -p "$d/$Q"
expect "exit 2: docs/quarantine.md es un directorio" 2 "" "no es un archivo regular legible" -- chk

new; feat_plain; ln -s no-existe.md "$d/$Q"
expect "exit 2: docs/quarantine.md enlace roto" 2 "" "no es un archivo regular legible" -- chk

if [ "$(id -u)" -ne 0 ]; then
  new; feat_plain; reg; chmod 000 "$d/$Q"
  expect "exit 2: docs/quarantine.md ilegible" 2 "" "no es un archivo regular legible" -- chk
  chmod 644 "$d/$Q"

  new; feat_q; reg "$(ri @AC-COMPRA-09 2026-10-05 2026-10-12)"; chmod 000 "$d/$F/compra.feature"
  expect "exit 2: feature ilegible" 2 "" "error interno de awk" -- chk
  chmod 644 "$d/$F/compra.feature"
else
  rows+=("$(printf '%-62s | %s | %s | omitido (root)' "exit 2: archivos ilegibles" 2 -)")
fi

# ------------------------------------------------------------------ reporte
printf '%-62s | %s | %s | %s\n' "caso" "esperado" "real" "resultado"
printf '%s\n' "${rows[@]}"
echo "casos: ${#rows[@]}, fallos: $fails"
if [ "$fails" -gt 0 ]; then
  cat "$tmp/detalle"
  exit 1
fi
exit 0
