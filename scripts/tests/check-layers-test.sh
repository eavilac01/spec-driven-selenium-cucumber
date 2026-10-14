#!/usr/bin/env bash
# Autoprueba de CHK-17 (scripts/check-layers.sh; ADR-002, D6).
#
# Uso: bash scripts/tests/check-layers-test.sh
#
# Crea en un directorio temporal fuera del repositorio (mktemp -d) un repo git
# mínimo que reproduce las capas, y exige:
#   - exit 0 sobre el árbol válido, que incluye casi-violaciones permitidas
#     (import de By en pages, ConfigReader en pages, constructor de acciones
#     con páginas, JUnit en las unitarias, Javadoc que nombra SecretReader,
#     ResultadoClic público en transport y solo dentro de una página);
#   - exit 1, con la línea "archivo:línea: R<n>: motivo" esperada, por cada
#     comando de D7, por la ampliación de R3 y por la restricción de
#     ResultadoClic de D1, con la violación versionada y sin versionar; las
#     comprobaciones de firmas y tipos (Firmas expuestas, D7) tienen además un
#     caso en la columna 0, con anotación, con otro modificador y con
#     protected, y los elementos de MOD los suyos (EXP-*); la unión por imports
#     (R1-imp, R1-her), R1-wild, R1-by y R5-ext (Selenium en el transporte y
#     herencia, D7) tienen casos de una línea y de dos (import en la 2 y
#     declaración en la 3); R5-js, R5-evt, R5-clic y R5-clic-max (Clic nativo
#     único, scripts cerrados y preferencias de Chrome, D7, parte 4) tienen un
#     caso por alternativa, como R5-esc y R5-esc-max (Escritura única, parte
#     5), y D8-prefs reescribe la línea de preferencias del
#     DriverFactory.java del árbol base (o borra el archivo) y espera
#     "archivo:0: D8: …"; las reglas de contract y de sus páginas locales
#     (A4-*, Pruebas de contrato del transporte, D7, parte 6; ADR-004, D8)
#     tienen un caso por alternativa de RED, FIX y de la fila de D4 de
#     contract, y casi-violaciones permitidas (A4-ok-*);
#   - exit 1 con una violación en un archivo versionado que coincide con
#     .gitignore, y exit 0 si ese archivo no está versionado;
#   - exit 1 ("directorio:0: D6: …") por cada directorio de capa ausente o
#     sin archivos versionados;
#   - exit 2, con el mensaje de error esperado, cuando no se puede evaluar:
#     raíz que no es repo, subdirectorio (también uno con su propio árbol de
#     capas y una violación fuera de él), raíz inexistente, argumentos de más,
#     índice corrupto y configuración inválida (git grep rc >= 2), git grep que
#     termina con rc >= 2 sin escribir en stderr (shim de git en el PATH),
#     archivo ilegible (stderr de git grep), el awk de la unión que sale con 3
#     (shim de awk), el git grep de HER que falla dentro de la unión, y el de
#     check_max (CLIC) y el de require (PREFS) que fallan sin stderr.
# Antes de copiar el repo base, exige que git no lance mantenimiento ni gc
# automáticos (config efectiva, traza del commit con un control positivo, sin
# archivos efímeros) y que un cp que pierde un archivo efímero salga con 2.
# Así una expresión regular rota no deja pasar todo en silencio. Cada
# alternativa de una expresión regular de D7 tiene su caso negativo: quitar una
# alternativa hace fallar al menos un caso.
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
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE GIT_COMMON_DIR \
  GIT_CONFIG_PARAMETERS GIT_TRACE
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null
# Sin mantenimiento ni gc automáticos. Tras un commit, git lanza
# "git maintenance run --auto --detach" en segundo plano (también git 2.53);
# ese proceso crea y borra .git/objects/maintenance.lock mientras cp copia el
# repositorio base (falló en CI con git 2.55: "cp: cannot stat …lock").
# Por entorno (GIT_CONFIG_COUNT) y no con "git config" en el repo base:
#   - vale para todo git que lance la autoprueba (también check-layers.sh y el
#     shim), antes de "git init" y en los casos que rompen o borran .git;
#   - tiene prioridad de línea de comandos: la config local de un caso no lo
#     reactiva, y no se copia como parte del árbol que se evalúa.
# Los autoDetach=false hacen que, si algo lo lanzara igualmente, corra en
# primer plano y no en paralelo con la copia.
export GIT_CONFIG_COUNT=4
export GIT_CONFIG_KEY_0=maintenance.auto GIT_CONFIG_VALUE_0=false
export GIT_CONFIG_KEY_1=gc.auto GIT_CONFIG_VALUE_1=0
export GIT_CONFIG_KEY_2=maintenance.autoDetach GIT_CONFIG_VALUE_2=false
export GIT_CONFIG_KEY_3=gc.autoDetach GIT_CONFIG_VALUE_3=false
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
    '        elemento.click();' \
    '    }' \
    '    public void escribir(By locator, String texto) {' \
    '        elemento.clear();' \
    '        elemento.sendKeys(texto);' \
    '    }' \
    '    public void desplazarA(By locator) {' \
    '        ((JavascriptExecutor) driver).executeScript(SCRIPT_DESPLAZAR_AL_CENTRO, driver.findElement(locator));' \
    '    }' \
    '    private Object leerCodigoPaginaError() {' \
    '        return ((JavascriptExecutor) driver).executeScript(SCRIPT_LEER_CODIGO_PAGINA_ERROR);' \
    '    }' \
    '    public String texto(By locator) {' \
    '        return driver.findElement(locator).getText();' \
    '    }' \
    '    public enum ResultadoClic { AVANZO, NO_AVANZO, NO_DISPONIBLE }' \
    '    public ResultadoClic clickYObservarUrlContiene(By locator, String fragmento) {' \
    '        return ResultadoClic.AVANZO;' \
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
    '        options.setExperimentalOption("prefs", settings.chromePreferences());' \
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

  # ResultadoClic solo dentro de la página: variable local en un método público
  # y método privado que lo devuelve (D1, enmienda 2026-10-13).
  put "$T/pages/CartPage.java" \
    'package com.demo.pages;' \
    '' \
    'import org.openqa.selenium.By;' \
    'import com.demo.transport.Navegador;' \
    '' \
    'public final class CartPage {' \
    '    private static final By TRAMITAR = By.id("checkout");' \
    '    private final Navegador navegador;' \
    '    public CartPage(Navegador navegador) {' \
    '        this.navegador = navegador;' \
    '    }' \
    '    /** Exige que avance; no expone el {@link Navegador.ResultadoClic}. */' \
    '    public void iniciarCheckout() {' \
    '        Navegador.ResultadoClic resultado = pulsarTramitar();' \
    '        if (resultado != Navegador.ResultadoClic.AVANZO) {' \
    '            throw new IllegalStateException("no avanzó");' \
    '        }' \
    '    }' \
    '    private Navegador.ResultadoClic pulsarTramitar() {' \
    '        return navegador.clickYObservarUrlContiene(TRAMITAR, "checkout");' \
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

  # Pruebas de contrato del transporte (D7, parte 6; ADR-004, D8): Selenium (By)
  # y JUnit en contract, y una página local con un contador de clics, para que
  # el árbol válido dé 0 con las reglas A4-* y 1 si se quita una exclusión.
  put "$T/contract/NavegadorContractTest.java" \
    'package com.demo.contract;' \
    '' \
    'import org.openqa.selenium.By;' \
    'import org.junit.jupiter.api.Test;' \
    'import com.demo.transport.Navegador;' \
    'import com.demo.utils.ConfigReader;' \
    '' \
    'class NavegadorContractTest {' \
    '    private static final By ACCION = By.id("accion");' \
    '    private final Navegador navegador = new Navegador();' \
    '    @Test' \
    '    void pulsaUnaVez() {' \
    '        navegador.click(ACCION);' \
    '    }' \
    '}'
  put src/test/resources/contract/inerte.html \
    '<!DOCTYPE html>' \
    '<button id="accion" onclick="contar()">Accion</button>' \
    '<p id="clics">0</p>' \
    "<script>let clics = 0; function contar() { document.getElementById('clics').textContent = String(++clics); }</script>"

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
  # La traza registra cada proceso que lanza el commit (caso de aislamiento).
  GIT_TRACE="$tmp/base-commit.trace" git -c commit.gpgsign=false commit -q -m base
) || { echo "check-layers-test: no se pudo crear el repositorio base" >&2; exit 2; }

# ------------------------------------------------------------------- arnés
n=0
total=0
fails=0
table=""
dir=""
rc=0
out=""

# Copia con cp -a (todo el árbol, versionado o no, y .git tal cual). Un fallo de
# copia es un error de preparación: 2, nunca un caso en verde.
new_case() {
  n=$((n + 1))
  dir="$tmp/case-$n"
  cp -a "$base" "$dir" || {
    echo "check-layers-test: no se pudo copiar el repositorio base al caso $n" >&2
    exit 2
  }
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

# violation2 <id> <regla> <motivo> <archivo> <línea 2> <línea 3>: import en la
# línea 2 y declaración en la 3; la violación esperada está en la línea 3.
violation2() {
  local id="$1" rule="$2" reason="$3" file="$4" l2="$5" l3="$6" mode
  for mode in versionada sin-versionar; do
    new_case
    put "$dir/$file" 'package com.demo.prueba;' "$l2" "$l3"
    if [ "$mode" = versionada ]; then
      git -C "$dir" add -- "$file"
    fi
    run_script "$dir"
    expect "$id $rule ${file#"$T/"} ($mode)" 1 "$file:3: $rule: $reason"
  done
}

# reemplazar <ruta> <línea exacta> [línea nueva]: sustituye esa línea del
# archivo, o la borra si no hay línea nueva. Si la línea no está, es un error de
# preparación (2): un caso así nunca puede quedar en verde.
reemplazar() {
  local path="$1" old="$2" found=0 line
  local nuevo="$tmp/reemplazo.tmp"
  : > "$nuevo"
  while IFS= read -r line; do
    if [ "$line" = "$old" ]; then
      found=1
      if [ "$#" -ge 3 ]; then
        printf '%s\n' "$3" >> "$nuevo"
      fi
    else
      printf '%s\n' "$line" >> "$nuevo"
    fi
  done < "$path"
  if [ "$found" -ne 1 ]; then
    echo "check-layers-test: no está la línea a sustituir en $path" >&2
    exit 2
  fi
  cat "$nuevo" > "$path"
}

# allowed2 <id> <archivo> <línea 2> <línea 3>: casi-violación de dos líneas.
allowed2() {
  local id="$1" file="$2" l2="$3" l3="$4" mode
  for mode in versionada sin-versionar; do
    new_case
    put "$dir/$file" 'package com.demo.prueba;' "$l2" "$l3"
    if [ "$mode" = versionada ]; then
      git -C "$dir" add -- "$file"
    fi
    run_script "$dir"
    expect "$id ${file#"$T/"} ($mode)" 0 "check-layers: ok: CHK-17 (R1–R6) sin violaciones"
  done
}

# ------------------------------------------------------------------- casos
# Aislamiento del mantenimiento de git (regresión de git 2.55). Van antes de la
# primera copia: si fallan, la autoprueba sale con 2 sin copiar nada.
for kv in maintenance.auto=false gc.auto=0 maintenance.autoDetach=false gc.autoDetach=false; do
  rc=0
  out="$(git -C "$base" config --show-scope --get "${kv%%=*}" 2>&1)" || rc=$?
  expect "aislamiento: $kv en el repo base (ámbito command)" 0 \
    "$(printf 'command\t%s' "${kv#*=}")"
done
# GIT_TRACE registra "run_command: git maintenance run --auto …" (o gc --auto)
# cuando el commit lo lanza. grep: 1 = no lo lanzó; 2 = sin traza (falla).
maint_re='run_command: git (maintenance run|gc)( .*)? --auto'
rc=0
out="$(grep -E -- "$maint_re" "$tmp/base-commit.trace" 2>&1)" || rc=$?
expect "aislamiento: el commit del repo base no lanza mantenimiento ni gc" 1
# Control: con -c maintenance.auto=true (precede al entorno) el mismo commit sí
# lo lanza, así que el caso anterior no pasa por una traza vacía. En primer
# plano (autoDetach=false del entorno) y en un repo que no se copia.
ctl="$tmp/control-mantenimiento"
mkdir -p "$ctl"
(
  cd "$ctl"
  git init -q .
  put f.txt 'control'
  git add -A
  GIT_TRACE="$tmp/control-commit.trace" \
    git -c commit.gpgsign=false -c maintenance.auto=true commit -q -m control
) || { echo "check-layers-test: no se pudo crear el repositorio de control" >&2; exit 2; }
rc=0
out="$(grep -E -- "$maint_re" "$tmp/control-commit.trace" 2>&1)" || rc=$?
expect "control: con maintenance.auto=true el commit sí lanza mantenimiento" 0
# Ningún archivo efímero de git en el repo base antes de copiarlo.
rc=0
out="$(find "$base/.git" \( -name '*.lock' -o -name gc.pid -o -name 'tmp_*' \
  -o -name 'incoming-*' \) -print 2>&1)" || rc=$?
[ -z "$out" ] || rc=1
expect "aislamiento: repo base sin archivos efímeros (*.lock, gc.pid, tmp_*)" 0
# Un cp que pierde un archivo efímero (lo que pasó en CI) falla cerrado con 2.
mkdir -p "$tmp/shim-cp"
printf '#!/usr/bin/env bash\necho "cp: cannot stat %s: No such file or directory" >&2\nexit 1\n' \
  "'$base/.git/objects/maintenance.lock'" > "$tmp/shim-cp/cp"
chmod +x "$tmp/shim-cp/cp"
rc=0
out="$( (PATH="$tmp/shim-cp:$PATH"; new_case) 2>&1)" || rc=$?
expect "regresión: cp pierde maintenance.lock durante la copia (sale con 2)" 2 \
  're:^check-layers-test: no se pudo copiar el repositorio base al caso [0-9]+$'
if [ "$fails" -ne 0 ]; then
  echo "check-layers-test: git no quedó aislado del mantenimiento automático; no se copia el repo base" >&2
  exit 2
fi

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
# ResultadoClic (D1): uso interno de una página, el enum público en transport y
# casi-coincidencias de cada parte de la expresión (^\s*, public\b, \b…\b).
allowed "ok-5 ResultadoClic en un método privado de una página" "$T/pages/OtraPage.java" \
  '    private Navegador.ResultadoClic pulsar() {'
allowed "ok-6 ResultadoClic en una variable local de una página" "$T/pages/OtraPage.java" \
  '        Navegador.ResultadoClic resultado = navegador.clickYObservarUrlContiene(TRAMITAR, "x");'
allowed "ok-7 ResultadoClic público en transport" "$T/transport/Otro.java" \
  '    public enum ResultadoClic { AVANZO, NO_AVANZO, NO_DISPONIBLE }'
allowed "ok-8 comentario de una página con public y ResultadoClic" "$T/pages/OtraPage.java" \
  '    // no es public: ResultadoClic queda dentro de la página'
allowed "ok-9 identificador que empieza por public en una página" "$T/pages/OtraPage.java" \
  '    publicar(Navegador.ResultadoClic.AVANZO);'
allowed "ok-10 método público con ResultadoClic como sufijo" "$T/pages/OtraPage.java" \
  '    public boolean esResultadoClic() {'
allowed "ok-11 método público con ResultadoClic como prefijo" "$T/pages/OtraPage.java" \
  '    public int ResultadoClicados() {'
# Firmas expuestas (D7, enmienda 2026-10-13): casi-coincidencias de EXP (MOD,
# modificador de acceso y \b final) y de TIPO (\b, \s+ y \w final).
allowed "ok-12 anotación y private en una página" "$T/pages/OtraPage.java" \
  '    @SuppressWarnings("unused") private Navegador.ResultadoClic pulsar() {'
allowed "ok-13 miembro de paquete con modificador en una página" "$T/pages/OtraPage.java" \
  '    static Navegador.ResultadoClic pulsar() {'
allowed "ok-14 variable local con final en una página" "$T/pages/OtraPage.java" \
  '        final Navegador.ResultadoClic resultado = pulsar();'
allowed "ok-15 identificador que termina en public en una página" "$T/pages/OtraPage.java" \
  '        boolean nonpublic = resultado == Navegador.ResultadoClic.AVANZO;'
allowed "ok-16 identificador que empieza por protected en una página" "$T/pages/OtraPage.java" \
  '        protectedMode(Navegador.ResultadoClic.AVANZO);'
allowed "ok-17 comentario de línea en una página" "$T/pages/OtraPage.java" \
  '    // @Override public Navegador.ResultadoClic pulsar() {'
allowed "ok-18 Javadoc en una página" "$T/pages/OtraPage.java" \
  '     * static public Navegador.ResultadoClic pulsar() no es API de la página'
allowed "ok-19 cadena en una página" "$T/pages/OtraPage.java" \
  '        String plantilla = "@Override public Navegador.ResultadoClic x()";'
allowed "ok-20 constructor anotado de acciones con páginas (D3)" "$T/actions/OtraActions.java" \
  '    @Inject public OtraActions(LoginPage loginPage) {'
allowed "ok-21 constructor protegido de acciones con páginas" "$T/actions/OtraActions.java" \
  '    protected OtraActions(LoginPage loginPage) {'
allowed "ok-22 método privado anotado de acciones con una página" "$T/actions/OtraActions.java" \
  '    @SuppressWarnings("unused") private void usar(LoginPage pagina) {'
allowed "ok-23 interfaz privada en transport" "$T/transport/Otro.java" \
  '    private interface Condicion { boolean cumple(); }'
allowed "ok-24 record de paquete en una página" "$T/pages/OtraPage.java" \
  '    record Fila(String nombre, int cantidad) {}'
allowed "ok-25 método que empieza por record en una página" "$T/pages/OtraPage.java" \
  '    public void recordar() {'
allowed "ok-26 campo llamado record en una página" "$T/pages/OtraPage.java" \
  '    public String record = "";'
allowed "ok-27 tipo que termina en record en una página" "$T/pages/OtraPage.java" \
  '    public void guardar(Autorecord registro) {'
# Selenium en el transporte y herencia (D7, enmienda 2026-10-13, parte 2):
# token completo, nombres por archivo, interfaces de Java e identificadores.
allowed2 "ok-28 token completo, no subcadena" "$T/transport/Otro.java" \
  'import org.openqa.selenium.WebDriver;' \
  '    public String nombreWebDriver(By localizador) {'
# ok-29: A.java importa Alert; B.java tiene su propio Alert (nombres por archivo).
for mode in versionada sin-versionar; do
  new_case
  put "$dir/$T/transport/A.java" 'package com.demo.prueba;' \
    'import org.openqa.selenium.Alert;' '    private Alert alerta;'
  put "$dir/$T/transport/B.java" 'package com.demo.prueba;' '    public Alert alerta() {'
  if [ "$mode" = versionada ]; then
    git -C "$dir" add -- "$T/transport/A.java" "$T/transport/B.java"
  fi
  run_script "$dir"
  expect "ok-29 nombres por archivo transport/A.java y B.java ($mode)" 0 \
    "check-layers: ok: CHK-17 (R1–R6) sin violaciones"
done
allowed2 "ok-30 interfaz de Java en transport" "$T/transport/Otro.java" \
  'import org.openqa.selenium.WebDriver;' \
  'public final class Cierre implements AutoCloseable {'
allowed "ok-31 implements de una interfaz de Java en actions" "$T/actions/OtraActions.java" \
  'public final class OtraActions implements java.util.function.Supplier<String> {'
allowed "ok-32 identificadores que contienen extends en utils" "$T/utils/Otro.java" \
  '        boolean noextends = extendsMenu;'
allowed "ok-33 comodín de Java en transport" "$T/transport/Otro.java" \
  'import java.util.*;'
allowed2 "ok-34 identificadores con implements y extends, y un nombre importado" "$T/transport/Otro.java" \
  'import org.openqa.selenium.WebDriver;' \
  '        WebDriver noimplements = extendsX;'

# Un caso negativo por comando de D7 (D7-01…D7-19 son los git grep; D7-20 es
# la presencia de directorios) y por la ampliación de R3 (R3-param).
violation "D7-01" R1 "Selenium fuera de transport, pages y contract" \
  "$T/steps/Bad.java" 'import static org.openqa.selenium.Keys.ENTER;'
violation "D7-01b" R1 "Selenium fuera de transport, pages y contract" \
  "$T/utils/Bad.java" '    private org.openqa.selenium.WebDriver driver;'
violation "D7-01c" R1 "Selenium fuera de transport, pages y contract" \
  "src/main/java/com/demo/config/Bad.java" 'import org.openqa.selenium.By;'
violation "D7-02" R1 "en pages solo se permite 'import org.openqa.selenium.By;'" \
  "$T/pages/BadPage.java" 'import org.openqa.selenium.WebElement;'
# El "$" de D7-02: el import de By solo se permite como línea completa.
violation "D7-02b" R1 "en pages solo se permite 'import org.openqa.selenium.By;'" \
  "$T/pages/BadPage.java" 'import org.openqa.selenium.By; import java.util.List;'
violation "D7-03" R1 "tipo de Selenium en una firma pública del transporte" \
  "$T/transport/Bad.java" '    public WebElement buscar(By locator) {'
violation "D7-03b" R1 "tipo de Selenium en una firma pública del transporte" \
  "$T/transport/Bad.java" '    public ChromeOptions opciones() {'
violation "D7-03c" R1 "tipo de Selenium en una firma pública del transporte" \
  "$T/transport/Bad.java" '    public SearchContext contexto() {'
violation "D7-03d" R1 "tipo de Selenium en una firma pública del transporte" \
  "$T/transport/Bad.java" '    public void ejecutar(JavascriptExecutor ejecutor) {'
violation "D7-03e" R1 "tipo de Selenium en una firma pública del transporte" \
  "$T/transport/Bad.java" '    public TakesScreenshot captura() {'
violation "D7-03f" R1 "tipo de Selenium en una firma pública del transporte" \
  "$T/transport/Bad.java" '    public Capabilities capacidades() {'
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
violation "D7-07" R4 "JUnit fuera de steps, runners, contract y las pruebas unitarias" \
  "$T/actions/Bad.java" 'import org.junit.jupiter.api.Assertions;'
violation "D7-08" R4 "Cucumber fuera de steps, hooks y runners" \
  "$T/pages/BadPage.java" 'import io.cucumber.java.en.Given;'
violation "D7-09" R4 "clave *.expected* en transport, pages o actions" \
  "$T/pages/BadPage.java" '    private static final String CLAVE = "cart.expected.count";'
violation "D7-09b" R4 "clave *.expected* en transport, pages o actions" \
  "$T/actions/Bad.java" '    private static final String CLAVE = "checkout.expected.confirmation";'
violation "D7-09c" R4 "clave *.expected* en transport, pages o actions" \
  "$T/transport/Bad.java" '    private static final String CLAVE = "login.expected.error";'
violation "D7-10" R5 "findElement(s) o executeScript fuera de transport" \
  "$T/pages/BadPage.java" '        driver.findElements(USUARIO);'
violation "D7-10b" R5 "findElement(s) o executeScript fuera de transport" \
  "$T/hooks/Bad.java" '        executor.executeScript(script);'
violation "D7-10c" R5 "findElement(s) o executeScript fuera de transport" \
  "$T/steps/Bad.java" '        executor.executeAsyncScript(script);'
violation "D7-10d" R5 "findElement(s) o executeScript fuera de transport" \
  "$T/pages/BadPage.java" '        driver.findElement(USUARIO);'
violation "D7-11" R5 "una página extiende una clase" \
  "$T/pages/BadPage.java" 'public final class BadPage extends BasePage {'
# R6: un caso por cada paquete de la alternancia de cada fila (D7-12…D7-18).
# r6 <id> <motivo> <archivo> <paquetes…>: "import com.demo.<paquete>.X;".
r6() {
  local id="$1" reason="$2" file="$3" pkg
  shift 3
  for pkg in "$@"; do
    violation "$id-$pkg" R6 "$reason" "$file" "import com.demo.$pkg.X;"
  done
}
r6 "D7-12" "transport nombra un paquete fuera de su fila de D4" \
  "$T/transport/Bad.java" pages actions steps hooks runners data
violation "D7-13" R6 "transport o pages nombran utils distinto de ConfigReader" \
  "$T/pages/BadPage.java" 'import com.demo.utils.TestContext;'
violation "D7-13b" R6 "transport o pages nombran utils distinto de ConfigReader" \
  "$T/transport/Bad.java" 'import com.demo.utils.ConfigReaderX;'
r6 "D7-14" "pages nombra un paquete fuera de su fila de D4" \
  "$T/pages/BadPage.java" actions steps hooks runners config data
r6 "D7-15" "actions nombra un paquete fuera de su fila de D4" \
  "$T/actions/Bad.java" transport utils steps hooks runners config
r6 "D7-16" "steps nombra un paquete fuera de su fila de D4" \
  "$T/steps/Bad.java" hooks runners config
r6 "D7-17" "utils nombra un paquete fuera de su fila de D4" \
  "$T/utils/Bad.java" transport pages actions steps hooks runners
r6 "D7-18" "hooks nombra un paquete fuera de su fila de D4" \
  "$T/hooks/Bad.java" pages actions steps runners config data
violation "D7-19" R6 "SecretReader o CredentialsProvider fuera de utils y steps" \
  "$T/actions/Bad.java" '    // Un comentario que nombra SecretReader también cuenta (D6).'
violation "D7-19b" R6 "SecretReader o CredentialsProvider fuera de utils y steps" \
  "$T/pages/BadPage.java" '    private CredentialsProvider proveedor;'
# Restricción de D1 (enmienda 2026-10-13): ResultadoClic en un miembro público
# de una página, como retorno (calificado o importado), parámetro o campo.
violation "D1-rc" R6 "ResultadoClic en un miembro público de una página" \
  "$T/pages/BadPage.java" '    public Navegador.ResultadoClic pulsar() {'
violation "D1-rc-b" R6 "ResultadoClic en un miembro público de una página" \
  "$T/pages/BadPage.java" '    public ResultadoClic pulsar() {'
violation "D1-rc-c" R6 "ResultadoClic en un miembro público de una página" \
  "$T/pages/BadPage.java" '    public void decidir(Navegador.ResultadoClic resultado) {'
violation "D1-rc-d" R6 "ResultadoClic en un miembro público de una página" \
  "$T/pages/BadPage.java" '    public static final Navegador.ResultadoClic INICIAL = null;'
# Firmas expuestas (D7, enmienda 2026-10-13): en cada comprobación de firmas,
# public en la columna 0, una anotación o un modificador delante y protected.
violation "D7-03-col0" R1 "tipo de Selenium en una firma pública del transporte" \
  "$T/transport/Bad.java" 'public WebElement buscar(By locator) {'
violation "D7-03-anot" R1 "tipo de Selenium en una firma pública del transporte" \
  "$T/transport/Bad.java" '    @Override public WebElement buscar(By locator) {'
violation "D7-03-mod" R1 "tipo de Selenium en una firma pública del transporte" \
  "$T/transport/Bad.java" '    static public WebDriver crear() {'
violation "D7-03-prot" R1 "tipo de Selenium en una firma pública del transporte" \
  "$T/transport/Bad.java" '    protected WebDriver driver() {'
violation "D7-04-col0" R1 "By en una firma pública de una página" \
  "$T/pages/BadPage.java" 'public void pulsar(By locator) {'
violation "D7-04-anot" R1 "By en una firma pública de una página" \
  "$T/pages/BadPage.java" '    @Deprecated public void pulsar(By locator) {'
violation "D7-04-mod" R1 "By en una firma pública de una página" \
  "$T/pages/BadPage.java" '    final public void pulsar(By locator) {'
violation "D7-04-prot" R1 "By en una firma pública de una página" \
  "$T/pages/BadPage.java" '    protected static final By TITULO = By.className("title");'
# Interfaces, anotaciones y records expuestos en transport y pages (R1-tipos).
violation "R1-tipos" R1 "interfaz, anotación o record expuesto en transport o pages" \
  "$T/pages/BadPage.java" 'public interface Pulsable {'
violation "R1-tipos-b" R1 "interfaz, anotación o record expuesto en transport o pages" \
  "$T/pages/BadPage.java" '    public @interface Marca {'
violation "R1-tipos-c" R1 "interfaz, anotación o record expuesto en transport o pages" \
  "$T/pages/BadPage.java" '    static public record Estado(boolean visible) {}'
violation "R1-tipos-d" R1 "interfaz, anotación o record expuesto en transport o pages" \
  "$T/pages/BadPage.java" '    protected interface Pulsable {'
violation "R1-tipos-e" R1 "interfaz, anotación o record expuesto en transport o pages" \
  "$T/transport/Bad.java" '    @FunctionalInterface public interface Condicion {'
violation "D7-06-col0" R3 "página en el tipo de retorno de un método público de actions" \
  "$T/actions/Bad.java" 'public LoginPage pagina() {'
violation "D7-06-anot" R3 "página en el tipo de retorno de un método público de actions" \
  "$T/actions/Bad.java" '    @Deprecated public LoginPage pagina() {'
violation "D7-06-mod" R3 "página en el tipo de retorno de un método público de actions" \
  "$T/actions/Bad.java" '    synchronized public LoginPage pagina() {'
violation "D7-06-prot" R3 "página en el tipo de retorno de un método público de actions" \
  "$T/actions/Bad.java" '    protected LoginPage pagina() {'
violation "R3-param-col0" R3 "página como parámetro de un método público de actions" \
  "$T/actions/Bad.java" 'public void usar(LoginPage pagina) {'
violation "R3-param-anot" R3 "página como parámetro de un método público de actions" \
  "$T/actions/Bad.java" '    @Override public void usar(LoginPage pagina) {'
violation "R3-param-mod" R3 "página como parámetro de un método público de actions" \
  "$T/actions/Bad.java" '    final public void usar(LoginPage pagina) {'
violation "R3-param-prot" R3 "página como parámetro de un método público de actions" \
  "$T/actions/Bad.java" '    protected void usar(LoginPage pagina) {'
# Interfaces, anotaciones y records expuestos en actions (R3-tipos).
violation "R3-tipos" R3 "interfaz, anotación o record expuesto en actions" \
  "$T/actions/Bad.java" 'public interface Flujo {'
violation "R3-tipos-b" R3 "interfaz, anotación o record expuesto en actions" \
  "$T/actions/Bad.java" '    public record Resumen(String total, int cantidad) {}'
violation "R3-tipos-c" R3 "interfaz, anotación o record expuesto en actions" \
  "$T/actions/Bad.java" '    @Deprecated protected interface Paso {'
violation "D1-rc-col0" R6 "ResultadoClic en un miembro público de una página" \
  "$T/pages/BadPage.java" 'public Navegador.ResultadoClic pulsar() {'
violation "D1-rc-anot" R6 "ResultadoClic en un miembro público de una página" \
  "$T/pages/BadPage.java" '    @Override public ResultadoClic x() {'
violation "D1-rc-mod" R6 "ResultadoClic en un miembro público de una página" \
  "$T/pages/BadPage.java" '    static public Navegador.ResultadoClic pulsar() {'
violation "D1-rc-prot" R6 "ResultadoClic en un miembro público de una página" \
  "$T/pages/BadPage.java" '    protected Navegador.ResultadoClic pulsar() {'
# Elementos de MOD: anotación con argumentos, calificada, dos elementos antes
# de public y non-sealed (columna 0).
violation "EXP-args" R6 "ResultadoClic en un miembro público de una página" \
  "$T/pages/BadPage.java" '    @Deprecated(since = "1") public Navegador.ResultadoClic pulsar() {'
violation "EXP-calif" R6 "ResultadoClic en un miembro público de una página" \
  "$T/pages/BadPage.java" '    @java.lang.Deprecated public Navegador.ResultadoClic pulsar() {'
violation "EXP-dos" R6 "ResultadoClic en un miembro público de una página" \
  "$T/pages/BadPage.java" '    @Deprecated final public Navegador.ResultadoClic pulsar() {'
violation "EXP-ns" R6 "ResultadoClic en un miembro público de una página" \
  "$T/pages/BadPage.java" 'non-sealed public class BadPage implements Supplier<Navegador.ResultadoClic> {'
# Selenium en el transporte y herencia (D7, enmienda 2026-10-13, parte 2):
# unión por imports (R1-imp y R1-her), comodines (R1-wild), By fuera de los
# parámetros (R1-by) y herencia en transport, actions y utils (R5-ext).
violation2 "R1-imp" R1 "tipo de Selenium importado o calificado en una firma pública del transporte" "$T/transport/Bad.java" \
  'import org.openqa.selenium.remote.RemoteWebDriver;' \
  '    public RemoteWebDriver remoto() {'
violation2 "R1-imp-b" R1 "tipo de Selenium importado o calificado en una firma pública del transporte" "$T/transport/Bad.java" \
  'import org.openqa.selenium.Alert;' \
  '    public void aceptar(Alert alerta) {'
violation2 "R1-imp-c" R1 "tipo de Selenium importado o calificado en una firma pública del transporte" "$T/transport/Bad.java" \
  'import static org.openqa.selenium.WebDriver.Timeouts;' \
  '    public Timeouts tiempos() {'
violation2 "R1-imp-d" R1 "tipo de Selenium importado o calificado en una firma pública del transporte" "$T/transport/Bad.java" \
  'import org.openqa.selenium.Cookie;' \
  '    public java.util.Set<Cookie> cookies() {'
violation2 "R1-imp-e" R1 "tipo de Selenium importado o calificado en una firma pública del transporte" "$T/transport/Bad.java" \
  'import org.openqa.selenium.Dimension;' \
  '    @Deprecated protected Dimension tamano() {'
violation2 "R1-imp-f" R1 "tipo de Selenium importado o calificado en una firma pública del transporte" "$T/transport/Bad.java" \
  'import java.util.List; import org.openqa.selenium.Alert; import org.openqa.selenium.Point;' \
  '    public Point posicion() {'
violation "R1-imp-g" R1 "tipo de Selenium importado o calificado en una firma pública del transporte" \
  "$T/transport/Bad.java" '    public org.openqa.selenium.Alert alerta() {'
violation2 "R1-imp-h" R1 "tipo de Selenium importado o calificado en una firma pública del transporte" "$T/transport/Bad.java" \
  'import org.openqa.selenium.NoSuchElementException;' \
  '    public void pulsar(By localizador) throws NoSuchElementException {'
violation2 "R1-her" R1 "transport hereda o implementa un tipo de Selenium" "$T/transport/Bad.java" \
  'import org.openqa.selenium.chrome.ChromeDriver;' \
  'final class Bad extends ChromeDriver {'
violation2 "R1-her-b" R1 "transport hereda o implementa un tipo de Selenium" "$T/transport/Bad.java" \
  'import org.openqa.selenium.WebDriver;' \
  'public final class Bad implements WebDriver {'
violation2 "R1-her-c" R1 "transport hereda o implementa un tipo de Selenium" "$T/transport/Bad.java" \
  'import org.openqa.selenium.WebDriver;' \
  'final class Proveedor implements java.util.function.Supplier<WebDriver> {'
violation "R1-her-d" R1 "transport hereda o implementa un tipo de Selenium" \
  "$T/transport/Bad.java" 'final class Bad extends org.openqa.selenium.remote.RemoteWebDriver {'
violation2 "R1-her-e" R1 "transport hereda o implementa un tipo de Selenium" "$T/transport/Bad.java" \
  'import org.openqa.selenium.JavascriptExecutor;' \
  '        implements JavascriptExecutor {'
violation "R1-wild" R1 "import con comodín de Selenium en transport" \
  "$T/transport/Bad.java" 'import org.openqa.selenium.*;'
violation "R1-wild-b" R1 "import con comodín de Selenium en transport" \
  "$T/transport/Bad.java" 'import static org.openqa.selenium.support.ui.ExpectedConditions.*;'
violation "R1-by" R1 "By fuera de los parámetros de una firma pública del transporte" \
  "$T/transport/Bad.java" '    public By localizador() {'
violation "R1-by-b" R1 "By fuera de los parámetros de una firma pública del transporte" \
  "$T/transport/Bad.java" '    public static final By TITULO = By.className("title");'
violation "R1-by-c" R1 "By fuera de los parámetros de una firma pública del transporte" \
  "$T/transport/Bad.java" 'public final class Bad extends By {'
violation "R1-by-d" R1 "By fuera de los parámetros de una firma pública del transporte" \
  "$T/transport/Bad.java" '    protected java.util.List<By> localizadores() {'
violation "R5-ext" R5 "una clase de transport, actions o utils extiende otra" \
  "$T/actions/Bad.java" 'public final class Bad extends CartPage {'
violation "R5-ext-b" R5 "una clase de transport, actions o utils extiende otra" \
  "$T/utils/Bad.java" 'public final class Bad extends ConfigResolver {'
violation "R5-ext-c" R5 "una clase de transport, actions o utils extiende otra" \
  "$T/transport/Bad.java" 'final class Bad extends RuntimeException {'

# Clic nativo único, scripts cerrados y preferencias de Chrome (D7, enmienda
# 2026-10-13, parte 4). R5-js: executeScript fuera de la lista cerrada.
R5JS="executeScript fuera de la lista cerrada de scripts del transporte"
violation "R5-js" R5 "$R5JS" "$T/transport/Bad.java" \
  '        ((JavascriptExecutor) driver).executeScript("return 1;");'
violation "R5-js-b" R5 "$R5JS" "$T/transport/Bad.java" \
  '            return ((JavascriptExecutor) driver).executeScript(script);'
violation "R5-js-c" R5 "$R5JS" "$T/transport/Bad.java" \
  '        ((JavascriptExecutor) driver).executeScript(SCRIPT_PULSAR, elemento);'
violation "R5-js-d" R5 "$R5JS" "$T/transport/Bad.java" \
  '        ((JavascriptExecutor) driver).executeScript(SCRIPT_DESPLAZAR_AL_CENTRO_Y_PULSAR, elemento);'
violation "R5-js-e" R5 "$R5JS" "$T/transport/Bad.java" \
  '        ((JavascriptExecutor) driver).executeAsyncScript(SCRIPT_DESPLAZAR_AL_CENTRO, elemento);'
# R5-evt: eventos sintéticos y otras vías de entrada.
R5EVT="evento sintético o vía de entrada distinta del clic nativo en transport"
violation "R5-evt" R5 "$R5EVT" "$T/transport/Bad.java" \
  "            arguments[0].dispatchEvent(new MouseEvent('click', {bubbles: true}));"
violation "R5-evt-b" R5 "$R5EVT" "$T/transport/Bad.java" \
  '        String metodo = "Input.dispatchMouseEvent";'
violation "R5-evt-c" R5 "$R5EVT" "$T/transport/Bad.java" \
  '        ((HasCdp) driver).executeCdpCommand("Runtime.evaluate", parametros);'
violation "R5-evt-d" R5 "$R5EVT" "$T/transport/Bad.java" \
  '        elemento.sendKeys(Keys.ENTER);'
violation "R5-evt-e" R5 "$R5EVT" "$T/transport/Bad.java" \
  '        elemento.submit();'
violation "R5-evt-f" R5 "$R5EVT" "$T/transport/Bad.java" \
  '            arguments[0].form.requestSubmit();'
violation "R5-evt-g" R5 "$R5EVT" "$T/transport/Bad.java" \
  'import org.openqa.selenium.interactions.Actions;'
violation "R5-evt-h" R5 "$R5EVT" "$T/transport/Bad.java" \
  'import org.openqa.selenium.devtools.HasDevTools;'
violation "R5-evt-i" R5 "$R5EVT" "$T/transport/Bad.java" \
  'import org.openqa.selenium.bidi.HasBiDi;'
violation "R5-evt-j" R5 "$R5EVT" "$T/transport/Bad.java" \
  '        java.util.Optional.of(elemento).ifPresent(WebElement::submit);'
# R5-clic: toda línea de clic es exactamente "elemento.click();".
R5CLIC="clic distinto de la línea de clic nativo del transporte"
violation "R5-clic" R5 "$R5CLIC" "$T/transport/Bad.java" \
  '            arguments[0].click();'
violation "R5-clic-b" R5 "$R5CLIC" "$T/transport/Bad.java" \
  '        wait.until(ExpectedConditions.elementToBeClickable(localizador)).click();'
violation "R5-clic-c" R5 "$R5CLIC" "$T/transport/Bad.java" \
  '        new Actions(driver).moveToElement(elemento).click().perform();'
violation "R5-clic-d" R5 "$R5CLIC" "$T/transport/Bad.java" \
  '        java.util.Optional.of(elemento).ifPresent(WebElement::click);'
violation "R5-clic-e" R5 "$R5CLIC" "$T/transport/Bad.java" \
  '            HTMLElement.prototype.click.call(arguments[0]);'
violation "R5-clic-f" R5 "$R5CLIC" "$T/transport/Bad.java" \
  '            elemento.click(); elemento.click();'
violation "R5-clic-g" R5 "$R5CLIC" "$T/transport/Bad.java" \
  '            boton.click();'
# R5-clic-max: forma exacta, pero es la segunda línea de clic (la otra está en
# el Navegador.java del árbol base).
violation "R5-clic-max" R5 "más de un clic nativo en transport" "$T/transport/Bad.java" \
  '            elemento.click();'
# D8-prefs (presencia): la línea de preferencias del DriverFactory.java del
# árbol base se reescribe; versionada = el cambio va al índice (git add o
# git rm), sin versionar = solo en el árbol de trabajo.
D8_FILE="$T/transport/DriverFactory.java"
D8_LINE='        options.setExperimentalOption("prefs", settings.chromePreferences());'
D8_OUT="$D8_FILE:0: D8: DriverFactory no aplica las preferencias de Chrome de BrowserSettings"
# d8 <id> <descripción> [línea nueva]: sin línea nueva, la línea se borra.
d8() {
  local id="$1" desc="$2" mode
  shift 2
  for mode in versionada sin-versionar; do
    new_case
    reemplazar "$dir/$D8_FILE" "$D8_LINE" "$@"
    if [ "$mode" = versionada ]; then
      git -C "$dir" add -- "$D8_FILE"
    fi
    run_script "$dir"
    expect "$id D8 transport/DriverFactory.java, $desc ($mode)" 1 "$D8_OUT"
  done
}
d8 "D8-prefs" "sin la línea"
d8 "D8-prefs-b" "comentada" \
  '        // options.setExperimentalOption("prefs", settings.chromePreferences());'
d8 "D8-prefs-c" "otra clave" \
  '        options.setExperimentalOption("excludeSwitches", settings.chromePreferences());'
d8 "D8-prefs-d" "otro origen" \
  '        options.setExperimentalOption("prefs", java.util.Map.of());'
# D8-prefs-e: la línea buena, pero en transport/Otro.java (línea 2).
for mode in versionada sin-versionar; do
  new_case
  reemplazar "$dir/$D8_FILE" "$D8_LINE"
  put "$dir/$T/transport/Otro.java" 'package com.demo.prueba;' "$D8_LINE"
  if [ "$mode" = versionada ]; then
    git -C "$dir" add -- "$D8_FILE" "$T/transport/Otro.java"
  fi
  run_script "$dir"
  expect "D8-prefs-e D8 sin la línea en DriverFactory y con ella en Otro.java ($mode)" 1 "$D8_OUT"
done
# D8-prefs-f: sin DriverFactory.java (git rm, o rm sin git rm).
for mode in versionada sin-versionar; do
  new_case
  if [ "$mode" = versionada ]; then
    git -C "$dir" rm -q -- "$D8_FILE"
  else
    rm -- "$dir/$D8_FILE"
  fi
  run_script "$dir"
  expect "D8-prefs-f D8 sin transport/DriverFactory.java ($mode)" 1 "$D8_OUT"
done
# D8-prefs-g: sin el directorio transport (git rm -r, o rm -r sin git rm). La
# guarda del directorio padre de require da 1 con la línea de D8, sin el aviso
# de git grep --untracked ("could not open directory").
for mode in versionada sin-versionar; do
  new_case
  if [ "$mode" = versionada ]; then
    git -C "$dir" rm -r -q -- "$T/transport"
  else
    rm -r -- "$dir/$T/transport"
  fi
  run_script "$dir"
  expect "D8-prefs-g D8 sin el directorio transport ($mode)" 1 "$D8_OUT"
done
# Casi-coincidencias permitidas de la parte 4.
allowed "ok-35 identificadores que contienen los nombres de JS" "$T/transport/Otro.java" \
  '        boolean noexecuteScript = executeScriptado && noexecuteAsyncScript || executeAsyncScriptado;'
# ok-36 (parte 5): sendKeys sin prefijo y Keystroke no son el token Keys ni una
# escritura (antes era una escritura, que ahora sería la segunda).
allowed "ok-36 sendKeys y Keystroke no son el token Keys" "$T/transport/Otro.java" \
  '        boolean sendKeys = Keystroke;'
allowed "ok-37 submit sin punto, y submitted" "$T/transport/Otro.java" \
  '        boolean submit = formulario.submitted;'
allowed "ok-38 método que empieza por click" "$T/transport/Otro.java" \
  '        this.clickHastaCumplir(localizador, postcondicion);'
# allowed_rewrite <id> <archivo> <línea exacta> <línea nueva>: casi-violación
# que reescribe una línea del árbol base, en ambos modos.
allowed_rewrite() {
  local id="$1" file="$2" old="$3" new="$4" mode
  for mode in versionada sin-versionar; do
    new_case
    reemplazar "$dir/$file" "$old" "$new"
    if [ "$mode" = versionada ]; then
      git -C "$dir" add -- "$file"
    fi
    run_script "$dir"
    expect "$id ${file#"$T/"} ($mode)" 0 "check-layers: ok: CHK-17 (R1–R6) sin violaciones"
  done
}
allowed_rewrite "ok-39 línea de clic del árbol base en la columna 0" "$T/transport/Navegador.java" \
  '        elemento.click();' 'elemento.click();'
allowed_rewrite "ok-40 otros nombres y espacios, en la columna 0" "$D8_FILE" \
  "$D8_LINE" 'opciones.setExperimentalOption( "prefs" , ajustes.chromePreferences() ) ;'

# Escritura única (D7, enmienda 2026-10-13, parte 5). R5-esc: toda línea de
# escritura es exactamente "elemento.sendKeys(texto);".
R5ESC="escritura distinta de la línea de escritura nativa del transporte"
violation "R5-esc" R5 "$R5ESC" "$T/transport/Bad.java" \
  '                elemento.sendKeys(textoEsperado);'
violation "R5-esc-b" R5 "$R5ESC" "$T/transport/Bad.java" \
  '        elemento.sendKeys(texto + "\n");'
violation "R5-esc-c" R5 "$R5ESC" "$T/transport/Bad.java" \
  '        new Actions(driver).sendKeys(elemento, texto).perform();'
violation "R5-esc-d" R5 "$R5ESC" "$T/transport/Bad.java" \
  '        java.util.Optional.of(elemento).ifPresent(WebElement::sendKeys);'
violation "R5-esc-e" R5 "$R5ESC" "$T/transport/Bad.java" \
  '            elemento.sendKeys(texto); elemento.sendKeys(texto);'
violation "R5-esc-f" R5 "$R5ESC" "$T/transport/Bad.java" \
  '            campo.sendKeys(texto);'
# R5-esc-max: forma exacta, pero es la segunda línea de escritura (la otra está
# en el Navegador.java del árbol base).
violation "R5-esc-max" R5 "más de una escritura nativa en transport" "$T/transport/Bad.java" \
  '            elemento.sendKeys(texto);'
allowed "ok-41 método que empieza por sendKeys" "$T/transport/Otro.java" \
  '        this.sendKeysYEsperar(localizador, texto);'
allowed_rewrite "ok-42 línea de escritura del árbol base en la columna 0" "$T/transport/Navegador.java" \
  '        elemento.sendKeys(texto);' 'elemento.sendKeys(texto);'

# Pruebas de contrato del transporte (D7, enmienda 2026-10-13, parte 6;
# ADR-004, D8). Cada línea va en la línea 2 del archivo, en sus dos modos.
FXT=src/test/resources/contract
# A4-R1: en contract, Selenium solo como "import org.openqa.selenium.By;".
A4R1="en contract solo se permite 'import org.openqa.selenium.By;'"
violation "A4-R1" R1 "$A4R1" "$T/contract/Bad.java" \
  'import org.openqa.selenium.WebDriver;'
violation "A4-R1-b" R1 "$A4R1" "$T/contract/Bad.java" \
  'import org.openqa.selenium.By; import java.util.List;'
violation "A4-R1-c" R1 "$A4R1" "$T/contract/Bad.java" \
  '        org.openqa.selenium.TimeoutException error = null;'
violation "A4-R1-d" R1 "$A4R1" "$T/contract/Bad.java" \
  'import static org.openqa.selenium.By.id;'
# A4-red: destinos de red y URL del SUT en contract y en sus páginas locales.
A4RED="destino de red o URL del SUT en contract o en sus páginas locales"
violation "A4-red" R4 "$A4RED" "$T/contract/Bad.java" \
  '        navegador.abrir("https://ejemplo.invalid/");'
violation "A4-red-b" R4 "$A4RED" "$T/contract/Bad.java" \
  '        navegador.abrir(ConfigReader.getRequired("base.url"));'
violation "A4-red-c" R4 "$A4RED" "$T/contract/Bad.java" \
  '        String grid = ConfigReader.getOptional("remote.url");'
violation "A4-red-d" R4 "$A4RED" "$FXT/bad.html" \
  '<img src="http://ejemplo.invalid/x.png" alt="">'
violation "A4-red-e" R4 "$A4RED" "$FXT/bad.html" \
  '<script>new WebSocket("ws://127.0.0.1:9");</script>'
# A4-fix: temporizadores, eventos sintéticos, envíos y recargas automáticas en
# las páginas locales; un caso por alternativa de FIX.
A4FIX="temporizador, evento sintético o navegación automática en una página local de contract"
violation "A4-fix" R5 "$A4FIX" "$FXT/bad.html" \
  '<script>setTimeout(contar, 1000);</script>'
violation "A4-fix-b" R5 "$A4FIX" "$FXT/bad.html" \
  '<script>setInterval(contar, 500);</script>'
violation "A4-fix-c" R5 "$A4FIX" "$FXT/bad.html" \
  '<script>requestAnimationFrame(contar);</script>'
violation "A4-fix-d" R5 "$A4FIX" "$FXT/bad.html" \
  '<script>boton.dispatchEvent(evento);</script>'
violation "A4-fix-e" R5 "$A4FIX" "$FXT/bad.html" \
  "<script>const evento = new Event('click');</script>"
violation "A4-fix-f" R5 "$A4FIX" "$FXT/bad.html" \
  "<body onload=\"document.getElementById('accion').click()\">"
violation "A4-fix-g" R5 "$A4FIX" "$FXT/bad.html" \
  '<script>document.forms[0].submit();</script>'
violation "A4-fix-h" R5 "$A4FIX" "$FXT/bad.html" \
  '<meta http-equiv="refresh" content="1">'
violation "A4-fix-i" R5 "$A4FIX" "$FXT/bad.html" \
  '<META HTTP-EQUIV=Refresh CONTENT=1>'
violation "A4-fix-j" R5 "$A4FIX" "$FXT/bad.html" \
  '<script>requestIdleCallback(contar);</script>'
violation "A4-fix-k" R5 "$A4FIX" "$FXT/bad.html" \
  '<script>queueMicrotask(contar);</script>'
violation "A4-fix-l" R5 "$A4FIX" "$FXT/bad.html" \
  "<script>const evento = document.createEvent('MouseEvents');</script>"
violation "A4-fix-m" R5 "$A4FIX" "$FXT/bad.html" \
  '<script>formulario.requestSubmit();</script>'
violation "A4-fix-n" R5 "$A4FIX" "$FXT/bad.html" \
  '<script>HTMLElement.prototype.click.call(boton);</script>'
# A4-R6: un caso por paquete fuera de la fila de D4 de contract.
r6 "A4-R6" "contract nombra un paquete fuera de su fila de D4" \
  "$T/contract/Bad.java" pages actions steps hooks runners config data
# A4-R6u: utils distinto de ConfigReader.
A4R6U="contract nombra utils distinto de ConfigReader"
violation "A4-R6u" R6 "$A4R6U" "$T/contract/Bad.java" \
  'import com.demo.utils.TestContext;'
violation "A4-R6u-b" R6 "$A4R6U" "$T/contract/Bad.java" \
  'import com.demo.utils.ConfigReaderX;'
# A4-R6in: ningún paquete distinto de contract la nombra (tampoco el glue).
A4R6IN="un paquete distinto de contract nombra contract"
violation "A4-R6in" R6 "$A4R6IN" "$T/transport/Bad.java" \
  'import com.demo.contract.X;'
violation "A4-R6in-b" R6 "$A4R6IN" "$T/pages/BadPage.java" \
  'import com.demo.contract.X;'
violation "A4-R6in-c" R6 "$A4R6IN" "$T/runners/Bad.java" \
  '@ConfigurationParameter(key = GLUE_PROPERTY_NAME, value = "com.demo.steps,com.demo.contract")'
violation "A4-R6in-d" R6 "$A4R6IN" "src/main/java/com/demo/config/Bad.java" \
  '// Nombra com.demo.contract en un comentario (D6).'
# Casi-violaciones permitidas de la parte 6.
allowed "A4-ok-1 onclick no es una llamada a click" "$FXT/ok.html" \
  '<button id="accion" onclick="contar()">Accion</button>'
allowed "A4-ok-2 el \\b final de FIX" "$FXT/ok.html" \
  "<script>const nombre = 'setTimeoutX';</script>"
allowed "A4-ok-3 cambiar el fragmento no es navegación automática" "$FXT/ok.html" \
  "<script>function avanzar() { location.hash = 'paso-siguiente'; }</script>"
allowed "A4-ok-4 las claves .expected se permiten en contract" "$T/contract/Otro.java" \
  '        private static final String PISTA = "contract.expected.pista";'
allowed "A4-ok-5 el \\b inicial de RED" "$T/contract/Otro.java" \
  '        String clave = "contract.database.url";'
allowed "A4-ok-6 el \\b de A4-R6in" "$T/steps/Otro.java" \
  'import com.demo.contractual.X;'

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
  "$T/steps/IgnoradoBad.java:2: R1: Selenium fuera de transport, pages y contract"
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

# No se puede evaluar: 2 (falla cerrado), siempre con el mensaje que explica
# por qué; el código de salida solo no distingue un error de otro.
err_rc='re:^check-layers: ERROR: git grep terminó con [0-9]+ '

new_case
rm -rf "$dir/.git"
run_script "$dir"
expect "error: la raíz no es un repositorio git" 2 \
  "check-layers: '$dir' no es un repositorio git"

new_case
run_script "$dir/src"
expect "error: la raíz es un subdirectorio del repositorio" 2 \
  "check-layers: '$dir/src' no es la raíz del repositorio ($dir)"

# Subdirectorio con su propio árbol de capas (válido) dentro de un repositorio
# con una violación fuera de él: evaluar solo el subdirectorio daría 0.
new_case
mkdir -p "$dir/proj"
cp -a "$base/src" "$dir/proj/src" || {
  echo "check-layers-test: no se pudo copiar src al subdirectorio del caso $n" >&2
  exit 2
}
put "$dir/$T/steps/Bad.java" 'package com.demo.prueba;' 'import org.openqa.selenium.WebDriver;'
git -C "$dir" add -A
run_script "$dir/proj"
expect "error: subdirectorio con árbol de capas propio y violación fuera" 2 \
  "check-layers: '$dir/proj' no es la raíz del repositorio ($dir)"

run_script "$tmp/no-existe"
expect "error: la raíz no existe" 2 \
  "check-layers: la raíz '$tmp/no-existe' no es un directorio"

new_case
run_script "$dir" extra
expect "error: argumentos de más" 2 \
  "check-layers: uso: bash scripts/check-layers.sh [raíz]"

new_case
printf 'indice corrupto\n' > "$dir/.git/index"
run_script "$dir"
# El mensaje distingue el rc >= 2 de git grep del de git ls-files, que
# también fallaría con el índice corrupto.
expect "error: git grep termina con rc >= 2 (índice corrupto)" 2 "$err_rc"

new_case
git -C "$dir" config grep.threads no-numerico
run_script "$dir"
expect "error: git grep termina con rc >= 2 (configuración inválida)" 2 "$err_rc"

# git grep termina con rc >= 2 sin escribir en stderr: solo la guarda de rc
# lo detecta (con git real, todo rc >= 2 trae un "fatal:"). Un shim de git en
# el PATH intercepta "git grep" y delega el resto en el git real.
real_git="$(command -v git)"
case "$real_git" in
  /*) ;;
  *) echo "check-layers-test: git no es un ejecutable con ruta absoluta" >&2; exit 2 ;;
esac
# shim <directorio> <acción para "git grep">
shim() {
  mkdir -p "$1"
  printf '#!/usr/bin/env bash\nif [ "${1:-}" = grep ]; then %s; fi\nexec %q "$@"\n' \
    "$2" "$real_git" > "$1/git"
  chmod +x "$1/git"
}
shim "$tmp/shim-kill" 'kill -KILL "$$"'
shim "$tmp/shim-rc2" 'exit 2'
# run_with_path <directorio del shim> <argumentos…>
run_with_path() {
  local p="$1"
  shift
  rc=0
  out="$(PATH="$p:$PATH" bash "$script" "$@" 2>&1)" || rc=$?
}

new_case
run_with_path "$tmp/shim-kill" "$dir"
expect "error: git grep muere por SIGKILL sin stderr (rc 137)" 2 \
  're:^check-layers: ERROR: git grep terminó con 137 '

new_case
run_with_path "$tmp/shim-rc2" "$dir"
expect "error: git grep termina con 2 sin stderr" 2 \
  're:^check-layers: ERROR: git grep terminó con 2 '

# Unión por imports (D7, Selenium en el transporte y herencia): un awk que sale
# con 3 da 2 (error-awk), y el git grep de HER pasa por el ejecutor con guardas
# (error-her: el shim falla solo si un argumento contiene "implements", que
# solo aparece en HER).
mkdir -p "$tmp/shim-awk"
printf '#!/usr/bin/env bash\nexit 3\n' > "$tmp/shim-awk/awk"
chmod +x "$tmp/shim-awk/awk"
new_case
run_with_path "$tmp/shim-awk" "$dir"
expect "error-awk: el awk de la unión sale con 3" 2 \
  're:^check-layers: ERROR: awk terminó con 3 '

shim "$tmp/shim-her" 'for a in "$@"; do case "$a" in *implements*) exit 2 ;; esac; done'
new_case
run_with_path "$tmp/shim-her" "$dir"
expect "error-her: el git grep de HER falla dentro de la unión" 2 \
  "check-layers: ERROR: git grep terminó con 2 (R1: transport hereda o implementa un tipo de Selenium)"

# Conteo y presencia (D7, parte 4): check_max y require pasan por el ejecutor
# con guardas. error-max: el shim falla, sin stderr, solo si un argumento es
# exactamente CLIC (FORMA lo contiene, pero no es igual). error-d8: solo si un
# argumento contiene setExperimentalOption; require no confunde el error con
# una ausencia.
shim "$tmp/shim-max" 'for a in "$@"; do if [ "$a" = '"'"'(?:\.|::)click\b'"'"' ]; then exit 2; fi; done'
new_case
run_with_path "$tmp/shim-max" "$dir"
expect "error-max: el git grep de check_max falla" 2 \
  "check-layers: ERROR: git grep terminó con 2 (R5: más de un clic nativo en transport)"

shim "$tmp/shim-d8" 'for a in "$@"; do case "$a" in *setExperimentalOption*) exit 2 ;; esac; done'
new_case
run_with_path "$tmp/shim-d8" "$dir"
expect "error-d8: el git grep de require falla" 2 \
  "check-layers: ERROR: git grep terminó con 2 (D8: DriverFactory no aplica las preferencias de Chrome de BrowserSettings)"

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
  expect "error: archivo ilegible (git grep escribe en stderr)" 2 "$err_rc"
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
