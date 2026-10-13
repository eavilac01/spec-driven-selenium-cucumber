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
                throw errorDeNavegacion(url, BrowserErrorPage.codeFromDriverMessage(exception.getMessage()));
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

    /** Resultado de {@link #clickYObservarUrlContiene}: la URL esperada se alcanzó o no, con clics efectivos. */
    public enum ResultadoClic {
        AVANZO,
        NO_AVANZO
    }

    /**
     * Hace clic en el control, con el mismo respaldo de clic repetido que {@link #clickYEsperarUrlContiene},
     * hasta que la URL contenga el fragmento o se agote el tiempo máximo. Distingue tres estados:
     * {@link ResultadoClic#AVANZO}; {@link ResultadoClic#NO_AVANZO} con al menos un clic efectivo (el control
     * estuvo clicable y se pulsó); y control no disponible (nunca clicable, ningún clic), que lanza
     * {@link IllegalStateException} porque no prueba nada y no debe leerse como "no avanza".
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
                WebElement elemento = ExpectedConditions.elementToBeClickable(localizador).apply(webDriver);
                if (elemento == null) {
                    return false;
                }
                if (clicsEfectivos.getAndIncrement() == 0) {
                    elemento.click();
                } else {
                    ((JavascriptExecutor) webDriver).executeScript("arguments[0].click();", elemento);
                }
                return Boolean.TRUE.equals(urlEsperada.apply(webDriver));
            });
            logger.info("El clic en {} avanzó con {} clic(s) efectivo(s)", localizador, clicsEfectivos.get());
            return ResultadoClic.AVANZO;
        } catch (TimeoutException exception) {
            int clics = clicsEfectivos.get();
            logger.info("El clic en {} no avanzó; clics efectivos: {}", localizador, clics);
            if (clics == 0) {
                throw new IllegalStateException(
                        "El control %s no estuvo disponible para hacer clic: la observación no es válida"
                                .formatted(localizador),
                        exception);
            }
            return ResultadoClic.NO_AVANZO;
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

    public void clickYEsperarInvisible(By localizador) {
        verificarIniciado();
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

    public boolean esVisible(By localizador) {
        verificarIniciado();
        try {
            List<WebElement> elementos = driver.findElements(localizador);
            return !elementos.isEmpty() && elementos.get(0).isDisplayed();
        } catch (WebDriverException exception) {
            logger.debug("El elemento {} no está visible", localizador, exception);
            return false;
        }
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

    /** Lectura inmediata, sin espera: cuenta los elementos presentes que coinciden. */
    public int contar(By localizador) {
        verificarIniciado();
        return driver.findElements(localizador).size();
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

    private void clickHastaCumplir(By localizador, ExpectedCondition<Boolean> postcondicion) {
        AtomicBoolean clicNativoIntentado = new AtomicBoolean();
        wait.until(webDriver -> {
            if (Boolean.TRUE.equals(postcondicion.apply(webDriver))) {
                return true;
            }

            WebElement elemento = ExpectedConditions.elementToBeClickable(localizador).apply(webDriver);
            if (elemento == null) {
                return false;
            }

            if (clicNativoIntentado.compareAndSet(false, true)) {
                elemento.click();
                return Boolean.TRUE.equals(postcondicion.apply(webDriver));
            }

            logger.debug("El clic nativo en {} no alcanzó su postcondición; se aplica el respaldo JavaScript",
                    localizador);
            ((JavascriptExecutor) webDriver).executeScript("arguments[0].click();", elemento);
            return Boolean.TRUE.equals(postcondicion.apply(webDriver));
        });
    }

    private void esperarValorEstable(By localizador, String textoEsperado) {
        AtomicInteger coincidenciasConsecutivas = new AtomicInteger();
        AtomicBoolean reintentoNativoRealizado = new AtomicBoolean();
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
    }
}
