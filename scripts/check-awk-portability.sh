#!/usr/bin/env bash
# Portabilidad de los programas awk entre mawk, gawk y POSIX.
#
# Uso: bash scripts/check-awk-portability.sh [raíz]      (raíz por defecto: .)
#
# Busca, en scripts/**/*.sh, .github/workflows/*.yml y Jenkinsfile, nombres que
# gawk trata de forma especial y que mawk acepta como variables normales (por
# eso pasan en local con mawk y fallan, o cambian en silencio, en el runner de
# GitHub Actions, donde awk es gawk):
#   - variables integradas de gawk: usarlas como array es un error fatal
#     ("attempt to use scalar as an array"); asignar IGNORECASE cambia en
#     silencio cómo se comparan las cadenas (verde falso);
#   - RS: con más de un carácter, POSIX no lo define;
#   - ENVIRON: es POSIX, pero los scripts reciben sus datos con -v (P-02);
#   - funciones y extensiones exclusivas de gawk, y match() con tercer
#     argumento (aproximado: admite un nivel de paréntesis anidados; una coma
#     dentro de la regex da un falso positivo, que se resuelve reescribiendo).
# No sustituye a scripts/run-with-each-awk.sh (que ejecuta las autopruebas con
# cada awk); lo complementa donde gawk no está instalado.
#
# Los nombres se prohíben en cualquier parte del archivo, también en
# comentarios: distinguir el código awk del bash que lo rodea no es fiable, y
# un falso positivo se resuelve renombrando. Se excluyen este script y su
# autoprueba, que definen los patrones.
#
# Salida: 0 sin hallazgos; 1 con hallazgos ("archivo:línea: motivo");
#         2 si no se puede evaluar (raíz, sin archivos, error de grep).
# Solo bash, coreutils, find, sort y grep (sin awk).
set -euo pipefail
export LC_ALL=C

me="check-awk-portability"
err() { echo "$me: $*" >&2; exit 2; }

[ "$#" -le 1 ] || err "uso: bash scripts/check-awk-portability.sh [raíz]"
root="${1:-.}"
[ -d "$root" ] || err "la raíz '$root' no es un directorio"
cd "$root"
[ -d scripts ] || err "no existe el directorio scripts"

self="scripts/check-awk-portability.sh"
selftest="scripts/tests/check-awk-portability-test.sh"

# find con error (directorio ilegible) dejaría la lista incompleta: falla cerrado.
list="$(find scripts -type f -name '*.sh')" || err "find terminó con error en scripts"
if [ -d .github/workflows ]; then
  list="$list"$'\n'"$(find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \))" \
    || err "find terminó con error en .github/workflows"
fi
[ -f Jenkinsfile ] && list="$list"$'\n'"Jenkinsfile"
files=()
while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ "$f" = "$self" ] || [ "$f" = "$selftest" ] || files+=("$f")
done <<< "$list"
[ "${#files[@]}" -gt 0 ] || err "no hay archivos que revisar"
for f in "${files[@]}"; do
  [ -r "$f" ] || err "$f no se puede leer"
done
mapfile -t files < <(printf '%s\n' "${files[@]}" | sort)

found=""
# rule <motivo> <opciones de grep> <patrón>
rule() {
  local reason="$1" opts="$2" pat="$3" out rc=0
  out="$(grep -Hn $opts -e "$pat" -- "${files[@]}" 2> "$tmp_err")" || rc=$?
  if [ "$rc" -ge 2 ] || [ -s "$tmp_err" ]; then
    cat "$tmp_err" >&2
    err "grep terminó con $rc ($reason)"
  fi
  if [ "$rc" -ne 0 ]; then return 0; fi
  while IFS= read -r line; do
    found="${found}${line%%:*}:$(cut -d: -f2 <<< "$line"): $reason"$'\n'
  done <<< "$out"
}

tmp_err="$(mktemp)"
trap 'rm -f "$tmp_err"' EXIT

rule "variable integrada de gawk (RT, IGNORECASE, FPAT, FIELDWIDTHS, BINMODE, PROCINFO, SYMTAB, FUNCTAB, ERRNO, LINT, TEXTDOMAIN, ARGIND, PREC, ROUNDMODE): renombrar" \
  -wE 'RT|IGNORECASE|FPAT|FIELDWIDTHS|BINMODE|PROCINFO|SYMTAB|FUNCTAB|ERRNO|LINT|TEXTDOMAIN|ARGIND|PREC|ROUNDMODE'
rule "RS: con más de un carácter POSIX no lo define; no cambiar el separador de registro" \
  -wE 'RS'
rule "ENVIRON: los programas awk reciben sus datos con -v (P-02)" \
  -wE 'ENVIRON'
rule "función exclusiva de gawk (gensub, asort, asorti, strftime, systime, mktime, patsplit, isarray, typeof, and, or, xor, lshift, rshift, compl, strtonum, bindtextdomain, dcgettext, dcngettext)" \
  -E '\b(gensub|asorti?|strftime|systime|mktime|patsplit|isarray|typeof|and|or|xor|lshift|rshift|compl|strtonum|bindtextdomain|dcgettext|dcngettext)[[:space:]]*\('
rule "extensión exclusiva de gawk (@include, @load, @namespace, BEGINFILE, ENDFILE)" \
  -E '@(include|load|namespace)\b|\b(BEGINFILE|ENDFILE)\b'
rule "match() con tercer argumento: exclusivo de gawk" \
  -E '\bmatch[[:space:]]*\(([^(),]|\([^()]*\))*,([^(),]|\([^()]*\))*,'

if [ -n "$found" ]; then
  printf '%s' "$found" | sort -t: -k1,1 -k2,2n | uniq
  exit 1
fi
echo "$me: ok: ${#files[@]} archivos sin construcciones exclusivas de una implementación de awk"
exit 0
