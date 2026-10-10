#!/usr/bin/env bash
# Autoprueba de CHK-17 (scripts/check-layers.sh; ADR-002, D6).
#
# Uso: bash scripts/tests/check-layers-test.sh
#
# Crea en un directorio temporal fuera del repositorio (mktemp -d) un repo git
# mínimo que reproduce las capas, y exige:
#   - exit 0 sobre el árbol válido, que incluye casi-violaciones permitidas
#     (import de By en pages, ConfigReader en pages, constructor de acciones
#     con páginas, JUnit en las unitarias, Javadoc que nombra SecretReader);
#   - exit 1, con la línea "archivo:línea: R<n>: motivo" esperada, por cada
#     comando de D7 y por la ampliación de R3, con la violación versionada y
#     sin versionar;
#   - exit 1 con una violación en un archivo versionado que coincide con
#     .gitignore, y exit 0 si ese archivo no está versionado;
#   - exit 1 ("directorio:0: D6: …") por cada directorio de capa ausente o
#     sin archivos versionados;
#   - exit 2 cuando no se puede evaluar: raíz que no es repo, subdirectorio,
#     raíz inexistente, argumentos de más, índice corrupto y configuración
#     inválida (git grep rc >= 2) y archivo ilegible (stderr de git grep).
# Así una expresión regular rota no deja pasar todo en silencio.
#
# Sale con 0 solo si todos los casos se comportan como se espera; con 1 si
# alguno falla; con 2 ante un error de preparación. Imprime la tabla
# caso → esperado → real. El temporal se borra al salir (trap).
set -euo pipefail
export LC_ALL=C

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
script="$here/../check-layers.sh"
repo_root="$(cd "$here/../.." && pwd -P)"
if [ ! -f "$script" ]; then
  echo "check-layers-test: no existe $script" >&2
  exit 2
fi

# Git aislado de la configuración del usuario y del sistema (hooks, firma,
# grep.*, color) y de variables que redirigen el repositorio.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE GIT_COMMON_DIR
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=autoprueba GIT_AUTHOR_EMAIL=autoprueba@localhost
export GIT_COMMITTER_NAME=autoprueba GIT_COMMITTER_EMAIL=autoprueba@localhost

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
tmp="$(cd "$tmp" && pwd -P)"
case "$tmp/" in
  "$repo_root"/*)
    echo "check-layers-test: el temporal $tmp está dentro del repositorio" >&2
    exit 2
    ;;
esac
# Git no busca repositorios por encima del temporal: el caso "no es repo"
# no depende de dónde esté /tmp.
export GIT_CEILING_DIRECTORIES="$tmp"

T=src/test/java/com/demo

# put <ruta> <líneas…>: escribe un archivo, una línea por argumento.
put() {
  local path="$1"
  shift
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$@" > "$path"
}

# ---------------------------------------------------------------- árbol válido
base="$tmp/base"
mkdir -p "$base"
(
  cd "$base"
  git init -q .

  put src/main/java/com/demo/config/ConfigResolver.java \
    'package com.demo.config;' \
    'public final class ConfigResolver {' \
    '}'
  put src/main/java/com/demo/config/SecretResolver.java \
    'package com.demo.config;' \
    'public final class SecretResolver {' \
    '}'
  put src/main/java/com/demo/data/Credentials.java \
    'package com.demo.data;' \
    'public record Credentials(String username, String password) {' \
    '}'

  put "$T/transport/Navegador.java" \
    'package com.demo.transport;' \
    '' \
    'import org.openqa.selenium.By;' \
    'import org.openqa.selenium.JavascriptExecutor;' \
    'import org.openqa.selenium.WebDriver;' \
    'import com.demo.config.ConfigResolver;' \
    'import com.demo.utils.ConfigReader;' \
    '' \
    'public final class Navegador {' \
    '    private WebDriver driver;' \
    '    public Navegador() {' \
    '    }' \
    '    public void click(By locator) {' \
    '        ((JavascriptExecutor) driver).executeScript("arguments[0].click();", driver.findElement(locator));' \
    '    }' \
    '    public String texto(By locator) {' \
    '        return driver.findElement(locator).getText();' \
    '    }' \
    '}'
  put "$T/transport/DriverFactory.java" \
    'package com.demo.transport;' \
    '' \
    'import org.openqa.selenium.WebDriver;' \
    'import org.openqa.selenium.chrome.ChromeOptions;' \
    '' \
    'final class DriverFactory {' \
    '    static WebDriver crear() {' \
    '        ChromeOptions opciones = new ChromeOptions();' \
    '        return null;' \
    '    }' \
    '}'

  put "$T/pages/LoginPage.java" \
    'package com.demo.pages;' \
    '' \
    'import org.openqa.selenium.By;' \
    'import com.demo.transport.Navegador;' \
    'import com.demo.utils.ConfigReader;' \
    '' \
    '/** Página de inicio de sesión: compone Navegador. */' \
    'public final class LoginPage {' \
    '    private static final By USUARIO = By.id("user-name");' \
    '    private final Navegador navegador;' \
    '    public LoginPage(Navegador navegador) {' \
    '        this.navegador = navegador;' \
    '    }' \
    '    public void iniciarSesion(String usuario, String clave) {' \
    '        navegador.click(USUARIO);' \
    '    }' \
    '    public String obtenerMensajeError() {' \
    '        return navegador.texto(USUARIO);' \
    '    }' \
    '}'
  put "$T/pages/InventoryPage.java" \
    'package com.demo.pages;' \
    '' \
    'import org.openqa.selenium.By;' \
    'import com.demo.transport.Navegador;' \
    '' \
    'public final class InventoryPage {' \
    '    private static final By TITULO = By.className("title");' \
    '    private final Navegador navegador;' \
    '    public InventoryPage(Navegador navegador) {' \
    '        this.navegador = navegador;' \
    '    }' \
    '    public String obtenerTitulo() {' \
    '        return navegador.texto(TITULO);' \
    '    }' \
    '}'

  # Constructor con páginas (permitido, D3) y método privado con página.
  put "$T/actions/LoginActions.java" \
    'package com.demo.actions;' \
    '' \
    'import com.demo.data.Credentials;' \
    'import com.demo.pages.InventoryPage;' \
    'import com.demo.pages.LoginPage;' \
    '' \
    'public final class LoginActions {' \
    '    private final LoginPage loginPage;' \
    '    private final InventoryPage inventoryPage;' \
    '    public LoginActions(LoginPage loginPage, InventoryPage inventoryPage) {' \
    '        this.loginPage = loginPage;' \
    '        this.inventoryPage = inventoryPage;' \
    '    }' \
    '    public void iniciarSesion(Credentials credentials) {' \
    '        usar(loginPage, credentials);' \
    '    }' \
    '    public String obtenerTituloCatalogo() {' \
    '        return inventoryPage.obtenerTitulo();' \
    '    }' \
    '    private void usar(LoginPage pagina, Credentials credentials) {' \
    '        pagina.iniciarSesion(credentials.username(), credentials.password());' \
    '    }' \
    '}'

  put "$T/steps/LoginSteps.java" \
    'package com.demo.steps;' \
    '' \
    'import static org.junit.jupiter.api.Assertions.assertEquals;' \
    'import io.cucumber.java.en.Then;' \
    'import com.demo.actions.LoginActions;' \
    'import com.demo.data.Credentials;' \
    'import com.demo.utils.ConfigReader;' \
    'import com.demo.utils.CredentialsProvider;' \
    'import com.demo.utils.TestContext;' \
    '' \
    'public class LoginSteps {' \
    '    private final LoginActions login;' \
    '    public LoginSteps(LoginActions login) {' \
    '        this.login = login;' \
    '    }' \
    '    @Then("accede al inventario")' \
    '    public void accede() {' \
    '        assertEquals(ConfigReader.get("inventory.expected.title"), login.obtenerTituloCatalogo());' \
    '    }' \
    '}'

  put "$T/hooks/Hooks.java" \
    'package com.demo.hooks;' \
    '' \
    'import io.cucumber.java.After;' \
    'import io.cucumber.java.Before;' \
    'import com.demo.transport.Navegador;' \
    'import com.demo.utils.TestContext;' \
    '' \
    'public class Hooks {' \
    '}'

  put "$T/utils/ConfigReader.java" \
    'package com.demo.utils;' \
    'import com.demo.config.ConfigResolver;' \
    'public final class ConfigReader {' \
    '}'
  put "$T/utils/SecretReader.java" \
    'package com.demo.utils;' \
    'import com.demo.config.SecretResolver;' \
    'public final class SecretReader {' \
    '}'
  put "$T/utils/CredentialsProvider.java" \
    'package com.demo.utils;' \
    'import com.demo.data.Credentials;' \
    'public final class CredentialsProvider {' \
    '    private final SecretReader secretos = new SecretReader();' \
    '}'
  put "$T/utils/TestContext.java" \
    'package com.demo.utils;' \
    'public final class TestContext {' \
    '}'

  put "$T/runners/RunnerTest.java" \
    'package com.demo.runners;' \
    '' \
    'import static io.cucumber.junit.platform.engine.Constants.GLUE_PROPERTY_NAME;' \
    'import org.junit.platform.suite.api.ConfigurationParameter;' \
    'import org.junit.platform.suite.api.Suite;' \
    '' \
    '@Suite' \
    '@ConfigurationParameter(key = GLUE_PROPERTY_NAME, value = "com.demo.steps,com.demo.hooks")' \
    'public class RunnerTest {' \
    '}'

  put "$T/config/ConfigResolverTest.java" \
    'package com.demo.config;' \
    'import org.junit.jupiter.api.Test;' \
    '/** No usa SecretReader ni CredentialsProvider (excepción de D6). */' \
    'class ConfigResolverTest {' \
    '    @Test' \
    '    void resuelve() {' \
    '    }' \
    '}'
  put "$T/data/CredentialsTest.java" \
    'package com.demo.data;' \
    'import org.junit.jupiter.api.Test;' \
    '/** No usa CredentialsProvider. */' \
    'class CredentialsTest {' \
    '    @Test' \
    '    void crea() {' \
    '    }' \
    '}'

  git add -A
  git -c commit.gpgsign=false commit -q -m base
) || { echo "check-layers-test: no se pudo crear el repositorio base" >&2; exit 2; }

# ------------------------------------------------------------------- arnés
n=0
total=0
fails=0
table=""
dir=""
rc=0
out=""

new_case() {
  n=$((n + 1))
  dir="$tmp/case-$n"
  cp -a "$base" "$dir"
}

run_script() {
  rc=0
  out="$(bash "$script" "$@" 2>&1)" || rc=$?
}

# expect <caso> <exit esperado> [línea exacta que debe aparecer en la salida]
# Con el prefijo "re:", la línea es una expresión regular extendida (grep -E).
expect() {
  local name="$1" want="$2" needle="${3:-}" verdict=ok
  [ "$rc" -eq "$want" ] || verdict=FALLA
  total=$((total + 1))
  # Here-string y no tubería: con pipefail, grep -q podría cortar printf (SIGPIPE).
  case "$needle" in
    "") ;;
    re:*) grep -qE -- "${needle#re:}" <<<"$out" || verdict=FALLA ;;
    *) grep -qxF -- "$needle" <<<"$out" || verdict=FALLA ;;
  esac
  if [ "$verdict" != ok ]; then
    fails=$((fails + 1))
    {
      echo "--- FALLA: $name (esperado $want, real $rc)"
      [ -z "$needle" ] || echo "    línea esperada: $needle"
      printf '%s\n' "$out" | sed 's/^/    | /'
    } >&2
  fi
  table="${table}$(printf '| %-74s | %8s | %4s | %-5s |' "$name" "$want" "$rc" "$verdict")"$'\n'
}

# violation <id> <regla> <motivo> <archivo> <línea>: una vez versionada (en el
# índice) y otra sin versionar; la línea queda en la línea 2 del archivo.
violation() {
  local id="$1" rule="$2" reason="$3" file="$4" line="$5" mode
  for mode in versionada sin-versionar; do
    new_case
    put "$dir/$file" 'package com.demo.prueba;' "$line"
    if [ "$mode" = versionada ]; then
      git -C "$dir" add -- "$file"
    fi
    run_script "$dir"
    expect "$id $rule ${file#"$T/"} ($mode)" 1 "$file:2: $rule: $reason"
  done
}

# allowed <id> <archivo> <línea>: casi-violación permitida, en ambos modos.
allowed() {
  local id="$1" file="$2" line="$3" mode
  for mode in versionada sin-versionar; do
    new_case
    put "$dir/$file" 'package com.demo.prueba;' "$line"
    if [ "$mode" = versionada ]; then
      git -C "$dir" add -- "$file"
    fi
    run_script "$dir"
    expect "$id ${file#"$T/"} ($mode)" 0 "check-layers: ok: CHK-17 (R1–R6) sin violaciones"
  done
}

# ------------------------------------------------------------------- casos
# Árbol válido
new_case
run_script "$dir"
expect "valido: árbol mínimo con las capas" 0 "check-layers: ok: CHK-17 (R1–R6) sin violaciones"

# Casi-violaciones permitidas
allowed "ok-1 constructor de acciones con páginas" "$T/actions/OtraActions.java" \
  '    public OtraActions(LoginPage loginPage, InventoryPage inventoryPage) {'
allowed "ok-2 método no público de acciones con página" "$T/actions/OtraActions.java" \
  '    void usar(LoginPage pagina) {'
allowed "ok-3 import de By en pages" "$T/pages/OtraPage.java" \
  'import org.openqa.selenium.By;'

# Un caso negativo por comando de D7 (D7-01…D7-19 son los git grep; D7-20 es
# la presencia de directorios) y por la ampliación de R3 (R3-param).
violation "D7-01" R1 "Selenium fuera de transport y pages" \
  "$T/steps/Bad.java" 'import static org.openqa.selenium.Keys.ENTER;'
violation "D7-01b" R1 "Selenium fuera de transport y pages" \
  "$T/utils/Bad.java" '    private org.openqa.selenium.WebDriver driver;'
violation "D7-01c" R1 "Selenium fuera de transport y pages" \
  "src/main/java/com/demo/config/Bad.java" 'import org.openqa.selenium.By;'
violation "D7-02" R1 "en pages solo se permite 'import org.openqa.selenium.By;'" \
  "$T/pages/BadPage.java" 'import org.openqa.selenium.WebElement;'
violation "D7-03" R1 "tipo de Selenium en una firma pública del transporte" \
  "$T/transport/Bad.java" '    public WebElement buscar(By locator) {'
violation "D7-03b" R1 "tipo de Selenium en una firma pública del transporte" \
  "$T/transport/Bad.java" '    public ChromeOptions opciones() {'
violation "D7-04" R1 "By en una firma pública de una página" \
  "$T/pages/BadPage.java" '    public void pulsar(By locator) {'
violation "D7-05" R3 "steps nombran pages o transport" \
  "$T/steps/Bad.java" 'import com.demo.pages.LoginPage;'
violation "D7-05b" R3 "steps nombran pages o transport" \
  "$T/steps/Bad.java" 'import com.demo.transport.Navegador;'
violation "D7-06" R3 "página en el tipo de retorno de un método público de actions" \
  "$T/actions/Bad.java" '    public LoginPage pagina() {'
violation "R3-param" R3 "página como parámetro de un método público de actions" \
  "$T/actions/Bad.java" '    public void usar(LoginPage pagina) {'
violation "R3-param-b" R3 "página como parámetro de un método público de actions" \
  "$T/actions/Bad.java" '    public static void usarTodas(java.util.List<com.demo.pages.CartPage> paginas) {'
violation "R3-param-c" R3 "página como parámetro de un método público de actions" \
  "$T/actions/Bad.java" '    public void usar(@Deprecated(since = "1") InventoryPage pagina) {'
violation "D7-07" R4 "JUnit fuera de steps, runners y las pruebas unitarias" \
  "$T/actions/Bad.java" 'import org.junit.jupiter.api.Assertions;'
violation "D7-08" R4 "Cucumber fuera de steps, hooks y runners" \
  "$T/pages/BadPage.java" 'import io.cucumber.java.en.Given;'
violation "D7-09" R4 "clave *.expected* en transport, pages o actions" \
  "$T/pages/BadPage.java" '    private static final String CLAVE = "cart.expected.count";'
violation "D7-09b" R4 "clave *.expected* en transport, pages o actions" \
  "$T/actions/Bad.java" '    private static final String CLAVE = "checkout.expected.confirmation";'
violation "D7-10" R5 "findElement(s) o executeScript fuera de transport" \
  "$T/pages/BadPage.java" '        driver.findElements(USUARIO);'
violation "D7-10b" R5 "findElement(s) o executeScript fuera de transport" \
  "$T/hooks/Bad.java" '        executor.executeScript(script);'
violation "D7-10c" R5 "findElement(s) o executeScript fuera de transport" \
  "$T/steps/Bad.java" '        executor.executeAsyncScript(script);'
violation "D7-11" R5 "una página extiende una clase" \
  "$T/pages/BadPage.java" 'public final class BadPage extends BasePage {'
violation "D7-12" R6 "transport nombra un paquete fuera de su fila de D4" \
  "$T/transport/Bad.java" 'import com.demo.pages.LoginPage;'
violation "D7-13" R6 "transport o pages nombran utils distinto de ConfigReader" \
  "$T/pages/BadPage.java" 'import com.demo.utils.TestContext;'
violation "D7-13b" R6 "transport o pages nombran utils distinto de ConfigReader" \
  "$T/transport/Bad.java" 'import com.demo.utils.ConfigReaderX;'
violation "D7-14" R6 "pages nombra un paquete fuera de su fila de D4" \
  "$T/pages/BadPage.java" 'import com.demo.actions.LoginActions;'
violation "D7-15" R6 "actions nombra un paquete fuera de su fila de D4" \
  "$T/actions/Bad.java" 'import com.demo.utils.ConfigReader;'
violation "D7-16" R6 "steps nombra un paquete fuera de su fila de D4" \
  "$T/steps/Bad.java" 'import com.demo.hooks.Hooks;'
violation "D7-17" R6 "utils nombra un paquete fuera de su fila de D4" \
  "$T/utils/Bad.java" 'import com.demo.pages.LoginPage;'
violation "D7-18" R6 "hooks nombra un paquete fuera de su fila de D4" \
  "$T/hooks/Bad.java" 'import com.demo.steps.LoginSteps;'
violation "D7-19" R6 "SecretReader o CredentialsProvider fuera de utils y steps" \
  "$T/actions/Bad.java" '    // Un comentario que nombra SecretReader también cuenta (D6).'

# Archivos que coinciden con .gitignore: --untracked omite incluso los
# versionados (git 2.53), así que el script hace también una pasada sobre el
# índice. Uno versionado e ignorado se detecta; uno sin versionar e ignorado
# no se va a subir y se omite.
new_case
put "$dir/.gitignore" 'Ignorado*.java'
put "$dir/$T/steps/IgnoradoBad.java" 'package com.demo.prueba;' 'import org.openqa.selenium.WebDriver;'
git -C "$dir" add -f -- .gitignore "$T/steps/IgnoradoBad.java"
run_script "$dir"
expect "D7-01 steps/IgnoradoBad.java (versionada e ignorada)" 1 \
  "$T/steps/IgnoradoBad.java:2: R1: Selenium fuera de transport y pages"
new_case
put "$dir/.gitignore" 'Ignorado*.java'
put "$dir/$T/steps/IgnoradoBad.java" 'package com.demo.prueba;' 'import org.openqa.selenium.WebDriver;'
git -C "$dir" add -- .gitignore
run_script "$dir"
expect "ok-4 steps/IgnoradoBad.java (sin versionar e ignorada)" 0 \
  "check-layers: ok: CHK-17 (R1–R6) sin violaciones"

# D7-20: directorios de capa ausentes (1: violación de estructura, no error)
for layer in transport pages actions steps; do
  new_case
  git -C "$dir" rm -r -q -- "$T/$layer"
  run_script "$dir"
  expect "D7-20 directorio $layer ausente" 1 "$T/$layer:0: D6: directorio de capa sin archivos versionados"
done
new_case
git -C "$dir" rm -r -q --cached -- "$T/actions"
run_script "$dir"
expect "D7-20 directorio actions solo con archivos sin versionar" 1 \
  "$T/actions:0: D6: directorio de capa sin archivos versionados"

# No se puede evaluar: 2 (falla cerrado)
new_case
rm -rf "$dir/.git"
run_script "$dir"
expect "error: la raíz no es un repositorio git" 2

new_case
run_script "$dir/src"
expect "error: la raíz es un subdirectorio del repositorio" 2

run_script "$tmp/no-existe"
expect "error: la raíz no existe" 2

new_case
run_script "$dir" extra
expect "error: argumentos de más" 2

new_case
printf 'indice corrupto\n' > "$dir/.git/index"
run_script "$dir"
# El mensaje distingue el rc >= 2 de git grep del de git ls-files, que
# también fallaría con el índice corrupto.
expect "error: git grep termina con rc >= 2 (índice corrupto)" 2 \
  're:^check-layers: ERROR: git grep terminó con [0-9]+ '

new_case
git -C "$dir" config grep.threads no-numerico
run_script "$dir"
expect "error: git grep termina con rc >= 2 (configuración inválida)" 2 \
  're:^check-layers: ERROR: git grep terminó con [0-9]+ '

# git grep imprime "failed to stat" y termina con 0 o 1 ante un archivo
# ilegible: el script lo trata como error por la salida en stderr. Como root
# el archivo sigue siendo legible, así que el caso no aplica.
if [ "$(id -u)" -ne 0 ]; then
  new_case
  put "$dir/$T/steps/Ilegible.java" 'package com.demo.prueba;'
  git -C "$dir" add -- "$T/steps/Ilegible.java"
  chmod 000 "$dir/$T/steps/Ilegible.java"
  run_script "$dir"
  chmod 644 "$dir/$T/steps/Ilegible.java"
  expect "error: archivo ilegible (git grep escribe en stderr)" 2 \
    're:^check-layers: ERROR: git grep terminó con [0-9]+ '
else
  table="${table}$(printf '| %-74s | %8s | %4s | %-5s |' "error: archivo ilegible (no aplica como root)" "2" "-" "n/a")"$'\n'
fi

# ------------------------------------------------------------------- resumen
printf '| %-74s | %8s | %4s | %-5s |\n' "Caso" "Esperado" "Real" "Resultado"
printf '|%s|%s|%s|%s|\n' "$(printf -- '-%.0s' $(seq 1 76))" "----------" "------" "-------"
printf '%s' "$table"
if [ "$fails" -ne 0 ]; then
  echo "check-layers-test: FALLA: $fails de $total casos no se comportan como se espera"
  exit 1
fi
echo "check-layers-test: ok: $total casos"
