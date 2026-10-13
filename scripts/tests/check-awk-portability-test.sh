#!/usr/bin/env bash
# Autoprueba de scripts/check-awk-portability.sh.
#
# Uso: bash scripts/tests/check-awk-portability-test.sh
#
# Cada caso crea en un temporal fuera del repositorio (mktemp -d) un árbol
# mínimo (scripts/, y en algunos casos .github/workflows/ y Jenkinsfile) y
# exige el código de salida y la salida estándar EXACTA (rc 0 y 1), o el
# mensaje de error esperado en stderr (rc 2). Con rc 0 y 1, stderr vacío.
#
# Sale con 0 solo si todos los casos se comportan como se espera; con 1 si
# alguno falla; con 2 ante un error de preparación. Imprime la tabla
# caso → esperado → real. El temporal se borra al salir (trap).
set -euo pipefail
export LC_ALL=C

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
script="$here/../check-awk-portability.sh"
repo_root="$(cd "$here/../.." && pwd -P)"
if [ ! -f "$script" ]; then
  echo "check-awk-portability-test: no existe $script" >&2
  exit 2
fi

tmp="$(mktemp -d)"
trap 'chmod -R u+rwx "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT
tmp="$(cd "$tmp" && pwd -P)"
case "$tmp/" in
  "$repo_root"/*)
    echo "check-awk-portability-test: el temporal $tmp está dentro del repositorio" >&2
    exit 2
    ;;
esac

V="variable integrada de gawk (RT, IGNORECASE, FPAT, FIELDWIDTHS, BINMODE, PROCINFO, SYMTAB, FUNCTAB, ERRNO, LINT, TEXTDOMAIN, ARGIND, PREC, ROUNDMODE): renombrar"
RS_MSG="RS: con más de un carácter POSIX no lo define; no cambiar el separador de registro"
ENV_MSG="ENVIRON: los programas awk reciben sus datos con -v (P-02)"
FN="función exclusiva de gawk (gensub, asort, asorti, strftime, systime, mktime, patsplit, isarray, typeof, and, or, xor, lshift, rshift, compl, strtonum, bindtextdomain, dcgettext, dcngettext)"
EXT="extensión exclusiva de gawk (@include, @load, @namespace, BEGINFILE, ENDFILE)"
M3="match() con tercer argumento: exclusivo de gawk"

n_case=0
# new: árbol con un script limpio en scripts/ok.sh. Deja su ruta en $d.
new() {
  n_case=$((n_case + 1))
  d="$tmp/c$n_case"
  mkdir -p "$d/scripts/tests"
  put scripts/ok.sh '#!/usr/bin/env bash' "awk '{ QTYPE[\$1] = \$2 } END { for (k in QTYPE) print k }' f"
}
# put <ruta relativa> <líneas…>
put() {
  local p="$d/$1"
  shift
  mkdir -p "$(dirname "$p")"
  printf '%s\n' "$@" > "$p"
}

fails=0
results=()
# expect <nombre> <rc> <salida exacta (rc 0 y 1) o fragmento de stderr (rc 2)> [args]
expect() {
  local name="$1" want_rc="$2" want="$3"
  shift 3
  local out err got_rc=0 ok=1 why=""
  out="$(bash "$script" "$@" 2> "$tmp/stderr")" || got_rc=$?
  err="$(cat "$tmp/stderr")"
  [ "$got_rc" = "$want_rc" ] || { ok=0; why="rc $got_rc"; }
  if [ "$want_rc" = 2 ]; then
    case "$err" in *"$want"*) ;; *) ok=0; why="$why; stderr sin «$want»" ;; esac
  else
    [ "$out" = "$want" ] || { ok=0; why="$why; salida distinta"; }
    [ -z "$err" ] || { ok=0; why="$why; stderr no vacío"; }
  fi
  if [ "$ok" = 1 ]; then
    results+=("ok    | $name | rc $want_rc")
  else
    fails=$((fails + 1))
    results+=("FALLA | $name | esperado rc $want_rc, real:${why}")
    printf '%s\n' "--- $name: salida" "$out" "--- esperado" "$want" "--- stderr" "$err" >&2
  fi
}

# --- Sin hallazgos (y sin falsos positivos con nombres parecidos).
new
put scripts/b.sh '#!/usr/bin/env bash' \
  "awk '{ RTX = 1; MYRT[1] = 2; ORS = \"\\n\"; FS = \",\"; RSTART = 0 }'" \
  "awk '{ if (match(\$0, /x/)) print substr(\$0, RSTART, RLENGTH); start(1); orx(2); format(3) }'" \
  "awk '{ if (match(\$0, /a(b)c/) && match(tolower(\$0), \"x\")) n++ }'" \
  "echo 'gensubx y strftimes no son funciones'"
expect "limpio y nombres parecidos" 0 "check-awk-portability: ok: 2 archivos sin construcciones exclusivas de una implementación de awk" "$d"

# --- Cada nombre, en su propia línea: quitar uno de la regla hace fallar el caso.
# family <nombre del caso> <motivo> <línea awk con @ en lugar del nombre> <nombres…>
family() {
  local name="$1" reason="$2" tpl="$3" want="" i=1 tok
  shift 3
  new
  put scripts/x.sh '#!/usr/bin/env bash'
  for tok in "$@"; do
    i=$((i + 1))
    printf '%s\n' "awk '${tpl//@/$tok}' f" >> "$d/scripts/x.sh"
    want="${want}scripts/x.sh:$i: $reason"$'\n'
  done
  expect "$name" 1 "${want%$'\n'}" "$d"
}
family "variables integradas de gawk" "$V" '{ if (!(k in @)) @[k] = 1 }' \
  RT IGNORECASE FPAT FIELDWIDTHS BINMODE PROCINFO SYMTAB FUNCTAB ERRNO LINT TEXTDOMAIN ARGIND PREC ROUNDMODE
family "funciones exclusivas de gawk" "$FN" '{ x = @(a, b) }' \
  gensub asort asorti strftime systime mktime patsplit isarray typeof and or xor lshift rshift compl strtonum bindtextdomain dcgettext dcngettext
family "funciones de gawk con espacio antes del paréntesis" "$FN" '{ x = @ (a) }' gensub or
family "extensiones de gawk" "$EXT" '@ "x"' @include @load @namespace
family "BEGINFILE y ENDFILE" "$EXT" '@ { n++ }' BEGINFILE ENDFILE

new
put scripts/x.sh '#!/usr/bin/env bash' "awk 'BEGIN { RS = \"--\" } { print }' f" "awk -v RS=ab '{ print }' f"
expect "RS" 1 "$(printf '%s\n' "scripts/x.sh:2: $RS_MSG" "scripts/x.sh:3: $RS_MSG")" "$d"

new
put scripts/x.sh '#!/usr/bin/env bash' "awk 'BEGIN { print ENVIRON[\"HOME\"] }'"
expect "ENVIRON" 1 "scripts/x.sh:2: $ENV_MSG" "$d"

new
put scripts/x.sh '#!/usr/bin/env bash' "awk '{ if (match(\$0, /a(b)/, m)) print m[1] }'"
expect "match() con tercer argumento" 1 "scripts/x.sh:2: $M3" "$d"

# --- Orden por archivo y número de línea (10 después de 9), varias reglas.
new
put scripts/tests/y-test.sh '#!/usr/bin/env bash' 'a' 'b' 'c' 'd' 'e' 'f' 'g' "awk '{ RT[1] }'" "awk 'BEGIN { RS = \"x\" }'"
put scripts/z.sh '#!/usr/bin/env bash' "awk '{ print ENVIRON[\"X\"]; s = gensub(/a/, \"b\", 1) }'"
expect "orden y varias reglas" 1 "$(printf '%s\n' \
  "scripts/tests/y-test.sh:9: $V" "scripts/tests/y-test.sh:10: $RS_MSG" \
  "scripts/z.sh:2: $ENV_MSG" "scripts/z.sh:2: $FN")" "$d"

# --- Pipelines: workflows de GitHub y Jenkinsfile.
new
put .github/workflows/ci.yml 'jobs:' '  a:' '    steps:' "      - run: awk '{ IGNORECASE = 1 }' f"
put .github/workflows/otro.yaml 'jobs:' "  b: { steps: [ { run: \"awk '{ print systime() }'\" } ] }"
put Jenkinsfile 'pipeline {' "  sh \"awk '{ RT[1] = 1 }' f\"" '}'
expect "workflows y Jenkinsfile" 1 "$(printf '%s\n' \
  ".github/workflows/ci.yml:4: $V" ".github/workflows/otro.yaml:2: $FN" "Jenkinsfile:2: $V")" "$d"

# --- Este script y su autoprueba se excluyen (definen los patrones).
new
put scripts/check-awk-portability.sh '#!/usr/bin/env bash' "# RT IGNORECASE gensub("
put scripts/tests/check-awk-portability-test.sh '#!/usr/bin/env bash' "# RT ENVIRON"
expect "exclusión de sí mismo" 0 "check-awk-portability: ok: 1 archivos sin construcciones exclusivas de una implementación de awk" "$d"

# --- Falla cerrado (rc 2).
new
rm -rf "$d/scripts"
expect "sin scripts/" 2 "no existe el directorio scripts" "$d"

new
rm -f "$d/scripts/ok.sh"
expect "sin archivos" 2 "no hay archivos que revisar" "$d"

expect "raíz inexistente" 2 "no es un directorio" "$tmp/no-existe"
expect "demasiados argumentos" 2 "uso:" "$d" otro

if [ "$(id -u)" != 0 ]; then
  new
  put scripts/x.sh '#!/usr/bin/env bash'
  chmod 000 "$d/scripts/x.sh"
  expect "archivo ilegible" 2 "scripts/x.sh no se puede leer" "$d"
  chmod 644 "$d/scripts/x.sh"

  new
  mkdir -p "$d/scripts/cerrado"
  put scripts/cerrado/x.sh '#!/usr/bin/env bash' "awk '{ RT[1] }'"
  chmod 000 "$d/scripts/cerrado"
  expect "directorio ilegible (find con error)" 2 "find terminó con error en scripts" "$d"
  chmod 755 "$d/scripts/cerrado"
else
  results+=("n/a   | archivo y directorio ilegibles | root lee todo")
fi

# grep con error: un shim en el PATH sale con 2 sin stderr, o con 1 y stderr.
for spec in "rc2:exit 2" "stderr:echo 'grep: fallo simulado' >&2; exit 1"; do
  mkdir -p "$tmp/shim-${spec%%:*}"
  printf '#!/usr/bin/env bash\n%s\n' "${spec#*:}" > "$tmp/shim-${spec%%:*}/grep"
  chmod +x "$tmp/shim-${spec%%:*}/grep"
done
new
PATH="$tmp/shim-rc2:$PATH" expect "grep sale con 2 sin stderr" 2 "grep terminó con 2" "$d"
new
PATH="$tmp/shim-stderr:$PATH" expect "grep escribe en stderr" 2 "grep terminó con 1" "$d"

# --- El repositorio real queda limpio.
expect "repositorio" 0 "check-awk-portability: ok: $(cd "$repo_root" && { find scripts -type f -name '*.sh'; find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \); [ -f Jenkinsfile ] && echo Jenkinsfile; } | grep -vcxE 'scripts/check-awk-portability\.sh|scripts/tests/check-awk-portability-test\.sh') archivos sin construcciones exclusivas de una implementación de awk" "$repo_root"

printf '%s\n' "${results[@]}"
total="${#results[@]}"
if [ "$fails" -ne 0 ]; then
  echo "check-awk-portability-test: $fails de $total casos fallaron"
  exit 1
fi
echo "check-awk-portability-test: $total casos ok"
exit 0
