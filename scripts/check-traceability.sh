#!/usr/bin/env bash
# CHK-12 — Trazabilidad SDD (Regla 01: SDD-05, SDD-06 y SDD-09; Regla 04).
#
# Uso: bash scripts/check-traceability.sh [raíz]   (raíz por defecto: .)
#
# Verifica:
#   1. Cada *.feature bajo src/test/resources/features/ declara en su descripción
#      "Spec: docs/specs/<dominio>.md".
#   2. Esa spec existe y su cabecera tiene "| Estado | aprobada |".
#   3. Cada Scenario/Example tiene @AC-<DOMINIO>-<NN> y @tec-<técnica>, propias
#      o heredadas de la Feature o de la Rule.
#   4. Cada Scenario Outline/Template las tiene en sí mismo (o heredadas), o cada
#      bloque Examples aporta lo que falte (cada escenario generado lleva ambas).
#   5. Cada @AC- usado en una feature existe como fila de la tabla de AC de su spec.
#   6. Cada AC con Verificable = "sí…" aparece en al menos un escenario de alguna
#      feature que referencia esa spec.
#
# Salida: 0 si todo pasa; 1 si hay violaciones, una por línea como
# "archivo:línea: motivo"; 2 ante un error interno del script.
# Solo bash, coreutils, find, sort y awk POSIX (compatible con mawk y gawk).
set -euo pipefail

root="${1:-.}"
if [ ! -d "$root" ]; then
  echo "check-traceability: la raíz '$root' no es un directorio" >&2
  exit 2
fi
cd "$root"

export LC_ALL=C
features_dir="src/test/resources/features"

files=()
if [ -d "$features_dir" ]; then
  while IFS= read -r f; do
    files+=("$f")
  done < <(find "$features_dir" -type f -name '*.feature' | sort)
fi

if [ "${#files[@]}" -eq 0 ]; then
  echo "${features_dir}:0: no hay archivos .feature que verificar"
  exit 1
fi

# awk no procesa archivos vacíos: se reportan aquí.
empty=""
for f in "${files[@]}"; do
  [ -s "$f" ] || empty="${empty}${f}:1: archivo .feature vacío"$'\n'
done

out="$(awk '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

function viol(file, line, msg) { nv++; V[nv] = file ":" line ": " msg }

# Divide una fila de tabla Markdown en C[1..n]; respeta "\|" dentro de celdas.
function cells(row,    n, i, tmp) {
  gsub(/\\\|/, "\001", row)
  sub(/^[ \t]*\|/, "", row)
  sub(/\|[ \t]*$/, "", row)
  n = split(row, tmp, "|")
  for (i = 1; i <= n; i++) {
    C[i] = trim(tmp[i])
    gsub(/\001/, "|", C[i])
    gsub(/`/, "", C[i])
  }
  return n
}

# Lista de etiquetas: entradas "TAG:LÍNEA" separadas por espacios.
function has_ac(list,    n, i, t, tmp) {
  n = split(list, tmp, " ")
  for (i = 1; i <= n; i++) { t = tmp[i]; sub(/:[0-9]+$/, "", t); if (t ~ /^@AC-[A-Z]+-[0-9][0-9]$/) return 1 }
  return 0
}
function has_tec(list,    n, i, t, tmp) {
  n = split(list, tmp, " ")
  for (i = 1; i <= n; i++) { t = tmp[i]; sub(/:[0-9]+$/, "", t); if (t ~ /^@tec-[A-Za-z0-9_-]+$/) return 1 }
  return 0
}
# Registra los @AC- de un escenario efectivo para las reglas 5 y 6.
function record_used(list,    n, i, t, ln, tmp) {
  n = split(list, tmp, " ")
  for (i = 1; i <= n; i++) {
    t = tmp[i]; ln = t; sub(/:[0-9]+$/, "", t); sub(/^.*:/, "", ln)
    if (t ~ /^@AC-[A-Z]+-[0-9][0-9]$/) {
      sub(/^@/, "", t)
      if (!((cur, t) in used_line)) { used_line[cur, t] = ln; nu++; U_file[nu] = cur; U_ac[nu] = t }
    }
  }
}

function check_scenario(kind, list, line) {
  if (!has_ac(list))  viol(cur, line, kind " sin @AC-<DOMINIO>-<NN> (ni propia ni heredada)")
  if (!has_tec(list)) viol(cur, line, kind " sin @tec-<técnica> (ni propia ni heredada)")
  record_used(list)
}

function close_outline() {
  if (outline_open && n_examples == 0) check_scenario("Scenario Outline", outline_tags, outline_line)
  outline_open = 0
}

function end_feature() {
  if (cur == "") return
  close_outline()
  if (!feature_seen) viol(cur, 1, "archivo sin palabra clave Feature:")
  else if (!(cur in spec_of) && !(cur in spec_bad))
    viol(cur, feature_line, "la descripción de la Feature no declara \"Spec: docs/specs/<dominio>.md\"")
}

FNR == 1 {
  # end_feature cierra el archivo anterior (cur) antes de cambiar al nuevo.
  end_feature()
  cur = FILENAME
  pending = ""; feature_tags = ""; rule_tags = ""; feature_seen = 0; feature_line = 1
  in_desc = 0; in_doc = 0; outline_open = 0; n_examples = 0
}

{
  sub(/\r$/, "")
  t = trim($0)

  # Docstrings: su contenido es texto libre, no Gherkin.
  if (t ~ /^"""/ || t ~ /^```/) { in_doc = !in_doc; next }
  if (in_doc) next

  if (t == "" || t ~ /^#/) next

  if (t ~ /^@/) {
    in_desc = 0
    sub(/[ \t]+#.*$/, "", t)
    n = split(t, tok, /[ \t]+/)
    for (i = 1; i <= n; i++) {
      if (tok[i] !~ /^@/) continue
      if (tok[i] ~ /^@AC-/ && tok[i] !~ /^@AC-[A-Z]+-[0-9][0-9]$/)
        viol(cur, FNR, "etiqueta @AC- con formato inválido (se espera @AC-<DOMINIO>-<NN>)")
      pending = pending " " tok[i] ":" FNR
    }
    next
  }

  if (t ~ /^Feature:/) {
    feature_seen = 1; feature_line = FNR; feature_tags = pending; pending = ""; in_desc = 1
    next
  }
  if (t ~ /^Rule:/) {
    close_outline(); in_desc = 0; rule_tags = pending; pending = ""
    next
  }
  if (t ~ /^Background:/) {
    close_outline(); in_desc = 0; pending = ""
    next
  }
  if (t ~ /^Scenario (Outline|Template):/) {
    close_outline(); in_desc = 0
    outline_open = 1; outline_line = FNR; n_examples = 0
    outline_tags = feature_tags " " rule_tags " " pending; pending = ""
    next
  }
  if (t ~ /^(Scenario|Example):/) {
    close_outline(); in_desc = 0
    check_scenario("Scenario", feature_tags " " rule_tags " " pending, FNR); pending = ""
    next
  }
  if (t ~ /^(Examples|Scenarios):/) {
    in_desc = 0
    if (outline_open) {
      n_examples++
      list = outline_tags " " pending
      if (!has_ac(list))  viol(cur, FNR, "Examples sin @AC-<DOMINIO>-<NN> (ni en el bloque, ni en el Scenario Outline ni heredada)")
      if (!has_tec(list)) viol(cur, FNR, "Examples sin @tec-<técnica> (ni en el bloque, ni en el Scenario Outline ni heredada)")
      record_used(list)
    }
    pending = ""
    next
  }

  if (in_desc && t ~ /^Spec:/) {
    if (cur in spec_of || cur in spec_bad) {
      viol(cur, FNR, "más de una línea Spec: en la descripción de la Feature")
    } else {
      p = t; sub(/^Spec:[ \t]*/, "", p); gsub(/`/, "", p); p = trim(p)
      if (p ~ /^docs\/specs\/[A-Za-z0-9_-]+\.md$/) {
        spec_of[cur] = p; spec_line[cur] = FNR
        if (!(p in spec_seen)) { spec_seen[p] = 1; ns++; S[ns] = p; spec_first_ref[p] = cur ":" FNR }
      } else {
        spec_bad[cur] = 1
        viol(cur, FNR, "línea Spec: con formato inválido (se espera \"Spec: docs/specs/<dominio>.md\")")
      }
    }
  }
}

END {
  end_feature()

  # Carga de cada spec referenciada.
  for (k = 1; k <= ns; k++) {
    sp = S[k]; ln = 0; estado = ""; estado_line = 0; vcol = 0; in_ac = 0; has_ac_table = 0
    rc = (getline row < sp)
    if (rc < 0) { spec_missing[sp] = 1; continue }
    while (rc > 0) {
      ln++
      sub(/\r$/, "", row)
      if (row ~ /^[ \t]*\|/) {
        n = cells(row)
        if (estado_line == 0 && C[1] == "Estado" && n >= 2) { estado = C[2]; estado_line = ln }
        if (!in_ac) {
          for (i = 1; i <= n; i++) if (C[i] == "Verificable") { vcol = i; in_ac = 1; has_ac_table = 1 }
        } else if (C[1] ~ /^AC-[A-Z]+-[0-9][0-9]$/) {
          if (!((sp, C[1]) in ac_line)) {
            ac_line[sp, C[1]] = ln
            if (vcol <= n && (C[vcol] ~ /^s(í|i)$/ || C[vcol] ~ /^s(í|i)[^A-Za-z0-9]/)) {
              nver++; VER_spec[nver] = sp; VER_ac[nver] = C[1]
            }
          }
        }
      } else {
        in_ac = 0
      }
      rc = (getline row < sp)
    }
    close(sp)
    if (estado_line == 0) viol(sp, 1, "sin fila \"| Estado | aprobada |\" en la tabla de cabecera (referenciada por " spec_first_ref[sp] ")")
    else if (estado != "aprobada") viol(sp, estado_line, "Estado distinto de \"aprobada\" (referenciada por " spec_first_ref[sp] ")")
    if (!has_ac_table) viol(sp, 1, "sin tabla de criterios de aceptación con columna Verificable")
  }

  # Regla 2 (existencia): una línea por feature que apunta a una spec inexistente.
  for (f in spec_of)
    if (spec_of[f] in spec_missing)
      viol(f, spec_line[f], "la spec referenciada no existe")

  # Regla 5: cada @AC- usado existe en la spec de su feature.
  for (i = 1; i <= nu; i++) {
    f = U_file[i]; a = U_ac[i]
    if (!(f in spec_of)) continue
    sp = spec_of[f]
    if (sp in spec_missing) continue
    covered[sp, a] = 1
    if (!((sp, a) in ac_line))
      viol(f, used_line[f, a], "@" a " no existe como criterio de aceptación en " sp)
  }

  # Regla 6: cada AC verificable tiene al menos un escenario.
  for (i = 1; i <= nver; i++) {
    sp = VER_spec[i]; a = VER_ac[i]
    if (!((sp, a) in covered))
      viol(sp, ac_line[sp, a], a " es verificable y ningún escenario de las features que referencian esta spec lo cubre")
  }

  for (i = 1; i <= nv; i++) print V[i]
}
' "${files[@]}")" || { echo "check-traceability: error interno de awk" >&2; exit 2; }

out="${empty}${out}"
if [ -n "$out" ]; then
  printf '%s\n' "$out" | sed '/^$/d' | sort -t: -k1,1 -k2,2n | uniq
  exit 1
fi
exit 0
