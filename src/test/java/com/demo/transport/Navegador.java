package com.demo.transport;

import java.time.Duration;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import org.openqa.selenium.By;
import org.openqa.selenium.JavascriptExecutor;
import org.openqa.selenium.OutputType;
import org.openqa.selenium.TakesScreenshot;
import org.openqa.selenium.TimeoutException;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebDriverException;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.support.ui.ExpectedCondition;
import org.openqa.selenium.support.ui.ExpectedConditions;
import org.openqa.selenium.support.ui.WebDriverWait;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import com.demo.config.BrowserErrorPage;
import com.demo.utils.ConfigReader;

/**
 * Transporte del escenario: único dueño del WebDriver y del WebDriverWait (ADR-002, D1).
 * PicoContainer crea una instancia por escenario y la comparte entre los hooks y las páginas.
 * Su API pública recibe solo By y tipos de Java, y nunca devuelve tipos de Selenium.
 * Ningún mensaje ni log incluye el texto escrito, que puede ser una contraseña.
 */
public final class Navegador {

    private static final Duration TIEMPO_MAXIMO_ESPERA =
            Duration.ofSeconds(ConfigReader.getPositiveInt("explicit.wait.seconds"));
    /**
     * Tope de clics por acción: el primero es nativo y los demás, el respaldo JavaScript. No es un reintento de
     * la prueba: agotado el tope no se vuelve a pulsar y solo se espera la postcondición hasta el tiempo máximo.
     */
    private static final int MAXIMO_CLICS_POR_ACCION = 3;
    /** Sondeos consecutivos con el mismo resultado para dar por estable una lectura de ausencia o de conteo. */
    private static final int SONDEOS_ESTABLES = 2;
    private static final String SCRIPT_ESCRIBIR_INPUT_CONTROLADO = """
            const elemento = arguments[0];
            const valor = arguments[1];
            const descriptor = Object.getOwnPropertyDescriptor(elemento.constructor.prototype, 'value');
            descriptor.set.call(elemento, valor);
            elemento.dispatchEvent(new Event('input', { bubbles: true }));
            elemento.dispatchEvent(new Event('change', { bubbles: true }));
            """;

    /** Constante (PI-05): no incluye datos del SUT. Devuelve null fuera de una página de error de Chrome. */
    private static final String SCRIPT_LEER_CODIGO_PAGINA_ERROR = """
            if (!document.body || !document.body.classList.contains('neterror')) { return null; }
            const codigo = document.querySelector('.error-code');
            return codigo ? codigo.textContent : '';
            """;

    private final Logger logger = LoggerFactory.getLogger(Navegador.class);
    private WebDriver driver;
    private WebDriverWait wait;

    public Navegador() {
    }

    // --- Ciclo de vida (solo hooks) ---

    public void iniciar() {
        if (driver != null) {
            throw new IllegalStateException("Ya existe un WebDriver para el escenario actual");
        }
        driver = DriverFactory.crear();
        wait = new WebDriverWait(driver, TIEMPO_MAXIMO_ESPERA);
    }

    public byte[] capturarPantalla() {
        verificarIniciado();
        return ((TakesScreenshot) driver).getScreenshotAs(OutputType.BYTES);
    }

    public void cerrar() {
        WebDriver actual = driver;
        try {
            if (actual != null) {
                actual.quit();
            }
        } finally {
            driver = null;
            wait = null;
        }
    }

    // --- Navegación ---

    /**
     * Abre la URL y falla de inmediato si el navegador responde con su propia página de error
     * (Chrome: documento {@code neterror}; Firefox: {@code about:neterror}). No reintenta. El mensaje
     * incluye la URL solicitada y, si es válido, el código {@code net::ERR_…}; nunca texto de la página.
     */
    public void abrir(String url) {
        verificarIniciado();
        try {
            driver.navigate().to(url);
        } catch (WebDriverException exception) {
            if (BrowserErrorPage.isNavigationErrorMessage(exception.getMessage())) {
                Optional<String> codigo = BrowserErrorPage.codeFromDriverMessage(exception.getMessage());
                // PI-05/PI-09: solo el tipo de la excepción y el código que pasó el patrón; ni el texto del driver
                // ni la causa viajan al mensaje o al log.
                logger.debug("La navegación lanzó {} y se clasificó como página de error de red (código: {})",
                        exception.getClass().getName(), codigo.orElse(BrowserErrorPage.CODE_UNAVAILABLE));
                throw errorDeNavegacion(url, codigo);
            }
            throw exception;
        }

        // El script devuelve null si el documento no es una página de error; si lo es, el texto del código.
        Object textoDelCodigo = ejecutarScriptConstante(SCRIPT_LEER_CODIGO_PAGINA_ERROR);
        if (textoDelCodigo instanceof String texto) {
            throw errorDeNavegacion(url, BrowserErrorPage.codeFromPageText(texto));
        }
        if (BrowserErrorPage.isErrorUrl(driver.getCurrentUrl())) {
            throw errorDeNavegacion(url, Optional.empty());
        }
    }

    public void esperarUrlContiene(String fragmentoUrl) {
        verificarIniciado();
        wait.until(ExpectedConditions.urlContains(fragmentoUrl));
    }

    /** Lectura inmediata, sin espera: indica si la URL actual contiene el fragmento. */
    public boolean urlContiene(String fragmentoUrl) {
        verificarIniciado();
        String urlActual = driver.getCurrentUrl();
        return urlActual != null && urlActual.contains(fragmentoUrl);
    }

    // --- Interacción con postcondición ---

    public void click(By localizador) {
        verificarIniciado();
        wait.until(ExpectedConditions.elementToBeClickable(localizador)).click();
    }

    /**
     * Resultado de {@link #clickYObservarUrlContiene}: la URL esperada se alcanzó, no se alcanzó tras al menos un
     * clic efectivo, o el control nunca estuvo disponible (visible y habilitado) y no hubo ningún clic.
     */
    public enum ResultadoClic {
        AVANZO,
        NO_AVANZO,
        NO_DISPONIBLE
    }

    /**
     * Hace clic en el control, con el mismo respaldo y el mismo tope de clics que {@link #clickYEsperarUrlContiene},
     * hasta que la URL contenga el fragmento o se agote el tiempo máximo. Distingue tres estados:
     * {@link ResultadoClic#AVANZO}; {@link ResultadoClic#NO_AVANZO} con al menos un clic efectivo (el control
     * estuvo clicable y se pulsó); y {@link ResultadoClic#NO_DISPONIBLE}: el control no estuvo visible y habilitado
     * en todo el tiempo máximo, así que no hubo clic. Quien lo llama decide si "no disponible" es un resultado
     * válido; para que no sea un falso positivo debe comprobar antes que el resto de la página sí cargó.
     * Registra a nivel INFO el número de clics efectivos, nunca datos del escenario.
     */
    public ResultadoClic clickYObservarUrlContiene(By localizador, String fragmentoUrl) {
        verificarIniciado();
        AtomicInteger clicsEfectivos = new AtomicInteger();
        ExpectedCondition<Boolean> urlEsperada = ExpectedConditions.urlContains(fragmentoUrl);
        try {
            wait.until(webDriver -> {
                if (Boolean.TRUE.equals(urlEsperada.apply(webDriver))) {
                    return true;
                }
                if (clicsEfectivos.get() >= MAXIMO_CLICS_POR_ACCION) {
                    return false;
                }
                WebElement elemento = ExpectedConditions.elementToBeClickable(localizador).apply(webDriver);
                if (elemento == null) {
                    return false;
                }
                pulsar(webDriver, elemento, localizador, clicsEfectivos);
                return Boolean.TRUE.equals(urlEsperada.apply(webDriver));
            });
            logger.info("El clic en {} avanzó con {} clic(s) efectivo(s)", localizador, clicsEfectivos.get());
            return ResultadoClic.AVANZO;
        } catch (TimeoutException exception) {
            int clics = clicsEfectivos.get();
            logger.info("El clic en {} no avanzó; clics efectivos: {}", localizador, clics);
            return clics == 0 ? ResultadoClic.NO_DISPONIBLE : ResultadoClic.NO_AVANZO;
        }
    }

    public void clickYEsperarTexto(By localizador, String textoEsperado) {
        verificarIniciado();
        clickHastaCumplir(localizador, ExpectedConditions.textToBePresentInElementLocated(
                localizador,
                textoEsperado));
    }

    public void clickYEsperarUrlContiene(By localizador, String fragmentoUrl) {
        verificarIniciado();
        clickHastaCumplir(localizador, ExpectedConditions.urlContains(fragmentoUrl));
    }

    public void clickYEsperarVisible(By localizador, By esperado) {
        verificarIniciado();
        ExpectedCondition<Boolean> esperadoVisible =
                webDriver -> ExpectedConditions.visibilityOfElementLocated(esperado).apply(webDriver) != null;
        clickHastaCumplir(localizador, esperadoVisible);
    }

    /** La postcondición es cualquiera de las dos salidas observables: el elemento visible o la URL esperada. */
    public void clickYEsperarVisibleOUrlContiene(By localizador, By esperado, String fragmentoUrl) {
        verificarIniciado();
        ExpectedCondition<Boolean> alguna = webDriver ->
                ExpectedConditions.visibilityOfElementLocated(esperado).apply(webDriver) != null
                        || Boolean.TRUE.equals(ExpectedConditions.urlContains(fragmentoUrl).apply(webDriver));
        clickHastaCumplir(localizador, alguna);
    }

    /** Exige que el control esté visible antes del clic: un localizador que no coincide no puede dar por cumplida la ausencia. */
    public void clickYEsperarInvisible(By localizador) {
        verificarIniciado();
        elementoVisible(localizador);
        clickHastaCumplir(localizador, ExpectedConditions.invisibilityOfElementLocated(localizador));
    }

    public void escribir(By localizador, String texto) {
        verificarIniciado();
        WebElement elemento = elementoVisible(localizador);
        elemento.clear();
        elemento.sendKeys(texto);
        esperarValorEstable(localizador, texto);
    }

    public void desplazarA(By localizador) {
        verificarIniciado();
        WebElement elemento = elementoVisible(localizador);
        ((JavascriptExecutor) driver).executeScript("arguments[0].scrollIntoView({block: 'center'});", elemento);
    }

    // --- Lectura ---

    public void esperarVisible(By localizador) {
        verificarIniciado();
        elementoVisible(localizador);
    }

    public String texto(By localizador) {
        verificarIniciado();
        return elementoVisible(localizador).getText();
    }

    public List<String> textos(By localizador) {
        verificarIniciado();
        return wait.until(ExpectedConditions.visibilityOfAllElementsLocatedBy(localizador)).stream()
                .map(WebElement::getText)
                .toList();
    }

    /** Observa si el elemento llega a estar presente en el DOM (visible o no) dentro del tiempo máximo; no falla si no llega. */
    public boolean existeEnTiempoMaximo(By localizador) {
        verificarIniciado();
        try {
            wait.until(webDriver -> !webDriver.findElements(localizador).isEmpty());
            return true;
        } catch (TimeoutException exception) {
            logger.debug("El elemento {} no estuvo presente dentro del tiempo máximo", localizador);
            return false;
        }
    }

    /** Lectura inmediata, sin espera: indica si el elemento está presente y visible en este instante. */
    public boolean esVisible(By localizador) {
        verificarIniciado();
        return visibleAhora(driver, localizador);
    }

    /**
     * Lectura de "se muestra" apta para afirmar una ausencia: devuelve true en cuanto el elemento es visible y
     * false solo si no lo estuvo en {@value #SONDEOS_ESTABLES} sondeos consecutivos (el sondeo de la espera
     * explícita), de modo que un elemento que aparece con la página ya lista no se da por ausente. Acotada por el
     * tiempo máximo. El llamador debe haber comprobado antes que la página cargó.
     */
    public boolean esVisibleEstable(By localizador) {
        verificarIniciado();
        AtomicInteger ausenciasConsecutivas = new AtomicInteger();
        Optional<Boolean> decision = wait.until(webDriver -> {
            if (visibleAhora(webDriver, localizador)) {
                return Optional.of(true);
            }
            return ausenciasConsecutivas.incrementAndGet() >= SONDEOS_ESTABLES ? Optional.of(false) : null;
        });
        return decision.orElseThrow();
    }

    /** Observa si el elemento llega a ser visible dentro del tiempo máximo; no falla si no llega. */
    public boolean apareceEnTiempoMaximo(By localizador) {
        verificarIniciado();
        try {
            wait.until(ExpectedConditions.visibilityOfElementLocated(localizador));
            return true;
        } catch (TimeoutException exception) {
            logger.debug("El elemento {} no apareció dentro del tiempo máximo", localizador);
            return false;
        }
    }

    /**
     * Cuenta los elementos presentes que coinciden, una vez que el conteo se repitió en {@value #SONDEOS_ESTABLES}
     * sondeos consecutivos: un cero (o cualquier cifra) leído antes de que la página termine de pintar no se
     * acepta. Acotada por el tiempo máximo. El llamador debe haber comprobado antes que la página cargó.
     */
    public int contarEstable(By localizador) {
        verificarIniciado();
        AtomicInteger ultimoConteo = new AtomicInteger(-1);
        AtomicInteger sondeosConsecutivos = new AtomicInteger();
        return wait.until(webDriver -> {
            int conteo = webDriver.findElements(localizador).size();
            if (conteo == ultimoConteo.getAndSet(conteo)) {
                sondeosConsecutivos.incrementAndGet();
            } else {
                sondeosConsecutivos.set(1);
            }
            return sondeosConsecutivos.get() >= SONDEOS_ESTABLES ? Optional.of(conteo) : null;
        }).orElseThrow();
    }

    public void esperarInvisible(By localizador) {
        verificarIniciado();
        wait.until(ExpectedConditions.invisibilityOfElementLocated(localizador));
    }

    // --- Internos ---

    private void verificarIniciado() {
        if (driver == null) {
            throw new IllegalStateException(
                    "El navegador aún no fue iniciado para el escenario: llama a iniciar() antes de usarlo");
        }
    }

    private IllegalStateException errorDeNavegacion(String urlSolicitada, Optional<String> codigo) {
        String mensaje = BrowserErrorPage.describe(urlSolicitada, codigo);
        logger.error(mensaje);
        return new IllegalStateException(mensaje);
    }

    private Object ejecutarScriptConstante(String script) {
        try {
            return ((JavascriptExecutor) driver).executeScript(script);
        } catch (WebDriverException exception) {
            logger.debug("No se pudo leer el documento para detectar una página de error", exception);
            return null;
        }
    }

    private WebElement elementoVisible(By localizador) {
        return wait.until(ExpectedConditions.visibilityOfElementLocated(localizador));
    }

    /**
     * Pulsa hasta {@value #MAXIMO_CLICS_POR_ACCION} veces (el primero nativo, el resto con el respaldo JavaScript
     * para cuando Chrome pierde el evento) y espera la postcondición dentro del tiempo máximo. El respaldo solo
     * se aplica si 500 ms después del clic anterior la postcondición sigue sin cumplirse; con el tope agotado no
     * se pulsa más y solo se espera. Un control que alterna estado (agregar y quitar) podría revertirse con un
     * segundo clic si el primero sí se registró pero tardó en verse: por eso el tope es pequeño y se registra a
     * nivel INFO cada vez que hace falta un clic extra. Al agotarse el plazo lanza {@link TimeoutException} con
     * el localizador, los clics efectivos y el plazo. El localizador puede llevar el nombre de un producto del
     * escenario (dato propio de la prueba); el mensaje no incluye texto leído del SUT ni credenciales.
     */
    private void clickHastaCumplir(By localizador, ExpectedCondition<Boolean> postcondicion) {
        AtomicInteger clicsEfectivos = new AtomicInteger();
        try {
            wait.until(webDriver -> {
                if (Boolean.TRUE.equals(postcondicion.apply(webDriver))) {
                    return true;
                }
                if (clicsEfectivos.get() >= MAXIMO_CLICS_POR_ACCION) {
                    return false;
                }

                WebElement elemento = ExpectedConditions.elementToBeClickable(localizador).apply(webDriver);
                if (elemento == null) {
                    return false;
                }

                pulsar(webDriver, elemento, localizador, clicsEfectivos);
                return Boolean.TRUE.equals(postcondicion.apply(webDriver));
            });
        } catch (TimeoutException exception) {
            int clics = clicsEfectivos.get();
            throw new TimeoutException(
                    "El clic en %s no alcanzó su postcondición en %d s (clics efectivos: %d de %d permitidos%s)"
                            .formatted(localizador, TIEMPO_MAXIMO_ESPERA.toSeconds(), clics, MAXIMO_CLICS_POR_ACCION,
                                    clics == 0 ? "; el control nunca estuvo visible y habilitado" : ""),
                    exception);
        }
        if (clicsEfectivos.get() > 1) {
            logger.info("El clic en {} necesitó {} clics efectivos (respaldo JavaScript)", localizador,
                    clicsEfectivos.get());
        }
    }

    /** Primer clic nativo; los siguientes, con el respaldo JavaScript. Cuenta el clic antes de pulsar. */
    private void pulsar(WebDriver webDriver, WebElement elemento, By localizador, AtomicInteger clicsEfectivos) {
        if (clicsEfectivos.getAndIncrement() == 0) {
            elemento.click();
            return;
        }
        logger.debug("El clic anterior en {} no alcanzó su postcondición; se aplica el respaldo JavaScript",
                localizador);
        ((JavascriptExecutor) webDriver).executeScript("arguments[0].click();", elemento);
    }

    private boolean visibleAhora(WebDriver webDriver, By localizador) {
        try {
            List<WebElement> elementos = webDriver.findElements(localizador);
            return !elementos.isEmpty() && elementos.get(0).isDisplayed();
        } catch (WebDriverException exception) {
            logger.debug("El elemento {} no está visible", localizador, exception);
            return false;
        }
    }

    private void esperarValorEstable(By localizador, String textoEsperado) {
        AtomicInteger coincidenciasConsecutivas = new AtomicInteger();
        AtomicBoolean reintentoNativoRealizado = new AtomicBoolean();
        AtomicInteger correcciones = new AtomicInteger();
        wait.until(webDriver -> {
            WebElement elemento = ExpectedConditions.visibilityOfElementLocated(localizador).apply(webDriver);
            if (elemento == null) {
                coincidenciasConsecutivas.set(0);
                return false;
            }

            if (textoEsperado.equals(elemento.getDomProperty("value"))) {
                return coincidenciasConsecutivas.incrementAndGet() >= 2;
            }

            coincidenciasConsecutivas.set(0);
            correcciones.incrementAndGet();
            if (reintentoNativoRealizado.compareAndSet(false, true)) {
                elemento.clear();
                elemento.sendKeys(textoEsperado);
                return false;
            }

            logger.debug("La escritura nativa en {} no conservó su valor; se aplica el respaldo para input controlado",
                    localizador);
            ((JavascriptExecutor) webDriver).executeScript(
                    SCRIPT_ESCRIBIR_INPUT_CONTROLADO,
                    elemento,
                    textoEsperado);
            return false;
        });
        if (correcciones.get() > 0) {
            logger.info("La escritura en {} necesitó {} corrección(es) tras la escritura nativa", localizador,
                    correcciones.get());
        }
    }
}
