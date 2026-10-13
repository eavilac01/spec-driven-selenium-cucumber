#!/usr/bin/env bash
# Ejecuta un comando una vez por cada implementación de awk disponible.
#
# Uso: bash scripts/run-with-each-awk.sh [--require <impl>]... -- <comando> [args]
#      <impl>: mawk | gawk | gawk-posix | busybox | original-awk
#      --require  la implementación debe existir y ejecutarse; si falta, sale
#                 con 2 (falla cerrado). En CI: --require mawk --require gawk
#                 --require gawk-posix.
#
# Motivo: Ubuntu de escritorio trae mawk como `awk` y el runner de GitHub
# Actions trae gawk. Un programa awk que solo se prueba con una implementación
# puede romperse (o, peor, cambiar en silencio de comportamiento) con la
# otra: un array con el nombre de una variable integrada de gawk pasó 52/52
# con mawk y falló 46/52 en CI. scripts/check-awk-portability.sh lo detecta
# también de forma estática, sin necesitar gawk.
#
# Para cada implementación crea un directorio temporal con un `awk` que la
# invoca y lo antepone al PATH del comando. El shim cuenta sus invocaciones:
# si el comando termina sin haber llamado a awk por el PATH (ruta absoluta,
# PATH reiniciado), la ejecución no midió nada y cuenta como fallo.
#
# Sale con 0 si el comando sale con 0 con todas las implementaciones; con 1 si
# falla con alguna o no invocó awk; con 2 ante un error de uso o de
# preparación (ninguna implementación, una --require ausente o que no
# responde). Sin gawk local avisa: esa ejecución no cubre gawk.
set -euo pipefail
export LC_ALL=C

me="run-with-each-awk"
usage() {
  echo "$me: uso: bash scripts/run-with-each-awk.sh [--require <impl>]... -- <comando> [args]" >&2
  exit 2
}
err() { echo "$me: $*" >&2; exit 2; }

known="mawk gawk gawk-posix busybox original-awk"
is_known() { case " $known " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

required=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --require)
      [ "$#" -ge 2 ] || usage
      is_known "$2" || err "implementación desconocida '$2' (conocidas: $known)"
      required+=("$2"); shift 2 ;;
    --) shift; break ;;
    *) usage ;;
  esac
done
[ "$#" -ge 1 ] || usage

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# resolve <impl>: deja en $bin y $pre (argumentos previos al programa) la forma
# de invocarla, y en $ver su versión. Devuelve 1 si no existe o no se
# identifica como esa implementación (p. ej. un `gawk` que es un enlace a mawk).
resolve() {
  local v=""
  bin=""; pre=""; ver=""
  case "$1" in
    mawk)
      bin="$(command -v mawk)" || return 1
      v="$("$bin" -W version 2>&1 < /dev/null)" || true
      case "$v" in mawk*) ;; *) return 1 ;; esac ;;
    gawk|gawk-posix)
      bin="$(command -v gawk)" || return 1
      v="$("$bin" --version 2>&1 < /dev/null)" || true
      case "$v" in "GNU Awk"*) ;; *) return 1 ;; esac
      [ "$1" = gawk ] || pre="--posix" ;;
    busybox)
      bin="$(command -v busybox)" || return 1
      v="$("$bin" 2>&1 < /dev/null)" || true
      case "$v" in BusyBox*) ;; *) return 1 ;; esac
      pre="awk" ;;
    original-awk)
      bin="$(command -v original-awk)" || return 1
      v="$("$bin" --version 2>&1 < /dev/null)" || true
      case "$v" in *"awk version"*) ;; *) return 1 ;; esac ;;
  esac
  ver="${v%%$'\n'*}"
  case "$bin" in /*) ;; *) return 1 ;; esac
  return 0
}

impls=()
for id in $known; do
  if resolve "$id"; then
    impls+=("$id")
  else
    for r in "${required[@]+"${required[@]}"}"; do
      [ "$r" != "$id" ] || err "se exige '$id' y no está disponible"
    done
  fi
done
[ "${#impls[@]}" -gt 0 ] || err "no hay ninguna implementación de awk conocida ($known)"

case " ${impls[*]} " in
  *" gawk "*) ;;
  *) echo "$me: AVISO: gawk no está disponible: esta ejecución no cubre gawk (CI lo exige con --require gawk); scripts/check-awk-portability.sh cubre sus nombres reservados" >&2 ;;
esac

fails=0
results=()
for id in "${impls[@]}"; do
  resolve "$id"
  dir="$tmp/$id"
  calls="$tmp/$id.calls"
  mkdir -p "$dir"
  : > "$calls"
  if [ -n "$pre" ]; then
    printf '#!/usr/bin/env bash\nprintf ".\\n" >> %q\nexec %q %q "$@"\n' "$calls" "$bin" "$pre" > "$dir/awk"
  else
    printf '#!/usr/bin/env bash\nprintf ".\\n" >> %q\nexec %q "$@"\n' "$calls" "$bin" > "$dir/awk"
  fi
  chmod +x "$dir/awk"
  # El shim responde y es el awk que encuentra el PATH del comando.
  got="$(PATH="$dir:$PATH" bash -c 'command -v awk')" || got=""
  [ "$got" = "$dir/awk" ] || err "$id: el PATH no resuelve awk al shim ($got)"
  got="$(PATH="$dir:$PATH" awk 'BEGIN { print 1 + 1 }' 2>&1)" || got="rc $?: $got"
  [ "$got" = 2 ] || err "$id ($bin $pre) no responde: $got"
  : > "$calls"

  echo "=== $me: $id ($bin${pre:+ $pre}): $ver"
  rc=0
  PATH="$dir:$PATH" "$@" || rc=$?
  n="$(wc -l < "$calls")"
  n=$((n + 0))
  if [ "$rc" -ne 0 ]; then
    fails=$((fails + 1)); results+=("FALLA | $id | rc $rc | awk invocado $n veces")
  elif [ "$n" -eq 0 ]; then
    fails=$((fails + 1)); results+=("FALLA | $id | rc 0 sin invocar awk por el PATH: no midió nada")
  else
    results+=("ok    | $id | rc 0 | awk invocado $n veces")
  fi
done

echo "=== $me: resumen ($*)"
printf '%s\n' "${results[@]}"
if [ "$fails" -ne 0 ]; then
  echo "$me: $fails de ${#impls[@]} implementaciones fallaron"
  exit 1
fi
echo "$me: ${#impls[@]} implementaciones ok: ${impls[*]}"
exit 0
