#!/usr/bin/env bash
# CHK-14 — Cuarentena reglada (Regla 04; docs/quarantine.md).
#
# Uso: bash scripts/check-quarantine.sh [raíz]   (raíz por defecto: .)
#      CHK14_TODAY=YYYY-MM-DD fija la fecha "hoy" (autoprueba); sin ella se usa
#      la fecha local del sistema.
#
# Unidad en cuarentena: cada Scenario/Example, cada bloque Examples de un
# Scenario Outline (o el Outline, si no tiene bloques) cuyas etiquetas
# efectivas (propias o heredadas de la Feature, la Rule o el Outline) incluyen
# @quarantine. Se identifica por sus @AC-<DOMINIO>-<NN>.
#
# El registro es la sección "## Registro" de docs/quarantine.md: tablas
# Markdown con columnas Tipo y Escenario (una sola etiqueta @AC-…), más los
# campos de su tipo:
#   inestable    Dueño, Ingreso, Límite, Issue, Diagnóstico
#                Límite − Ingreso ≤ 14 días; Límite ≥ hoy
#   defecto-sut  Dueño, Ingreso, Referencia (docs/specs/<dominio>.md existente),
#                Esperado, Observado, Próxima revisión
#                Próxima revisión − Ingreso ≤ 90 días; Próxima revisión ≥ hoy
# En ambos tipos: fechas YYYY-MM-DD de calendario, Ingreso ≤ hoy y la fecha
# final no anterior a Ingreso. Una celda vacía o con "—", "–" o "-" es un campo
# ausente. Un tipo distinto de esos dos es un error.
#
# Cruce: cada @AC- de cada unidad en cuarentena tiene exactamente una fila; cada
# fila tiene al menos una unidad en cuarentena con su @AC-. Varias unidades con
# el mismo @AC- comparten la fila.
#
# Sin docs/quarantine.md: exit 0 si no hay ninguna unidad en cuarentena (no hay
# nada que registrar ni ninguna prueba oculta); si la hay, cada una es una
# violación.
#
# Salida: 0 si todo pasa; 1 si hay violaciones, una por línea como
# "archivo:línea: motivo"; 2 si no se puede evaluar (raíz o argumentos
# inválidos, CHK14_TODAY mal formada, sin directorio de features, registro
# ilegible o error interno). Solo imprime rutas, números de línea, etiquetas
# @AC-, nombres de campo y fechas ya validadas; nunca el contenido de una celda.
# Solo bash, coreutils, find, sort y awk POSIX (compatible con mawk y gawk).
set -euo pipefail
export LC_ALL=C

err() { echo "check-quarantine: $*" >&2; exit 2; }

[ "$#" -le 1 ] || err "uso: check-quarantine.sh [raíz]"
root="${1:-.}"
[ -d "$root" ] || err "la raíz '$root' no es un directorio"
cd "$root"

if [ -n "${CHK14_TODAY+x}" ]; then
  today="$CHK14_TODAY"
else
  today="$(date +%Y-%m-%d)" || err "no se pudo obtener la fecha del sistema"
fi
[[ "$today" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || err "la fecha de hoy (CHK14_TODAY) no tiene formato YYYY-MM-DD"

features_dir="src/test/resources/features"
qfile="docs/quarantine.md"

[ -d "$features_dir" ] || err "no existe $features_dir"

files=()
while IFS= read -r f; do
  files+=("$f")
done < <(find "$features_dir" -type f -name '*.feature' | sort)

qarg=""
if [ -e "$qfile" ] || [ -L "$qfile" ]; then
  [ -f "$qfile" ] && [ -r "$qfile" ] || err "$qfile no es un archivo regular legible"
  qarg="$qfile"
fi

# Sin archivos que leer, awk leería la entrada estándar.
if [ -z "$qarg" ] && [ "${#files[@]}" -eq 0 ]; then
  exit 0
fi

args=()
[ -n "$qarg" ] && args+=("$qarg")
args+=("${files[@]}")

rc=0
out="$(awk -v qfile="$qarg" -v qname="$qfile" -v today="$today" '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

function viol(loc, msg) { nv++; V[nv] = loc ": " msg }

# Divide una fila de tabla Markdown en C[1..n]; respeta "\|" dentro de celdas.
# Un parámetro no puede llamarse como una función (POSIX; gawk --posix lo rechaza).
function cells(line,    n, i, tmp) {
  gsub(/\\\|/, "\001", line)
  sub(/^[ \t]*\|/, "", line)
  sub(/\|[ \t]*$/, "", line)
  n = split(line, tmp, "|")
  for (i = 1; i <= n; i++) {
    C[i] = trim(tmp[i])
    gsub(/\001/, "|", C[i])
    gsub(/`/, "", C[i])
  }
  return n
}

function leap(y) { return (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 }

function valid_date(s,    y, m, d, md) {
  if (s !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) return 0
  y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  if (y < 1 || m < 1 || m > 12 || d < 1) return 0
  md = 31
  if (m == 4 || m == 6 || m == 9 || m == 11) md = 30
  if (m == 2) md = leap(y) ? 29 : 28
  return d <= md
}

# Días desde una época fija (algoritmo days_from_civil); solo fechas válidas.
function days(s,    y, m, d, era, yoe, mp, doy, doe) {
  y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  if (m <= 2) y--
  era = int(y / 400)
  yoe = y - era * 400
  mp = (m > 2) ? m - 3 : m + 9
  doy = int((153 * mp + 2) / 5) + d - 1
  doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
  return era * 146097 + doe
}

# ------------------------------------------------------------------ features
function is_q(list,    n, i, tmp) {
  n = split(list, tmp, " ")
  for (i = 1; i <= n; i++) if (tmp[i] == "@quarantine") return 1
  return 0
}

# Registra una unidad; si está en cuarentena, guarda cada @AC- distinto.
function unit(list, line,    n, i, t, tmp, nac) {
  if (!is_q(list)) return
  nunits++
  n = split(list, tmp, " "); nac = 0
  for (i = 1; i <= n; i++) {
    t = tmp[i]
    if (t !~ /^@AC-[A-Z]+-[0-9][0-9]$/) continue
    if ((nunits, t) in seen_unit_ac) continue
    seen_unit_ac[nunits, t] = 1
    nac++; nq++; Q_ac[nq] = t; Q_loc[nq] = cur ":" line; Q[t] = 1
  }
  if (nac == 0)
    viol(cur ":" line, "unidad con @quarantine sin @AC-<DOMINIO>-<NN>: no se puede identificar su fila en " qname)
}

function close_outline() {
  if (outline_open && n_examples == 0) unit(outline_tags, outline_line)
  outline_open = 0
}

# ------------------------------------------------------------------ registro
function get(name) {
  if (!(name in col) || col[name] > ncell) return ""
  return C[col[name]]
}
function absent(v) { return v == "" || v == "—" || v == "–" || v == "-" }

function check_dates(tipo, fin_name, max,    ing, fin, ok, di, df, dt) {
  ing = get("Ingreso"); fin = get(fin_name); ok = 1
  if (!absent(ing) && !valid_date(ing)) { viol(qfile ":" FNR, "Ingreso con formato inválido (se espera YYYY-MM-DD de calendario)"); ok = 0 }
  if (!absent(fin) && !valid_date(fin)) { viol(qfile ":" FNR, fin_name " con formato inválido (se espera YYYY-MM-DD de calendario)"); ok = 0 }
  if (!ok || absent(ing) || absent(fin)) return
  di = days(ing); df = days(fin); dt = days(today)
  if (di > dt) viol(qfile ":" FNR, "Ingreso " ing " posterior a hoy (" today ")")
  if (df < di) viol(qfile ":" FNR, fin_name " " fin " anterior a Ingreso " ing)
  else if (df - di > max) viol(qfile ":" FNR, fin_name " a " (df - di) " días de Ingreso (máximo " max " para " tipo ")")
  if (df < dt) viol(qfile ":" FNR, fin_name (fin_name == "Límite" ? " vencido: " : " vencida: ") fin " (hoy " today ")")
}

function require(tipo, list,    n, i, f) {
  n = split(list, f, ",")
  for (i = 1; i <= n; i++)
    if (absent(get(f[i]))) viol(qfile ":" FNR, "campo ausente para " tipo ": " f[i])
}

function row(line,    tipo, esc, ref) {
  ncell = cells(line)
  tipo = get("Tipo"); esc = get("Escenario")

  if (absent(esc)) viol(qfile ":" FNR, "campo ausente: Escenario")
  else if (esc !~ /^@AC-[A-Z]+-[0-9][0-9]$/)
    viol(qfile ":" FNR, "Escenario debe ser una sola etiqueta @AC-<DOMINIO>-<NN>")
  else if (esc in R)
    viol(qfile ":" FNR, "más de una fila para " esc " (la primera en la línea " R[esc] ")")
  else R[esc] = FNR

  if (tipo == "inestable") {
    require(tipo, "Dueño,Ingreso,Límite,Issue,Diagnóstico")
    check_dates(tipo, "Límite", 14)
  } else if (tipo == "defecto-sut") {
    require(tipo, "Dueño,Ingreso,Referencia,Esperado,Observado,Próxima revisión")
    check_dates(tipo, "Próxima revisión", 90)
    ref = get("Referencia")
    if (!absent(ref)) {
      if (match(ref, /docs\/specs\/[A-Za-z0-9_-]+\.md/)) {
        ref = substr(ref, RSTART, RLENGTH)
        if ((getline tmpline < ref) < 0) viol(qfile ":" FNR, "Referencia apunta a una spec inexistente: " ref)
        close(ref)
      } else {
        viol(qfile ":" FNR, "Referencia sin ruta docs/specs/<dominio>.md")
      }
    }
  } else if (absent(tipo)) {
    viol(qfile ":" FNR, "campo ausente: Tipo")
  } else {
    viol(qfile ":" FNR, "tipo desconocido (se espera inestable o defecto-sut)")
  }
}

BEGIN {
  if (!valid_date(today)) { bad_today = 1; exit 3 }
}

FILENAME == qfile {
  sub(/\r$/, "")
  if ($0 ~ /^[ \t]*(```|~~~)/) { in_fence = !in_fence; tstate = 0; next }
  if (in_fence) next
  if ($0 ~ /^#[ \t]/ || $0 ~ /^##[ \t]/) {
    if (tstate == 1) viol(qfile ":" hdr_line, "tabla del Registro sin fila separadora")
    tstate = 0
    h = $0; sub(/^##?[ \t]+/, "", h)
    in_reg = ($0 ~ /^##[ \t]/ && trim(h) == "Registro")
    if (in_reg) { if (reg_seen) viol(qfile ":" FNR, "más de una sección \"## Registro\""); reg_seen = 1 }
    next
  }
  if (!in_reg) next
  if ($0 !~ /^[ \t]*\|/) {
    if (tstate == 1) viol(qfile ":" hdr_line, "tabla del Registro sin fila separadora")
    tstate = 0
    next
  }
  if (tstate == 0) {
    n = cells($0); split("", col)
    for (i = 1; i <= n; i++) if (C[i] != "" && !(C[i] in col)) col[C[i]] = i
    hdr_line = FNR; tstate = 1
    next
  }
  if (tstate == 1) {
    if ($0 !~ /^[ \t]*\|([ \t]*:?-+:?[ \t]*\|)+[ \t]*$/) {
      viol(qfile ":" hdr_line, "tabla del Registro sin fila separadora")
      tstate = 3
      next
    }
    if (!("Tipo" in col) || !("Escenario" in col)) {
      viol(qfile ":" hdr_line, "tabla del Registro sin columnas Tipo y Escenario")
      tstate = 3
      next
    }
    tstate = 2
    next
  }
  if (tstate == 2) row($0)
  next
}

FNR == 1 {
  close_outline()
  cur = FILENAME
  pending = ""; feature_tags = ""; rule_tags = ""; in_doc = 0; outline_open = 0; n_examples = 0
}

{
  sub(/\r$/, "")
  t = trim($0)

  # Docstrings: su contenido es texto libre, no Gherkin.
  if (t ~ /^"""/ || t ~ /^```/) { in_doc = !in_doc; next }
  if (in_doc) next

  if (t == "" || t ~ /^#/) next

  if (t ~ /^@/) {
    sub(/[ \t]+#.*$/, "", t)
    n = split(t, tok, /[ \t]+/)
    for (i = 1; i <= n; i++) if (tok[i] ~ /^@/) pending = pending " " tok[i]
    next
  }

  if (t ~ /^Feature:/) { feature_tags = pending; pending = ""; next }
  if (t ~ /^Rule:/) { close_outline(); rule_tags = pending; pending = ""; next }
  if (t ~ /^Background:/) { close_outline(); pending = ""; next }
  if (t ~ /^Scenario (Outline|Template):/) {
    close_outline()
    outline_open = 1; outline_line = FNR; n_examples = 0
    outline_tags = feature_tags " " rule_tags " " pending; pending = ""
    next
  }
  if (t ~ /^(Scenario|Example):/) {
    close_outline()
    unit(feature_tags " " rule_tags " " pending, FNR); pending = ""
    next
  }
  if (t ~ /^(Examples|Scenarios):/) {
    if (outline_open) { n_examples++; unit(outline_tags " " pending, FNR) }
    pending = ""
    next
  }
}

END {
  if (bad_today) exit 3
  close_outline()
  if (qfile != "") {
    if (tstate == 1) viol(qfile ":" hdr_line, "tabla del Registro sin fila separadora")
    if (!reg_seen) viol(qfile ":1", "sin sección \"## Registro\"")
  }
  for (i = 1; i <= nq; i++)
    if (!(Q_ac[i] in R))
      viol(Q_loc[i], "unidad con @quarantine sin fila en " qname ": " Q_ac[i] (qfile == "" ? " (archivo ausente)" : ""))
  for (a in R)
    if (!(a in Q)) viol(qfile ":" R[a], "fila de " a " sin escenario con @quarantine")
  for (i = 1; i <= nv; i++) print V[i]
}
' "${args[@]}")" || rc=$?

if [ "$rc" -eq 3 ]; then
  err "la fecha de hoy (CHK14_TODAY) no es una fecha de calendario"
elif [ "$rc" -ne 0 ]; then
  err "error interno de awk"
fi

if [ -n "$out" ]; then
  printf '%s\n' "$out" | sort -t: -k1,1 -k2,2n | uniq
  exit 1
fi
exit 0
