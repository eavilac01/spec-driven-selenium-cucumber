package com.demo.transport;

import java.time.Duration;
import java.util.List;
import java.util.Optional;
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
import com.demo.config.ClicNativoUnico;
import com.demo.config.ConfigResolver;
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
    /** Sondeos consecutivos con el mismo resultado para dar por estable una lectura de ausencia o de conteo. */
    private static final int SONDEOS_ESTABLES = 2;
    /**
     * Pista fija de los fallos con un clic o una escritura nativos sin efecto (ADR-002, D1 y D8): la causa conocida
     * es el aviso de contraseñas filtradas de Chrome, que descarta la entrada nativa mientras está abierto.
     */
    private static final String PISTA_ENTRADA_NATIVA_SIN_EFECTO =
            "si ocurre en Chrome tras iniciar sesión, revisar las preferencias de Chrome (ADR-002, D8)";

    /** Constante (PI-05): centra en la ventana el elemento que recibe como único argumento. */
    private static final String SCRIPT_DESPLAZAR_AL_CENTRO = "arguments[0].scrollIntoView({block: 'center'});";

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
     * lleva solo el host de la URL solicitada ({@code ConfigResolver.describeHost}, PI-09) y, si es válido, el
     * código {@code net::ERR_…}; nunca el resto de la URL ni texto de la página.
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
            // PI-09: el mensaje de Selenium repite la URL completa (su comando "get"); solo viajan el host y el tipo.
            throw new IllegalStateException("La navegación a '%s' falló (%s)"
                    .formatted(ConfigResolver.describeHost(url), exception.getClass().getSimpleName()));
        }

        // El script devuelve null si el documento no es una página de error; si lo es, el texto del código.
        Object textoDelCodigo = leerCodigoPaginaError();
        if (textoDelCodigo instanceof String texto) {
            throw errorDeNavegacion(url, BrowserErrorPage.codeFromPageText(texto));
        }
        if (BrowserErrorPage.isErrorUrl(driver.getCurrentUrl())) {
            throw errorDeNavegacion(url, Optional.empty());
        }
    }

    /**
     * Espera a que la URL contenga el fragmento. Al agotarse el plazo, el mensaje lleva el fragmento y solo el host
     * de la URL actual (PI-09): la condición de Selenium repetiría la URL completa, con sus credenciales si las hay.
     */
    public void esperarUrlContiene(String fragmentoUrl) {
        verificarIniciado();
        try {
            wait.until(webDriver -> Boolean.TRUE.equals(ExpectedConditions.urlContains(fragmentoUrl).apply(webDriver)));
        } catch (TimeoutException exception) {
            throw new TimeoutException("La URL no llegó a contener '%s' en %d s (host actual: %s)"
                    .formatted(fragmentoUrl, TIEMPO_MAXIMO_ESPERA.toSeconds(),
                            ConfigResolver.describeHost(driver.getCurrentUrl())),
                    exception);
        }
    }

    /** Lectura inmediata, sin espera: indica si la URL actual contiene el fragmento. */
    public boolean urlContiene(String fragmentoUrl) {
        verificarIniciado();
        String urlActual = driver.getCurrentUrl();
        return urlActual != null && urlActual.contains(fragmentoUrl);
    }

    // --- Interacción con postcondición ---

    /**
     * Un solo clic nativo, sin postcondición observable propia: el propio clic la cumple. Si el control nunca está
     * visible y habilitado, falla como {@link #clickHastaCumplir(By, ExpectedCondition)} con 0 clics efectivos.
     */
    public void click(By localizador) {
        verificarIniciado();
        ClicNativoUnico clic = new ClicNativoUnico(localizador.toString());
        clickHastaCumplir(localizador, webDriver -> clic.clicsEfectivos() > 0, clic);
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
     * Hace un solo clic nativo en el control, como {@link #clickYEsperarUrlContiene}, y espera hasta que la URL
     * contenga el fragmento o se agote el tiempo máximo. Distingue tres estados: {@link ResultadoClic#AVANZO};
     * {@link ResultadoClic#NO_AVANZO}: tras el clic nativo (el control estuvo clicable y se pulsó) la URL no se
     * alcanzó; y {@link ResultadoClic#NO_DISPONIBLE}: el control no estuvo visible y habilitado en todo el tiempo
     * máximo, así que no hubo clic. Quien lo llama decide si "no disponible" es un resultado
     * válido; para que no sea un falso positivo debe comprobar antes que el resto de la página sí cargó.
     * Registra a nivel INFO el número de clics efectivos, nunca datos del escenario; con
     * {@link ResultadoClic#NO_AVANZO} añade la pista de D8, porque un clic nativo descartado por el navegador
     * también da ese resultado.
     */
    public ResultadoClic clickYObservarUrlContiene(By localizador, String fragmentoUrl) {
        verificarIniciado();
        ClicNativoUnico clic = new ClicNativoUnico(localizador.toString());
        try {
            wait.until(clicNativoUnicoHastaCumplir(localizador, ExpectedConditions.urlContains(fragmentoUrl), clic));
            logger.info("El clic en {} avanzó con {} clic(s) efectivo(s)", localizador, clic.clicsEfectivos());
            return ResultadoClic.AVANZO;
        } catch (TimeoutException exception) {
            int clics = clic.clicsEfectivos();
            if (clics == 0) {
                logger.info("El clic en {} no avanzó; clics efectivos: {}", localizador, clics);
                return ResultadoClic.NO_DISPONIBLE;
            }
            logger.info("El clic en {} no avanzó; clics efectivos: {}; {}", localizador, clics,
                    PISTA_ENTRADA_NATIVA_SIN_EFECTO);
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

    /** Exige que el control esté visible antes del clic: un localizador que no coincide no puede dar por cumplida la ausencia. */
    public void clickYEsperarInvisible(By localizador) {
        verificarIniciado();
        elementoVisible(localizador);
        clickHastaCumplir(localizador, ExpectedConditions.invisibilityOfElementLocated(localizador));
    }

    /** Escribe una sola vez de forma nativa y espera a que el campo conserve el valor; si no, falla. */
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
        ((JavascriptExecutor) driver).executeScript(SCRIPT_DESPLAZAR_AL_CENTRO, elemento);
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

    private Object leerCodigoPaginaError() {
        try {
            return ((JavascriptExecutor) driver).executeScript(SCRIPT_LEER_CODIGO_PAGINA_ERROR);
        } catch (WebDriverException exception) {
            logger.debug("No se pudo leer el documento para detectar una página de error", exception);
            return null;
        }
    }

    private WebElement elementoVisible(By localizador) {
        return wait.until(ExpectedConditions.visibilityOfElementLocated(localizador));
    }

    /**
     * Hace un solo clic nativo cuando el control está visible y habilitado, y espera la postcondición dentro del
     * tiempo máximo (ADR-002, D1; ADR-004, D2). No repite el clic: si la postcondición no se cumple, lanza
     * {@link TimeoutException} con el localizador, el plazo y los clics efectivos (0 o 1); con 1, añade la pista de
     * D8. El localizador puede llevar el nombre de un producto del escenario (dato propio de la prueba); el mensaje
     * no incluye texto leído del SUT ni credenciales.
     */
    private void clickHastaCumplir(By localizador, ExpectedCondition<Boolean> postcondicion) {
        clickHastaCumplir(localizador, postcondicion, new ClicNativoUnico(localizador.toString()));
    }

    /** Igual que {@link #clickHastaCumplir(By, ExpectedCondition)}, con el clic que la postcondición puede leer. */
    private void clickHastaCumplir(By localizador, ExpectedCondition<Boolean> postcondicion, ClicNativoUnico clic) {
        try {
            wait.until(clicNativoUnicoHastaCumplir(localizador, postcondicion, clic));
        } catch (TimeoutException exception) {
            int clics = clic.clicsEfectivos();
            throw new TimeoutException(
                    "El clic en %s no alcanzó su postcondición en %d s (clics efectivos: %d; %s)"
                            .formatted(localizador, TIEMPO_MAXIMO_ESPERA.toSeconds(), clics,
                                    clics == 0
                                            ? "el control nunca estuvo visible y habilitado"
                                            : "el clic nativo no tuvo efecto; " + PISTA_ENTRADA_NATIVA_SIN_EFECTO),
                    exception);
        }
    }

    /**
     * Condición de espera que delega cada sondeo en {@link ClicNativoUnico#sondear} (ADR-004, D2): es verdadera en
     * cuanto se cumple la postcondición; mientras no haya intento, pulsa el control si está visible y habilitado, y
     * solo cuenta la pulsación que retorna. Una pulsación que lanza sale como {@link IllegalStateException} con su
     * causa, sin contarse ni repetirse.
     */
    private static ExpectedCondition<Boolean> clicNativoUnicoHastaCumplir(
            By localizador, ExpectedCondition<Boolean> postcondicion, ClicNativoUnico clic) {
        return webDriver -> clic.sondear(
                () -> Boolean.TRUE.equals(postcondicion.apply(webDriver)),
                () -> pulsacionSiClicable(webDriver, localizador));
    }

    /** La pulsación nativa del control si está visible y habilitado; vacío si no. */
    private static Optional<Runnable> pulsacionSiClicable(WebDriver webDriver, By localizador) {
        WebElement elemento = ExpectedConditions.elementToBeClickable(localizador).apply(webDriver);
        if (elemento == null) {
            return Optional.empty();
        }
        return Optional.of(() -> {
            elemento.click();
        });
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

    /**
     * Espera a que el campo conserve el valor escrito en {@value #SONDEOS_ESTABLES} sondeos consecutivos, sin volver
     * a escribir (ADR-002, D1). El mensaje del fallo no incluye el texto, que puede ser una contraseña.
     */
    private void esperarValorEstable(By localizador, String textoEsperado) {
        AtomicInteger coincidenciasConsecutivas = new AtomicInteger();
        try {
            wait.until(webDriver -> {
                WebElement elemento = ExpectedConditions.visibilityOfElementLocated(localizador).apply(webDriver);
                if (elemento == null || !textoEsperado.equals(elemento.getDomProperty("value"))) {
                    coincidenciasConsecutivas.set(0);
                    return false;
                }
                return coincidenciasConsecutivas.incrementAndGet() >= SONDEOS_ESTABLES;
            });
        } catch (TimeoutException exception) {
            throw new TimeoutException(
                    "La escritura en %s no conservó el valor escrito en %d s; %s"
                            .formatted(localizador, TIEMPO_MAXIMO_ESPERA.toSeconds(), PISTA_ENTRADA_NATIVA_SIN_EFECTO),
                    exception);
        }
    }
}
