#!/usr/bin/env bash
# Autoprueba de scripts/evaluate-quarantine-run.sh (CHK-14, job `quarantine`).
#
# Uso: bash scripts/tests/evaluate-quarantine-run-test.sh
#
# Cada caso crea en un temporal fuera del repositorio (mktemp -d) un árbol
# mínimo (features, docs/quarantine.md, XML sintético de Surefire y log de
# Maven) y exige:
#   - el código de salida esperado (0 verde, 3 verde con aviso, 1 rojo, 2 uso);
#   - una línea esperada en la salida estándar (o en stderr para rc 2);
#   - con rc 0 y 3, ninguna línea "ERROR:"; con rc 0, 1 y 3, stderr vacío.
#
# evaluate-quarantine-run.sh no invoca git. Aun así, git queda aislado de la
# configuración del usuario y sin mantenimiento automático (como
# check-layers-test.sh) por si una versión futura del script lo usara.
#
# Sale con 0 solo si todos los casos se comportan como se espera; con 1 si
# alguno falla; con 2 ante un error de preparación. Imprime la tabla
# caso → esperado → real. El temporal se borra al salir (trap).
set -euo pipefail
export LC_ALL=C

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
script="$here/../evaluate-quarantine-run.sh"
repo_root="$(cd "$here/../.." && pwd -P)"
if [ ! -f "$script" ]; then
  echo "evaluate-quarantine-run-test: no existe $script" >&2
  exit 2
fi

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_CONFIG_PARAMETERS
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
    echo "evaluate-quarantine-run-test: el temporal $tmp está dentro del repositorio" >&2
    exit 2
    ;;
esac
export GIT_CEILING_DIRECTORIES="$tmp"

F=src/test/resources/features
X=target/surefire-reports/TEST-com.demo.runners.RunnerTest.xml
SKIPF="<skipped message=\"&apos;cucumber.filter.tags=@quarantine&apos; did not match this scenario\"/>"

# ------------------------------------------------------------------ fixtures
n_case=0
# new: árbol con una feature (un escenario normal y uno en cuarentena) y el
# registro con AC-COMPRA-09 como defecto-sut. Deja su ruta en $d.
new() {
  n_case=$((n_case + 1))
  d="$tmp/c$n_case"
  mkdir -p "$d/$F" "$d/docs" "$d/target/surefire-reports"
  feat a.feature \
    'Feature: Compra' \
    '  @e2e @AC-COMPRA-01' \
    '  Scenario: Normal' \
    '    Given algo' \
    '' \
    '  @e2e @quarantine @AC-COMPRA-09' \
    '  Scenario: Defecto conocido' \
    '    Given algo'
  registry '| defecto-sut | `@AC-COMPRA-09` |'
}

feat() {
  local path="$d/$F/$1"
  shift
  printf '%s\n' "$@" > "$path"
}

# registry <filas…>: docs/quarantine.md con una tabla por tipo.
registry() {
  {
    printf '%s\n' '# Cuarentena' '' '## Registro' '' '| Tipo | Escenario |' '|---|---|'
    printf '%s\n' "$@"
  } > "$d/docs/quarantine.md"
}

# xml <tests> <failures> <errors> <skipped> <líneas de testcase…>
xml() {
  local t="$1" f="$2" e="$3" s="$4"
  shift 4
  {
    printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
    printf '%s\n' "<testsuite xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" version=\"3.0.2\" name=\"com.demo.runners.RunnerTest\" time=\"1.0\" tests=\"$t\" errors=\"$e\" skipped=\"$s\" failures=\"$f\">"
    printf '%s\n' '  <properties>' '    <property name="java.version" value="17"/>' '  </properties>'
    printf '%s\n' "$@"
    printf '%s\n' '</testsuite>'
  } > "$d/$X"
}

# Fragmentos de <testcase>.
tc_skip() { printf '%s\n' "  <testcase name=\"$1\" classname=\"com.demo.runners.RunnerTest\" time=\"0.0\">" "    $SKIPF" '  </testcase>'; }
tc_pass() { printf '%s\n' "  <testcase name=\"$1\" classname=\"com.demo.runners.RunnerTest\" time=\"1.0\"/>"; }
tc_fail() {
  printf '%s\n' "  <testcase name=\"$1\" classname=\"com.demo.runners.RunnerTest\" time=\"1.0\">" \
    '    <failure message="esperado ==&gt; expected: &lt;false&gt; but was: &lt;true&gt;" type="org.opentest4j.AssertionFailedError"><![CDATA[org.opentest4j.AssertionFailedError' \
    '	at com.demo.steps.X.y(X.java:1)' \
    ']]></failure>' \
    '    <system-out><![CDATA[@e2e @quarantine' \
    ']]></system-out>' \
    '  </testcase>'
}
tc_error() {
  printf '%s\n' "  <testcase name=\"$1\" classname=\"com.demo.runners.RunnerTest\" time=\"10.0\">" \
    '    <error message="Expected condition failed" type="org.openqa.selenium.TimeoutException"><![CDATA[org.openqa.selenium.TimeoutException' \
    ']]></error>' \
    '  </testcase>'
}

# log <rc-de-build: success|failure|tests-failure|compile> [tests f e s]
log() {
  local kind="$1" level="[INFO]"
  {
    printf '%s\n' '[INFO] Scanning for projects...'
    if [ "$kind" = compile ]; then
      printf '%s\n' '[ERROR] COMPILATION ERROR :' '[INFO] BUILD FAILURE' \
        '[ERROR] Failed to execute goal org.apache.maven.plugins:maven-compiler-plugin:3.13.0:testCompile'
    else
      if [ "$3" != 0 ] || [ "$4" != 0 ]; then level="[ERROR]"; fi
      printf '%s\n' "$level Tests run: $2, Failures: $3, Errors: $4, Skipped: $5, Time elapsed: 1.0 s -- in com.demo.runners.RunnerTest"
      case "$kind" in
        success) printf '%s\n' '[INFO] BUILD SUCCESS' ;;
        failure) printf '%s\n' '[INFO] BUILD FAILURE' '[ERROR] Failed to execute goal some.plugin:goal' ;;
        tests-failure) printf '%s\n' '[INFO] BUILD FAILURE' \
          '[ERROR] Failed to execute goal org.apache.maven.plugins:maven-surefire-plugin:3.5.3:test (default-test) on project p: There are test failures.' ;;
      esac
    fi
  } > "$d/maven.log"
}

# ------------------------------------------------------------------ runner
fails=0
results=()
# check <nombre> <rc esperado> <línea esperada (fija)> [opciones y argumentos del script]
check() {
  local name="$1" want_rc="$2" want="$3"
  shift 3
  local out err got_rc=0
  out="$(cd "$d" && bash "$script" "$@" 2> "$tmp/stderr")" || got_rc=$?
  err="$(cat "$tmp/stderr")"
  local ok=1 why=""
  if [ "$got_rc" != "$want_rc" ]; then ok=0; why="rc $got_rc"; fi
  if [ "$want_rc" = 2 ]; then
    case "$err" in *"$want"*) ;; *) ok=0; why="$why; stderr sin «$want»" ;; esac
  else
    case "$out" in *"$want"*) ;; *) ok=0; why="$why; stdout sin «$want»" ;; esac
    [ -z "$err" ] || { ok=0; why="$why; stderr no vacío"; }
  fi
  if [ "$want_rc" = 0 ] || [ "$want_rc" = 3 ]; then
    if printf '%s\n' "$out" | grep -qE '^(ERROR: |::error::)'; then ok=0; why="$why; error en un caso verde"; fi
  fi
  if [ "$ok" = 1 ]; then
    results+=("ok    | $name | rc $want_rc")
  else
    fails=$((fails + 1))
    results+=("FALLA | $name | esperado rc $want_rc, real:${why}")
    printf '%s\n' "--- $name: salida" "$out" "--- stderr" "$err" >&2
  fi
}

# out <argumentos del script>: su salida estándar, cualquiera que sea su rc
# (con pipefail, "script | grep" daría falso con rc 1 o 3 aunque grep coincida).
out() { (cd "$d" && bash "$script" "$@" 2>/dev/null) || true; }

# ------------------------------------------------------------------ casos
# 1. defecto-sut que falla por aserción: lo esperado.
new
xml 2 1 0 1 "$(tc_skip Normal)" "$(tc_fail 'Defecto conocido')"
log tests-failure 2 1 0 1
check "defecto-sut falla por aserción" 0 'NOTA: Fallo esperado (defecto-sut): «Defecto conocido»' 1 maven.log

# 2. defecto-sut que pasa: aviso (rc 3).
new
xml 2 0 0 1 "$(tc_skip Normal)" "$(tc_pass 'Defecto conocido')"
log success 2 0 0 1
check "defecto-sut pasa" 3 'AVISO: defecto-sut que pasa: «Defecto conocido»' 0 maven.log

# 3. Error (excepción o timeout, no aserción).
new
xml 2 0 1 1 "$(tc_skip Normal)" "$(tc_error 'Defecto conocido')"
log tests-failure 2 0 1 1
check "error no aserción" 1 'ERROR: 1 escenario(s) en cuarentena terminaron con error' 1 maven.log

# 3b. Solo errores: Surefire falla sin "There are test failures" (log real).
new
xml 2 0 1 1 "$(tc_skip Normal)" "$(tc_error 'Defecto conocido')"
log tests-failure 2 0 1 1
sed -i 's/ There are test failures\.$/ /' "$d/maven.log"
check "solo errores, sin otra causa" 1 'ERROR: 1 escenario(s) en cuarentena terminaron con error' 1 maven.log
if out 1 maven.log | grep -q 'falló por otra causa'; then
  fails=$((fails + 1)); results+=("FALLA | solo errores | atribuye el fallo a otra causa")
else
  results+=("ok    | solo errores | sin falsa «otra causa»")
fi

# 4. Cero ejecutados.
new
xml 2 0 0 2 "$(tc_skip Normal)" "$(tc_skip 'Defecto conocido')"
log success 2 0 0 2
check "cero ejecutados" 1 'ERROR: no se ejecutó ningún escenario @quarantine' 0 maven.log

# 5. Sin XML: falló la compilación.
new
log compile
check "sin XML (compilación)" 1 'ERROR: no se generó target/surefire-reports/TEST-com.demo.runners.RunnerTest.xml (rc de Maven 1)' 1 maven.log

# 6. rc 1 sin fallos de prueba: Maven falló por otra causa.
new
xml 2 0 0 1 "$(tc_skip Normal)" "$(tc_pass 'Defecto conocido')"
log failure 2 0 0 1
check "rc 1 sin fallos de prueba" 1 'ERROR: Maven terminó con rc 1 sin fallos de prueba en el XML' 1 maven.log

# 7. rc 0 con un fallo en el XML.
new
xml 2 1 0 1 "$(tc_skip Normal)" "$(tc_fail 'Defecto conocido')"
log success 2 1 0 1
check "rc 0 con fallos" 1 'ERROR: Maven terminó con rc 0 pero el XML tiene fallos o errores' 0 maven.log

# 8. Log sin la línea Tests run de RunnerTest (XML de otra ejecución).
new
xml 2 1 0 1 "$(tc_skip Normal)" "$(tc_fail 'Defecto conocido')"
log compile
check "log sin Tests run" 1 'ERROR: el log de Maven no tiene la línea' 1 maven.log

# 9. Log con números distintos del XML.
new
xml 2 1 0 1 "$(tc_skip Normal)" "$(tc_fail 'Defecto conocido')"
log tests-failure 3 1 0 2
check "log distinto del XML" 1 'no coincide con el XML' 1 maven.log

# 10. Omitido por otro motivo que el filtro.
new
xml 2 0 0 2 "$(tc_skip Normal)" \
  "  <testcase name=\"Defecto conocido\" classname=\"c\" time=\"0.0\">" '    <skipped message="aborted"/>' '  </testcase>'
log success 2 0 0 2
check "omitido por otro motivo" 1 'ERROR: «Defecto conocido» omitido por otro motivo que el filtro de tags' 0 maven.log

# 11. Filtro roto: se ejecuta un escenario fuera de la cuarentena.
new
xml 2 1 0 0 "$(tc_pass Normal)" "$(tc_fail 'Defecto conocido')"
log tests-failure 2 1 0 0
check "escenario fuera de la cuarentena" 1 'ERROR: «Normal» se ejecutó y no está en cuarentena' 1 maven.log

# 12. Reintento (CHK-02).
new
xml 2 0 0 1 "$(tc_skip Normal)" \
  "  <testcase name=\"Defecto conocido\" classname=\"c\" time=\"1.0\">" '    <flakyFailure message="m" type="t"/>' '  </testcase>'
log success 2 0 0 1
check "reintento flaky" 1 'ERROR: «Defecto conocido» tiene reintentos' 0 maven.log

# 13. XML truncado.
new
xml 2 1 0 1 "$(tc_skip Normal)" "$(tc_fail 'Defecto conocido')"
head -n 8 "$d/$X" > "$d/x.tmp" && mv "$d/x.tmp" "$d/$X"
log tests-failure 2 1 0 1
check "XML truncado" 1 'truncado o con estructura no reconocida' 1 maven.log

# 14. rc de Maven distinto de 0 y 1.
new
xml 2 1 0 1 "$(tc_skip Normal)" "$(tc_fail 'Defecto conocido')"
log tests-failure 2 1 0 1
check "rc 130" 1 'ERROR: rc de Maven inesperado: 130' 130 maven.log

# 15. inestable que falla: informativo.
new
registry '| inestable | `@AC-COMPRA-09` |'
xml 2 1 0 1 "$(tc_skip Normal)" "$(tc_fail 'Defecto conocido')"
log tests-failure 2 1 0 1
check "inestable falla" 0 'NOTA: inestable: «Defecto conocido» falló por aserción' 1 maven.log

# 16. inestable que pasa: informativo, sin aviso.
new
registry '| inestable | `@AC-COMPRA-09` |'
xml 2 0 0 1 "$(tc_skip Normal)" "$(tc_pass 'Defecto conocido')"
log success 2 0 0 1
check "inestable pasa" 0 'NOTA: inestable: «Defecto conocido» pasó; un verde aislado' 0 maven.log

# 17. Outline en cuarentena: sus filas se llaman "Example #N.M".
new
feat b.feature \
  'Feature: Login' \
  '  @quarantine @AC-LOGIN-05' \
  '  Scenario Outline: Varios' \
  '    Given <x>' \
  '    Examples:' \
  '      | x |' \
  '      | 1 |'
registry '| defecto-sut | `@AC-COMPRA-09` |' '| defecto-sut | `@AC-LOGIN-05` |'
xml 3 2 0 1 "$(tc_skip Normal)" "$(tc_fail 'Defecto conocido')" "$(tc_fail 'Example #1.1')"
log tests-failure 3 2 0 1
check "Outline en cuarentena" 0 'NOTA: Fallo esperado (defecto-sut): «Example #1.1»' 1 maven.log

# 18. Outline con dos @AC- de tipos distintos que pasa: aviso (tipo mixto).
new
feat b.feature \
  'Feature: Login' \
  '  @quarantine' \
  '  Scenario Outline: Varios' \
  '    Given <x>' \
  '    @AC-LOGIN-05' \
  '    Examples:' \
  '      | x |' \
  '      | 1 |' \
  '    @AC-LOGIN-06' \
  '    Examples:' \
  '      | x |' \
  '      | 2 |'
registry '| defecto-sut | `@AC-COMPRA-09` |' '| defecto-sut | `@AC-LOGIN-05` |' '| inestable | `@AC-LOGIN-06` |'
xml 3 1 0 1 "$(tc_skip Normal)" "$(tc_fail 'Defecto conocido')" "$(tc_pass 'Example #2.1')"
log tests-failure 3 1 0 1
check "tipo mixto pasa" 3 'AVISO: «Example #2.1» pasa y podría ser un defecto-sut' 1 maven.log

# 19. @AC- en cuarentena sin fila en el registro.
new
registry '| defecto-sut | `@AC-COMPRA-77` |'
xml 2 1 0 1 "$(tc_skip Normal)" "$(tc_fail 'Defecto conocido')"
log tests-failure 2 1 0 1
check "@AC sin fila" 1 'ERROR: «Defecto conocido»: @AC-COMPRA-09 sin fila en docs/quarantine.md' 1 maven.log

# 20. Etiquetas falsas dentro de CDATA (salida capturada): se ignoran.
new
xml 2 1 0 1 "$(tc_skip Normal)" \
  "  <testcase name=\"Defecto conocido\" classname=\"c\" time=\"1.0\">" \
  '    <failure message="m" type="t"><![CDATA[x</failure></testcase><testcase name="Normal"><error message="e"/>' \
  ']]></failure>' \
  '    <system-out><![CDATA[<error message="spoof"/>]]></system-out>' \
  '    <system-err><![CDATA[' '<testcase name="Otro">' ']]></system-err>' \
  '  </testcase>'
log tests-failure 2 1 0 1
check "etiquetas dentro de CDATA" 0 'NOTA: Fallo esperado (defecto-sut): «Defecto conocido»' 1 maven.log

# 21. Nombre con entidades XML.
new
feat a.feature \
  'Feature: Compra' \
  '  @quarantine @AC-COMPRA-09' \
  "  Scenario: Compra \"rápida\" & <sin> 'carrito'" \
  '    Given algo'
xml 1 1 0 0 "$(tc_fail 'Compra &quot;rápida&quot; &amp; &lt;sin&gt; &apos;carrito&apos;')"
log tests-failure 1 1 0 0
check "nombre con entidades XML" 0 "«Compra \"rápida\" & <sin> 'carrito'» falla por aserción" 1 maven.log

# 22. @quarantine heredado de la Feature.
new
feat a.feature \
  '@quarantine @AC-COMPRA-09' \
  'Feature: Compra' \
  '  Scenario: Defecto conocido' \
  '    Given algo'
xml 1 1 0 0 "$(tc_fail 'Defecto conocido')"
log tests-failure 1 1 0 0
check "@quarantine heredado" 0 'NOTA: Fallo esperado (defecto-sut): «Defecto conocido»' 1 maven.log

# 23. Mensaje de <failure> partido en varias líneas: cuenta igual.
new
xml 2 1 0 1 "$(tc_skip Normal)" \
  "  <testcase name=\"Defecto conocido\" classname=\"c\" time=\"1.0\">" \
  '    <failure message="línea 1' 'línea 2" type="t"/>' \
  '  </testcase>'
log tests-failure 2 1 0 1
check "failure en varias líneas" 0 'NOTA: Fallo esperado (defecto-sut)' 1 maven.log

# 23b. <testcase> partido en varias líneas: sus atributos no son fiables.
new
xml 2 1 0 1 "$(tc_skip Normal)" \
  '  <testcase name="Defecto conocido"' '    classname="c" time="1.0">' \
  '    <failure message="m" type="t"/>' \
  '  </testcase>'
log tests-failure 2 1 0 1
check "testcase en varias líneas" 1 'truncado o con estructura no reconocida' 1 maven.log

# 24. rc 1 con fallo, pero Maven falló en otro goal: otra causa.
new
xml 2 1 0 1 "$(tc_skip Normal)" "$(tc_fail 'Defecto conocido')"
log failure 2 1 0 1
check "rc 1 sin fallo de Surefire" 1 'sin "BUILD FAILURE" por el goal test de Surefire' 1 maven.log

# 25. Escenario en cuarentena ausente del XML.
new
feat c.feature \
  'Feature: Otra' \
  '  @quarantine @AC-COMPRA-09' \
  '  Scenario: Segundo defecto' \
  '    Given algo'
xml 2 1 0 1 "$(tc_skip Normal)" "$(tc_fail 'Defecto conocido')"
log tests-failure 2 1 0 1
check "en cuarentena sin ejecutar" 1 '«Segundo defecto» está en cuarentena y no se ejecutó' 1 maven.log

# 26. Sin @quarantine en las features.
new
feat a.feature 'Feature: Compra' '  Scenario: Normal' '    Given algo'
xml 1 0 0 0 "$(tc_pass Normal)"
log success 1 0 0 0
check "sin @quarantine" 1 'ERROR: no hay escenarios con @quarantine' 0 maven.log

# 27. XML con contadores que no cuadran con sus <testcase>.
new
xml 3 1 0 1 "$(tc_skip Normal)" "$(tc_fail 'Defecto conocido')"
log tests-failure 3 1 0 1
check "contadores sin cuadrar" 1 'no cuadran con sus contadores' 1 maven.log

# 28. Formato GitHub y resumen Markdown.
new
xml 2 1 0 1 "$(tc_skip Normal)" "$(tc_fail 'Defecto conocido')"
log tests-failure 2 1 0 1
check "anotación de GitHub" 0 '::notice::Fallo esperado (defecto-sut): «Defecto conocido»' --github --summary summary.md 1 maven.log
n_case_sum="$d"
if grep -qxF '| Defecto conocido | defecto-sut | falla | fallo esperado |' "$n_case_sum/summary.md" \
   && grep -qxF '### Escenarios en cuarentena (CHK-14): VERDE' "$n_case_sum/summary.md"; then
  results+=("ok    | resumen Markdown | fila del escenario")
else
  fails=$((fails + 1)); results+=("FALLA | resumen Markdown | sin la fila esperada")
fi

# ---- <error> según el tipo (decisión del usuario, 2026-10-13): un
# `inestable` con error es verde con aviso; un `defecto-sut`, un tipo mixto o
# sin clasificar con error, y cualquier fallo de infraestructura, son rojo.

# 30. inestable con error: verde con aviso que nombra el @AC- y el tipo.
new
registry '| inestable | `@AC-COMPRA-09` |'
xml 2 0 1 1 "$(tc_skip Normal)" "$(tc_error 'Defecto conocido')"
log tests-failure 2 0 1 1
check "inestable con error" 3 'AVISO: inestable con error: @AC-COMPRA-09 («Defecto conocido») terminó con error' 1 maven.log
if out 1 maven.log | grep -qF 'terminaron con error'; then
  fails=$((fails + 1)); results+=("FALLA | inestable con error | lo cuenta como error real")
else
  results+=("ok    | inestable con error | no lo cuenta como error real")
fi

# 30b. Lo mismo con solo errores y sin "There are test failures" (log real).
new
registry '| inestable | `@AC-COMPRA-09` |'
xml 2 0 1 1 "$(tc_skip Normal)" "$(tc_error 'Defecto conocido')"
log tests-failure 2 0 1 1
sed -i 's/ There are test failures\.$/ /' "$d/maven.log"
check "inestable con error, log real" 3 'AVISO: inestable con error: @AC-COMPRA-09' 1 maven.log

# 30c. Formato GitHub y resumen Markdown del aviso.
new
registry '| inestable | `@AC-COMPRA-09` |'
xml 2 0 1 1 "$(tc_skip Normal)" "$(tc_error 'Defecto conocido')"
log tests-failure 2 0 1 1
check "inestable con error, GitHub" 3 '::warning::inestable con error: @AC-COMPRA-09 («Defecto conocido»)' --github --summary summary.md 1 maven.log
if grep -qxF '| Defecto conocido | inestable | error | error tolerado (inestable): aviso |' "$d/summary.md" \
   && grep -qxF '### Escenarios en cuarentena (CHK-14): VERDE CON AVISO' "$d/summary.md"; then
  results+=("ok    | resumen Markdown | inestable con error")
else
  fails=$((fails + 1)); results+=("FALLA | resumen Markdown | inestable con error sin la fila esperada")
fi

# 31. Dos inestables, uno falla por aserción y otro con error: verde con aviso.
new
feat c.feature \
  'Feature: Otra' \
  '  @quarantine @AC-LOGIN-03' \
  '  Scenario: Intermitente' \
  '    Given algo'
registry '| inestable | `@AC-COMPRA-09` |' '| inestable | `@AC-LOGIN-03` |'
xml 3 1 1 1 "$(tc_skip Normal)" "$(tc_fail 'Defecto conocido')" "$(tc_error 'Intermitente')"
log tests-failure 3 1 1 1
check "inestable aserción + inestable error" 3 'AVISO: inestable con error: @AC-LOGIN-03 («Intermitente»)' 1 maven.log
if out 1 maven.log | grep -qF 'NOTA: inestable: «Defecto conocido» falló por aserción'; then
  results+=("ok    | inestable aserción + error | nota de la aserción")
else
  fails=$((fails + 1)); results+=("FALLA | inestable aserción + error | sin la nota de la aserción")
fi

# 32. defecto-sut con error e inestable con error: rojo (y el aviso del inestable).
new
feat c.feature \
  'Feature: Otra' \
  '  @quarantine @AC-LOGIN-03' \
  '  Scenario: Intermitente' \
  '    Given algo'
registry '| defecto-sut | `@AC-COMPRA-09` |' '| inestable | `@AC-LOGIN-03` |'
xml 3 0 2 1 "$(tc_skip Normal)" "$(tc_error 'Defecto conocido')" "$(tc_error 'Intermitente')"
log tests-failure 3 0 2 1
check "defecto-sut error + inestable error" 1 'ERROR: 1 escenario(s) en cuarentena terminaron con error' 1 maven.log
if out 1 maven.log | grep -qF 'AVISO: inestable con error: @AC-LOGIN-03'; then
  results+=("ok    | defecto-sut error + inestable error | aviso del inestable")
else
  fails=$((fails + 1)); results+=("FALLA | defecto-sut error + inestable error | sin el aviso del inestable")
fi

# 33. Outline con @AC- de tipos distintos que termina con error: rojo (el tipo
# no se distingue por nombre; falla cerrado).
new
feat b.feature \
  'Feature: Login' \
  '  @quarantine' \
  '  Scenario Outline: Varios' \
  '    Given <x>' \
  '    @AC-LOGIN-05' \
  '    Examples:' \
  '      | x |' \
  '      | 1 |' \
  '    @AC-LOGIN-06' \
  '    Examples:' \
  '      | x |' \
  '      | 2 |'
registry '| defecto-sut | `@AC-COMPRA-09` |' '| defecto-sut | `@AC-LOGIN-05` |' '| inestable | `@AC-LOGIN-06` |'
xml 3 1 1 1 "$(tc_skip Normal)" "$(tc_fail 'Defecto conocido')" "$(tc_error 'Example #2.1')"
log tests-failure 3 1 1 1
check "tipo mixto con error" 1 'ERROR: 1 escenario(s) en cuarentena terminaron con error' 1 maven.log

# 34. inestable con error pero sin fila en el registro: rojo.
new
registry '| inestable | `@AC-COMPRA-77` |'
xml 2 0 1 1 "$(tc_skip Normal)" "$(tc_error 'Defecto conocido')"
log tests-failure 2 0 1 1
check "inestable con error sin fila" 1 'ERROR: «Defecto conocido»: @AC-COMPRA-09 sin fila en docs/quarantine.md' 1 maven.log

# 35. Fallos de infraestructura con un registro inestable: siguen en rojo.
# 35a. Maven no compila (sin XML).
new
registry '| inestable | `@AC-COMPRA-09` |'
log compile
check "infra: sin XML (inestable)" 1 'ERROR: no se generó target/surefire-reports/TEST-com.demo.runners.RunnerTest.xml' 1 maven.log

# 35b. rc de Maven inesperado con un inestable con error.
new
registry '| inestable | `@AC-COMPRA-09` |'
xml 2 0 1 1 "$(tc_skip Normal)" "$(tc_error 'Defecto conocido')"
log tests-failure 2 0 1 1
check "infra: rc 137 (inestable con error)" 1 'ERROR: rc de Maven inesperado: 137' 137 maven.log

# 35c. rc 0 con un inestable con error en el XML.
new
registry '| inestable | `@AC-COMPRA-09` |'
xml 2 0 1 1 "$(tc_skip Normal)" "$(tc_error 'Defecto conocido')"
log success 2 0 1 1
check "infra: rc 0 con error (inestable)" 1 'ERROR: Maven terminó con rc 0 pero el XML tiene fallos o errores' 0 maven.log

# 35d. rc 1 con un inestable con error, pero Maven falló en otro goal.
new
registry '| inestable | `@AC-COMPRA-09` |'
xml 2 0 1 1 "$(tc_skip Normal)" "$(tc_error 'Defecto conocido')"
log failure 2 0 1 1
check "infra: otro goal (inestable con error)" 1 'sin "BUILD FAILURE" por el goal test de Surefire' 1 maven.log

# 35e. Log de otra ejecución (sin la línea Tests run) con un inestable con error.
new
registry '| inestable | `@AC-COMPRA-09` |'
xml 2 0 1 1 "$(tc_skip Normal)" "$(tc_error 'Defecto conocido')"
log compile
check "infra: log sin Tests run (inestable)" 1 'ERROR: el log de Maven no tiene la línea' 1 maven.log

# 29. Errores de uso (rc 2).
new
xml 2 1 0 1 "$(tc_skip Normal)" "$(tc_fail 'Defecto conocido')"
log tests-failure 2 1 0 1
check "rc no numérico" 2 "el rc de Maven 'x' no es un entero" x maven.log
check "log inexistente" 2 "el log 'no.log' no existe" 1 no.log
check "sin argumentos" 2 'uso:'
rm "$d/docs/quarantine.md"
check "sin registro" 2 'docs/quarantine.md no existe' 1 maven.log

# ------------------------------------------------------------------ informe
printf '%s\n' "${results[@]}"
total="${#results[@]}"
if [ "$fails" -ne 0 ]; then
  echo "evaluate-quarantine-run-test: $fails de $total casos fallaron"
  exit 1
fi
echo "evaluate-quarantine-run-test: $total casos ok"
exit 0
