#!/usr/bin/env bash
# Autoprueba de scripts/run-with-each-awk.sh.
#
# Uso: bash scripts/tests/run-with-each-awk-test.sh
#
# El runner descubre las implementaciones con `command -v`. Para que el
# resultado no dependa de lo que tenga instalado la máquina, cada caso lo
# ejecuta con un PATH mínimo (un temporal fuera del repositorio) con las
# herramientas que usa y unos awk falsos:
#   - mawk: el awk real del sistema (mawk o gawk, el que haya), que se presenta
#     como mawk;
#   - gawk: se presenta como "GNU Awk", delega en el awk real y sale con 1 si
#     algún argumento es FALLAR (simula un programa que gawk rechaza);
#   - gawk-roto: un `gawk` que en realidad es mawk (no se identifica como gawk).
# Exige el código de salida y una línea de la salida estándar (rc 0 y 1) o de
# stderr (rc 2).
#
# Sale con 0 solo si todos los casos se comportan como se espera; con 1 si
# alguno falla; con 2 ante un error de preparación. El temporal se borra al
# salir (trap).
set -euo pipefail
export LC_ALL=C

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
script="$here/../run-with-each-awk.sh"
repo_root="$(cd "$here/../.." && pwd -P)"
me="run-with-each-awk-test"
if [ ! -f "$script" ]; then
  echo "$me: no existe $script" >&2
  exit 2
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
tmp="$(cd "$tmp" && pwd -P)"
case "$tmp/" in
  "$repo_root"/*) echo "$me: el temporal $tmp está dentro del repositorio" >&2; exit 2 ;;
esac

real_awk="$(command -v mawk || command -v gawk || command -v awk)" \
  || { echo "$me: no hay ningún awk en el PATH" >&2; exit 2; }

# Herramientas que usan el runner, los shims y los comandos de los casos.
tools="$tmp/tools"
mkdir -p "$tools"
for t in bash mktemp rm mkdir chmod wc cat; do
  p="$(command -v "$t")" || { echo "$me: falta $t" >&2; exit 2; }
  ln -s "$p" "$tools/$t"
done

# fake <directorio> <nombre> <contenido del script>
fake() {
  mkdir -p "$1"
  printf '#!/usr/bin/env bash\n%s\n' "$3" > "$1/$2"
  chmod +x "$1/$2"
}
fake "$tmp/mawk" mawk "if [ \"\${1:-}\" = -W ]; then echo 'mawk 1.3.4 (falso)'; exit 0; fi
exec $(printf '%q' "$real_awk") \"\$@\""
fake "$tmp/gawk" gawk "if [ \"\${1:-}\" = --version ]; then echo 'GNU Awk 5.3.0 (falso)'; exit 0; fi
for a in \"\$@\"; do [ \"\$a\" != FALLAR ] || exit 1; done
[ \"\${1:-}\" != --posix ] || shift
exec $(printf '%q' "$real_awk") \"\$@\""
mkdir -p "$tmp/gawk-roto"
ln -s "$tmp/mawk/mawk" "$tmp/gawk-roto/gawk"
fake "$tmp/gawk-posix-roto" gawk "if [ \"\${1:-}\" = --version ]; then echo 'GNU Awk 5.3.0 (falso)'; exit 0; fi
[ \"\${1:-}\" != --posix ] || exit 2
exec $(printf '%q' "$real_awk") \"\$@\""

fails=0
results=()
# expect <nombre> <PATH extra> <rc> <línea esperada (fija)> <argumentos del runner…>
expect() {
  local name="$1" extra="$2" want_rc="$3" want="$4"
  shift 4
  local out err got_rc=0 ok=1 why="" path="$tools"
  [ -z "$extra" ] || path="$extra:$tools"
  out="$(PATH="$path" "$tools/bash" "$script" "$@" 2> "$tmp/stderr")" || got_rc=$?
  err="$(cat "$tmp/stderr")"
  [ "$got_rc" = "$want_rc" ] || { ok=0; why="rc $got_rc"; }
  if [ "$want_rc" = 2 ]; then
    case "$err" in *"$want"*) ;; *) ok=0; why="$why; stderr sin «$want»" ;; esac
  else
    printf '%s\n' "$out" | grep -qxF -- "$want" || { ok=0; why="$why; stdout sin «$want»"; }
  fi
  if [ "$ok" = 1 ]; then
    results+=("ok    | $name | rc $want_rc")
  else
    fails=$((fails + 1))
    results+=("FALLA | $name | esperado rc $want_rc, real:${why}")
    printf '%s\n' "--- $name: salida" "$out" "--- stderr" "$err" >&2
  fi
}

ok_cmd=(bash -c "awk 'BEGIN { exit 0 }'")

expect "solo mawk: verde" "$tmp/mawk" 0 "ok    | mawk | rc 0 | awk invocado 1 veces" -- "${ok_cmd[@]}"
expect "solo mawk: avisa que no cubre gawk" "$tmp/mawk" 0 "run-with-each-awk: 1 implementaciones ok: mawk" -- "${ok_cmd[@]}"
if PATH="$tmp/mawk:$tools" "$tools/bash" "$script" -- "${ok_cmd[@]}" 2>&1 >/dev/null | grep -qF 'AVISO: gawk no está disponible'; then
  results+=("ok    | solo mawk | aviso de gawk en stderr")
else
  fails=$((fails + 1)); results+=("FALLA | solo mawk | sin aviso de gawk en stderr")
fi

expect "mawk, gawk y gawk-posix" "$tmp/mawk:$tmp/gawk" 0 "run-with-each-awk: 3 implementaciones ok: mawk gawk gawk-posix" \
  --require mawk --require gawk --require gawk-posix -- "${ok_cmd[@]}"

# Falla con una implementación: rc 1 y la tabla dice cuál.
fail_cmd=(bash -c "awk 'BEGIN { exit 0 }' FALLAR")
expect "falla con gawk" "$tmp/mawk:$tmp/gawk" 1 "FALLA | gawk | rc 1 | awk invocado 1 veces" -- "${fail_cmd[@]}"
expect "falla con gawk: mawk sigue en verde" "$tmp/mawk:$tmp/gawk" 1 "ok    | mawk | rc 0 | awk invocado 1 veces" -- "${fail_cmd[@]}"
expect "falla con gawk: resumen" "$tmp/mawk:$tmp/gawk" 1 "run-with-each-awk: 2 de 3 implementaciones fallaron" -- "${fail_cmd[@]}"

# El comando no invoca awk por el PATH: no midió nada.
expect "sin invocar awk" "$tmp/mawk" 1 "FALLA | mawk | rc 0 sin invocar awk por el PATH: no midió nada" -- bash -c 'exit 0'
expect "awk por ruta absoluta" "$tmp/mawk" 1 "FALLA | mawk | rc 0 sin invocar awk por el PATH: no midió nada" \
  -- bash -c "$(printf '%q' "$real_awk") 'BEGIN { exit 0 }'"

# Falla cerrado (rc 2).
expect "exige gawk y no está" "$tmp/mawk" 2 "se exige 'gawk' y no está disponible" --require gawk -- "${ok_cmd[@]}"
expect "gawk que es mawk no cuenta como gawk" "$tmp/mawk:$tmp/gawk-roto" 2 "se exige 'gawk' y no está disponible" --require gawk -- "${ok_cmd[@]}"
expect "gawk --posix que no responde" "$tmp/mawk:$tmp/gawk-posix-roto" 2 "gawk-posix (" -- "${ok_cmd[@]}"
expect "ninguna implementación" "" 2 "no hay ninguna implementación de awk conocida" -- "${ok_cmd[@]}"
expect "implementación desconocida" "$tmp/mawk" 2 "implementación desconocida 'nawk'" --require nawk -- "${ok_cmd[@]}"
expect "sin --" "$tmp/mawk" 2 "uso:" "${ok_cmd[@]}"
expect "sin comando" "$tmp/mawk" 2 "uso:" --

printf '%s\n' "${results[@]}"
total="${#results[@]}"
if [ "$fails" -ne 0 ]; then
  echo "$me: $fails de $total casos fallaron"
  exit 1
fi
echo "$me: $total casos ok"
exit 0
