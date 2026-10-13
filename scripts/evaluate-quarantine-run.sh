#!/usr/bin/env bash
# CHK-14 — Evalúa la ejecución de los escenarios @quarantine (job `quarantine`
# de GitHub Actions y etapa `Cuarentena (CHK-14)` de Jenkins).
#
# Uso: bash scripts/evaluate-quarantine-run.sh [--github] [--summary <archivo>]
#           <rc-de-maven> <log-de-maven> [raíz]          (raíz por defecto: .)
#      --github    mensajes como anotaciones (::error::, ::warning::, ::notice::)
#      --summary   agrega al archivo una tabla Markdown (p. ej. $GITHUB_STEP_SUMMARY)
#      La ruta del log es relativa al directorio actual, no a la raíz.
#
# Lee docs/quarantine.md (tipo de cada @AC-), las features (qué escenarios
# están en cuarentena), target/surefire-reports/TEST-com.demo.runners.RunnerTest.xml
# y el log de Maven. Un escenario en cuarentena que falla por aserción
# (<failure>) o que pasa es una medición válida, y también un `inestable` que
# termina con <error>; lo que se vigila es que la cuarentena mida de verdad.
#
# Salida:
#   0  medición válida. Un `defecto-sut` que falla por aserción es lo esperado
#      (nota); un `inestable` que falla por aserción o pasa es informativo (nota).
#   3  medición válida con aviso (GitHub lo deja en verde con ::warning::;
#      Jenkins marca la etapa como UNSTABLE):
#        - un `defecto-sut` (o un escenario cuyo tipo no se puede resolver entre
#          varios) PASA: el SUT pudo haberse corregido; revisar la spec y la
#          cuarentena;
#        - un `inestable` termina con <error> (excepción o timeout, no
#          aserción): es justo la causa raíz en diagnóstico; el aviso nombra sus
#          @AC- (decisión del usuario, 2026-10-13). Solo si todos los @AC- del
#          escenario son `inestable`: con tipo mixto o sin clasificar es rojo.
#   1  la cuarentena no midió nada o se rompió (rojo real):
#        - no hay XML de RunnerTest (p. ej. falló la compilación) o está truncado;
#        - el log no tiene la línea "Tests run … -- in com.demo.runners.RunnerTest"
#          o sus números no coinciden con el XML (XML de otra ejecución);
#        - el rc de Maven no concuerda con el resultado (rc 0 con fallos, rc ≠ 0
#          sin fallos de prueba, rc distinto de 0 y 1, BUILD SUCCESS/FAILURE o
#          el fallo del goal test de Surefire ausentes);
#        - algún <error> (excepción o timeout, no aserción) en un escenario que
#          no es `inestable` (defecto-sut, tipo mixto o sin clasificar), aunque
#          otro `inestable` también termine con error;
#        - un reintento (flaky/rerun, CHK-02) o un omitido por otro motivo que
#          el filtro;
#        - cero escenarios ejecutados, un escenario en cuarentena sin ejecutar,
#          o uno ejecutado que no está en cuarentena (filtro de tags roto);
#        - un @AC- en cuarentena sin fila válida en docs/quarantine.md.
#   2  no se puede evaluar (argumentos, raíz o archivos ilegibles, error interno).
#
# PI-05: del XML solo se leen la estructura, los contadores y el nombre de cada
# escenario (que viene de la feature); nunca el mensaje de fallo ni la salida
# capturada, que pueden contener texto del SUT. Las secciones CDATA se ignoran.
# Solo bash, coreutils, find, sort y awk POSIX (compatible con mawk y gawk).
set -euo pipefail
export LC_ALL=C

me="evaluate-quarantine-run"
usage() {
  echo "$me: uso: bash scripts/evaluate-quarantine-run.sh [--github] [--summary <archivo>] <rc-de-maven> <log-de-maven> [raíz]" >&2
  exit 2
}
err() { echo "$me: $*" >&2; exit 2; }

fmt=plain
summary=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --github) fmt=github; shift ;;
    --summary)
      [ "$#" -ge 2 ] || usage
      summary="$2"; shift 2 ;;
    --) shift; break ;;
    -*) usage ;;
    *) break ;;
  esac
done
[ "$#" -ge 2 ] && [ "$#" -le 3 ] || usage
mvn_rc="$1"
log="$2"
root="${3:-.}"

[[ "$mvn_rc" =~ ^[0-9]+$ ]] || err "el rc de Maven '$mvn_rc' no es un entero no negativo"
[ -f "$log" ] && [ -r "$log" ] || err "el log '$log' no existe o no se puede leer"
[ -d "$root" ] || err "la raíz '$root' no es un directorio"
if [ -n "$summary" ]; then
  : >> "$summary" 2>/dev/null || err "no se puede escribir el resumen en '$summary'"
  summary="$(cd "$(dirname "$summary")" && pwd -P)/$(basename "$summary")"
fi
log="$(cd "$(dirname "$log")" && pwd -P)/$(basename "$log")"
cd "$root"

features_dir="src/test/resources/features"
qfile="docs/quarantine.md"
xml="target/surefire-reports/TEST-com.demo.runners.RunnerTest.xml"

[ -d "$features_dir" ] || err "no existe $features_dir"
[ -f "$qfile" ] && [ -r "$qfile" ] || err "$qfile no existe o no se puede leer"

files=()
while IFS= read -r f; do
  files+=("$f")
done < <(find "$features_dir" -type f -name '*.feature' | sort)
[ "${#files[@]}" -gt 0 ] || err "no hay features en $features_dir"

# Sin XML no se le pasa a awk (no debe leer la entrada estándar): awk lo
# reporta como rojo, igual que un XML vacío.
xml_arg=""
if [ -e "$xml" ]; then
  [ -f "$xml" ] && [ -r "$xml" ] || err "$xml no es un archivo regular legible"
  xml_arg="$xml"
fi

args=("$qfile" "${files[@]}")
[ -n "$xml_arg" ] && args+=("$xml_arg")
args+=("$log")

rc=0
awk -v qfile="$qfile" -v xmlfile="$xml_arg" -v xmlname="$xml" -v logfile="$log" \
    -v mvn_rc="$mvn_rc" -v fmt="$fmt" -v sumfile="$summary" -v me="$me" '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

# ------------------------------------------------------------------ mensajes
# Solo datos del repositorio (nombres de escenario, @AC-, contadores). En
# formato GitHub se escapan "%", CR y LF, como pide la sintaxis de anotaciones.
function esc(s) {
  if (fmt != "github") return s
  gsub(/%/, "%25", s); gsub(/\r/, "%0D", s); gsub(/\n/, "%0A", s)
  return s
}
function emit(level, msg,    p) {
  if (fmt == "github") p = "::" level "::"
  else if (level == "error") p = "ERROR: "
  else if (level == "warning") p = "AVISO: "
  else p = "NOTA: "
  print p esc(msg)
}
function red(msg) { nred++; RED[nred] = msg }

# Fila Markdown: "|" dentro de una celda se escapa.
function cell(s) { gsub(/\|/, "\\|", s); return s }

# ------------------------------------------------------------------ registro
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

# ------------------------------------------------------------------ features
function has_tag(list, tag,    n, i, tmp) {
  n = split(list, tmp, " ")
  for (i = 1; i <= n; i++) if (tmp[i] == tag) return 1
  return 0
}
# Lista de @AC- distintos de una lista de etiquetas, separados por espacio.
function acs(list,    n, i, tmp, out, seen) {
  n = split(list, tmp, " "); out = ""
  split("", seen)
  for (i = 1; i <= n; i++)
    if (tmp[i] ~ /^@AC-[A-Z]+-[0-9][0-9]$/ && !(tmp[i] in seen)) { seen[tmp[i]] = 1; out = out " " tmp[i] }
  return out
}
# Escenario simple (o Example): su nombre identifica el <testcase>.
function scenario(title, list, line) {
  if (!has_tag(list, "@quarantine")) { OTHER[title] = 1; return }
  nqs++; QS_name[nqs] = title; QS_loc[nqs] = cur ":" line
  QNAME[title] = QNAME[title] acs(list)
}
# Bloque Examples (o Outline sin bloques) en cuarentena: sus filas se llaman
# "Example #N.M" y no se distinguen por nombre de las de otro Outline.
function outline_unit(list) {
  if (!has_tag(list, "@quarantine")) { other_outline = 1; return }
  q_outline = 1
  Q_OUTLINE_ACS = Q_OUTLINE_ACS acs(list)
}
function close_outline() {
  if (outline_open && n_examples == 0) outline_unit(outline_tags)
  outline_open = 0
}

# ------------------------------------------------------------------ XML
function xml_unescape(s) {
  gsub(/&lt;/, "<", s); gsub(/&gt;/, ">", s); gsub(/&quot;/, "\"", s)
  gsub(/&apos;/, "\047", s); gsub(/&amp;/, "\\&", s)
  return s
}
# Texto visible de una línea: sin el contenido de las secciones CDATA.
function visible(s,    out, i) {
  out = ""
  while (s != "") {
    if (in_cdata) {
      i = index(s, "]]>")
      if (i == 0) return out
      s = substr(s, i + 3); in_cdata = 0
    } else {
      i = index(s, "<![CDATA[")
      if (i == 0) return out s
      out = out substr(s, 1, i - 1)
      s = substr(s, i + 9); in_cdata = 1
    }
  }
  return out
}
function attr(tag, name,    v) {
  if (!match(tag, " " name "=\"[^\"]*\"")) return ""
  v = substr(tag, RSTART + length(name) + 3, RLENGTH - length(name) - 4)
  return v
}
function close_case() {
  if (!in_case) return
  in_case = 0
  ncase++
  CNAME[ncase] = case_name
  if (case_flags ~ /R/) CRES[ncase] = "reintento"
  else if (length(case_flags) > 1) CRES[ncase] = "múltiple"
  else if (case_flags == "F") CRES[ncase] = "falla"
  else if (case_flags == "E") CRES[ncase] = "error"
  else if (case_flags == "S") CRES[ncase] = "omitido-filtro"
  else if (case_flags == "O") CRES[ncase] = "omitido-otro"
  else CRES[ncase] = "pasa"
}
# Procesa las etiquetas de una línea visible del XML, en orden.
# Una etiqueta que no cierra en su línea (atributo con salto de línea) cuenta
# por su nombre; <testsuite>, <testcase> y <skipped> necesitan sus atributos
# completos, así que partidas hacen el XML no reconocible.
function xml_line(s,    i, rest, tag, j, partial) {
  rest = s
  while ((i = index(rest, "<")) > 0) {
    rest = substr(rest, i)
    j = index(rest, ">")
    partial = (j == 0)
    if (partial) { tag = rest " "; rest = "" }
    else { tag = substr(rest, 1, j); rest = substr(rest, j + 1) }
    if (partial && tag ~ /^<(testsuite|testcase|skipped)[ \t]/) { xml_bad = 1; continue }
    if (tag ~ /^<testsuite[ \t>]/) {
      if (suite_seen) xml_bad = 1
      suite_seen = 1
      S_tests = attr(tag, "tests"); S_fail = attr(tag, "failures")
      S_err = attr(tag, "errors"); S_skip = attr(tag, "skipped")
    } else if (tag == "</testsuite>") {
      suite_closed = 1
    } else if (tag ~ /^<testcase[ \t\/>]/) {
      if (in_case) xml_bad = 1
      in_case = 1; case_flags = ""
      case_name = xml_unescape(attr(tag, "name"))
      if (case_name == "") xml_bad = 1
      if (tag ~ /\/>$/) close_case()
    } else if (tag == "</testcase>") {
      if (!in_case) xml_bad = 1
      close_case()
    } else if (tag ~ /^<(flakyFailure|flakyError|rerunFailure|rerunError)[ \t\/>]/) {
      if (!in_case) xml_bad = 1
      case_flags = case_flags "R"
    } else if (tag ~ /^<failure[ \t\/>]/) {
      if (!in_case) xml_bad = 1
      case_flags = case_flags "F"
    } else if (tag ~ /^<error[ \t\/>]/) {
      if (!in_case) xml_bad = 1
      case_flags = case_flags "E"
    } else if (tag ~ /^<skipped[ \t\/>]/) {
      if (!in_case) xml_bad = 1
      # Mensaje de Cucumber para los escenarios que el filtro de tags excluye.
      if (attr(tag, "message") ~ /did not match this scenario$/) case_flags = case_flags "S"
      else case_flags = case_flags "O"
    }
  }
}

# ------------------------------------------------------------------ tipos
# Tipo de una lista de @AC-: "defecto-sut", "inestable", "mixto" (varios) o ""
# si alguno no tiene fila válida (se registra como rojo).
function type_of(list, who,    n, i, tmp, t, out) {
  n = split(list, tmp, " "); out = ""
  if (n == 0) { red(who ": escenario en cuarentena sin @AC-<DOMINIO>-<NN>"); return "" }
  for (i = 1; i <= n; i++) {
    if (!(tmp[i] in RT)) { red(who ": " tmp[i] " sin fila en " qfile " (CHK-14)"); return "" }
    t = RT[tmp[i]]
    if (t != "defecto-sut" && t != "inestable") { red(who ": " tmp[i] " con tipo desconocido en " qfile " (CHK-14)"); return "" }
    if (out == "") out = t
    else if (out != t) out = "mixto"
  }
  return out
}

# ------------------------------------------------------------------ lectura
FILENAME == qfile {
  sub(/\r$/, "")
  if ($0 ~ /^[ \t]*(```|~~~)/) { in_fence = !in_fence; tstate = 0; next }
  if (in_fence) next
  if ($0 ~ /^#[ \t]/ || $0 ~ /^##[ \t]/) {
    tstate = 0
    h = $0; sub(/^##?[ \t]+/, "", h)
    in_reg = ($0 ~ /^##[ \t]/ && trim(h) == "Registro")
    next
  }
  if (!in_reg) next
  if ($0 !~ /^[ \t]*\|/) { tstate = 0; next }
  if (tstate == 0) {
    n = cells($0); split("", col)
    for (i = 1; i <= n; i++) if (C[i] != "" && !(C[i] in col)) col[C[i]] = i
    tstate = ("Tipo" in col && "Escenario" in col) ? 1 : 3
    next
  }
  if (tstate == 1) { tstate = 2; next }
  if (tstate == 2) {
    n = cells($0)
    e = (col["Escenario"] <= n) ? C[col["Escenario"]] : ""
    t = (col["Tipo"] <= n) ? C[col["Tipo"]] : ""
    if (e ~ /^@AC-[A-Z]+-[0-9][0-9]$/) RT[e] = t
  }
  next
}

FILENAME == xmlfile {
  sub(/\r$/, "")
  xml_line(visible($0))
  next
}

FILENAME == logfile {
  sub(/\r$/, "")
  if ($0 ~ /Tests run: [0-9]+, Failures: [0-9]+, Errors: [0-9]+, Skipped: [0-9]+, Time elapsed: .* -- in com\.demo\.runners\.RunnerTest$/) {
    s = $0; sub(/^.*Tests run: /, "", s)
    split(s, p, ", ")
    L_tests = p[1]; L_fail = p[2]; L_err = p[3]; L_skip = p[4]
    sub(/^Failures: /, "", L_fail); sub(/^Errors: /, "", L_err); sub(/^Skipped: /, "", L_skip)
    L_tests += 0; L_fail += 0; L_err += 0; L_skip += 0
    log_line = 1
  }
  if ($0 ~ /^\[INFO\] BUILD SUCCESS$/) build_success = 1
  if ($0 ~ /^\[INFO\] BUILD FAILURE$/) build_failure = 1
  # Con fallos o errores de prueba, Maven falla en el goal de Surefire.
  if ($0 ~ /^\[ERROR\] Failed to execute goal org\.apache\.maven\.plugins:maven-surefire-plugin:[^ ]*:test /) surefire_failed = 1
  next
}

# Features (mismo análisis de etiquetas que scripts/check-quarantine.sh).
FNR == 1 {
  close_outline()
  cur = FILENAME
  pending = ""; feature_tags = ""; rule_tags = ""; in_doc = 0; outline_open = 0; n_examples = 0
}
{
  sub(/\r$/, "")
  t = trim($0)
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
    outline_open = 1; n_examples = 0
    outline_tags = feature_tags " " rule_tags " " pending; pending = ""
    next
  }
  if (t ~ /^(Scenario|Example):/) {
    close_outline()
    title = t; sub(/^(Scenario|Example):[ \t]*/, "", title)
    scenario(trim(title), feature_tags " " rule_tags " " pending, FNR); pending = ""
    next
  }
  if (t ~ /^(Examples|Scenarios):/) {
    if (outline_open) { n_examples++; outline_unit(outline_tags " " pending) }
    pending = ""
    next
  }
}

END {
  close_outline()
  if (nqs == 0 && !q_outline)
    red("no hay escenarios con @quarantine en las features: no hay nada que evaluar")

  # --- XML y log: ¿la ejecución midió algo y es esta ejecución?
  xml_ok = 0
  if (xmlfile == "") {
    red("no se generó " xmlname " (rc de Maven " mvn_rc "): Maven falló antes de las pruebas, p. ej. en la compilación")
  } else if (in_cdata || xml_bad || !suite_seen || !suite_closed || in_case) {
    red(xmlname " truncado o con estructura no reconocida")
  } else if (S_tests !~ /^[0-9]+$/ || S_fail !~ /^[0-9]+$/ || S_err !~ /^[0-9]+$/ || S_skip !~ /^[0-9]+$/) {
    red(xmlname " sin los contadores tests/failures/errors/skipped")
  } else {
    xml_ok = 1
    S_tests += 0; S_fail += 0; S_err += 0; S_skip += 0
  }
  if (!log_line) {
    red("el log de Maven no tiene la línea \"Tests run … -- in com.demo.runners.RunnerTest\": las pruebas no corrieron o el XML no es de esta ejecución")
  } else if (xml_ok && (L_tests != S_tests || L_fail != S_fail || L_err != S_err || L_skip != S_skip)) {
    red("el log (Tests run " L_tests ", Failures " L_fail ", Errors " L_err ", Skipped " L_skip ") no coincide con el XML (tests " S_tests ", failures " S_fail ", errors " S_err ", skipped " S_skip "): XML de otra ejecución")
  }

  n_run = n_pass = n_fail = n_err = n_skipf = 0
  if (xml_ok) {
    for (i = 1; i <= ncase; i++) {
      r = CRES[i]
      if (r == "omitido-filtro") { n_skipf++; continue }
      if (r == "omitido-otro") { red("«" CNAME[i] "» omitido por otro motivo que el filtro de tags: no se midió"); continue }
      if (r == "reintento") { red("«" CNAME[i] "» tiene reintentos (flaky/rerun): prohibidos por CHK-02"); continue }
      if (r == "múltiple") { red("«" CNAME[i] "» con varios resultados en el XML"); continue }
      n_run++
      if (r == "falla") n_fail++
      else if (r == "error") n_err++
      else n_pass++
    }
    if (ncase != S_tests || n_fail != S_fail || n_err != S_err)
      red("los <testcase> del XML (" ncase ") no cuadran con sus contadores (tests " S_tests ", failures " S_fail ", errors " S_err ")")
    if (n_run == 0) red("no se ejecutó ningún escenario @quarantine")

    # rc de Maven frente al resultado.
    if (mvn_rc == 0) {
      if (n_fail + n_err > 0) red("Maven terminó con rc 0 pero el XML tiene fallos o errores")
      if (!build_success) red("Maven terminó con rc 0 sin \"BUILD SUCCESS\" en el log")
    } else if (mvn_rc == 1) {
      if (n_fail + n_err == 0) red("Maven terminó con rc 1 sin fallos de prueba en el XML: falló por otra causa")
      else if (!surefire_failed || !build_failure) red("Maven terminó con rc 1 sin \"BUILD FAILURE\" por el goal test de Surefire en el log: falló por otra causa")
    } else {
      red("rc de Maven inesperado: " mvn_rc)
    }

    # Cada escenario simple en cuarentena se ejecutó.
    for (i = 1; i <= ncase; i++) if (CRES[i] != "omitido-filtro") EXEC[CNAME[i]] = 1
    for (i = 1; i <= nqs; i++)
      if (!(QS_name[i] in EXEC)) red(QS_loc[i] ": «" QS_name[i] "» está en cuarentena y no se ejecutó")
  }

  # --- Lectura de cada escenario ejecutado.
  aviso = 0
  nrow = 0
  if (xml_ok) {
    for (i = 1; i <= ncase; i++) {
      r = CRES[i]; name = CNAME[i]
      if (r != "falla" && r != "error" && r != "pasa") continue
      lst = ""
      if (name in QNAME) lst = QNAME[name]
      else if (name ~ /^Example #[0-9]+\.[0-9]+$/ && q_outline) lst = Q_OUTLINE_ACS
      if (name in QNAME || (name ~ /^Example #[0-9]+\.[0-9]+$/ && q_outline)) tipo = type_of(lst, "«" name "»")
      else {
        red("«" name "» se ejecutó y no está en cuarentena: el filtro de tags no se aplicó")
        tipo = ""
      }
      nrow++; ROW_N[nrow] = name; ROW_T[nrow] = (tipo == "" ? "?" : tipo); ROW_R[nrow] = r
      # <error> (excepción o timeout, no aserción). Solo un `inestable` puro lo
      # tolera, con aviso (decisión del usuario, 2026-10-13): su causa raíz es
      # justamente lo que está en diagnóstico. En un `defecto-sut`, un tipo
      # mixto o sin clasificar es rojo: la cuarentena no mide el criterio.
      if (r == "error" && tipo == "inestable") {
        ROW_L[nrow] = "error tolerado (inestable): aviso"; aviso = 1
        NOTE[++nnote] = "warning|inestable con error:" lst " («" name "») terminó con error (excepción o timeout, no aserción); es `inestable`, así que no rompe el job: revisar su diagnóstico y su límite en docs/quarantine.md."
        continue
      }
      if (r == "error") { n_err_red++; ROW_L[nrow] = "error real: no mide el criterio"; continue }
      if (tipo == "") { ROW_L[nrow] = "sin clasificar"; continue }
      if (tipo == "defecto-sut" && r == "falla") {
        ROW_L[nrow] = "fallo esperado"
        NOTE[++nnote] = "notice|Fallo esperado (defecto-sut): «" name "» falla por aserción mientras el SUT no se corrija (docs/quarantine.md)."
      } else if (tipo == "defecto-sut") {
        ROW_L[nrow] = "PASA: revisar la spec y la cuarentena"; aviso = 1
        NOTE[++nnote] = "warning|defecto-sut que pasa: «" name "». El SUT pudo haberse corregido: revisar la spec y la cuarentena (docs/quarantine.md)."
      } else if (tipo == "inestable" && r == "falla") {
        ROW_L[nrow] = "informativo (inestable)"
        NOTE[++nnote] = "notice|inestable: «" name "» falló por aserción; sigue en cuarentena hasta corregir su causa raíz (docs/quarantine.md)."
      } else if (tipo == "inestable") {
        ROW_L[nrow] = "informativo (inestable)"
        NOTE[++nnote] = "notice|inestable: «" name "» pasó; un verde aislado no la saca de la cuarentena (docs/quarantine.md)."
      } else if (r == "falla") {
        ROW_L[nrow] = "fallo esperado o informativo (tipo mixto)"
        NOTE[++nnote] = "notice|«" name "» falla por aserción; su tipo (defecto-sut o inestable) no se distingue por nombre (docs/quarantine.md)."
      } else {
        ROW_L[nrow] = "PASA: revisar la cuarentena (tipo mixto)"; aviso = 1
        NOTE[++nnote] = "warning|«" name "» pasa y podría ser un defecto-sut (su tipo no se distingue por nombre): revisar la spec y la cuarentena (docs/quarantine.md)."
      }
    }
    if (n_err_red > 0) red(n_err_red " escenario(s) en cuarentena terminaron con error (excepción o timeout, no aserción) sin ser `inestable`: la cuarentena no mide el criterio")
  }

  # --- Salida.
  verdict = (nred > 0) ? "ROJO" : (aviso ? "VERDE CON AVISO" : "VERDE")
  for (i = 1; i <= nnote; i++) {
    split(NOTE[i], q, "|")
    emit(q[1], substr(NOTE[i], length(q[1]) + 2))
  }
  for (i = 1; i <= nred; i++) emit("error", RED[i])
  print me ": " verdict ": ejecutados=" n_run " fallaron=" n_fail " errores=" n_err " pasaron=" n_pass " (rc de Maven " mvn_rc ")"

  if (sumfile != "") {
    print "### Escenarios en cuarentena (CHK-14): " verdict >> sumfile
    print "" >> sumfile
    print "| Ejecutados | Fallaron (aserción) | Errores | Pasaron | rc de Maven |" >> sumfile
    print "|---|---|---|---|---|" >> sumfile
    print "| " n_run " | " n_fail " | " n_err " | " n_pass " | " mvn_rc " |" >> sumfile
    if (nrow > 0) {
      print "" >> sumfile
      print "| Escenario | Tipo | Resultado | Lectura |" >> sumfile
      print "|---|---|---|---|" >> sumfile
      for (i = 1; i <= nrow; i++)
        print "| " cell(ROW_N[i]) " | " ROW_T[i] " | " ROW_R[i] " | " ROW_L[i] " |" >> sumfile
    }
    if (nred > 0) {
      print "" >> sumfile
      print "**Errores reales:**" >> sumfile
      for (i = 1; i <= nred; i++) print "- " cell(RED[i]) >> sumfile
    }
    close(sumfile)
  }

  if (nred > 0) exit 1
  exit (aviso ? 3 : 0)
}
' "${args[@]}" || rc=$?

case "$rc" in
  0|1|3) exit "$rc" ;;
  *) err "error interno de awk (rc $rc)" ;;
esac
