package com.demo.pages;

import java.time.Duration;
import java.util.List;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import org.openqa.selenium.By;
import org.openqa.selenium.JavascriptExecutor;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebDriverException;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.support.ui.ExpectedCondition;
import org.openqa.selenium.support.ui.ExpectedConditions;
import org.openqa.selenium.support.ui.WebDriverWait;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import com.demo.utils.ConfigReader;

public abstract class BasePage {

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

    protected final WebDriver driver;
    protected final WebDriverWait wait;
    protected final Logger logger;

    protected BasePage(WebDriver driver) {
        this.driver = Objects.requireNonNull(driver, "El WebDriver de la página no puede ser nulo");
        this.wait = new WebDriverWait(driver, TIEMPO_MAXIMO_ESPERA);
        this.logger = LoggerFactory.getLogger(getClass());
    }

    protected WebElement esperarVisible(By localizador) {
        return wait.until(ExpectedConditions.visibilityOfElementLocated(localizador));
    }

    protected void click(By localizador) {
        wait.until(ExpectedConditions.elementToBeClickable(localizador)).click();
    }

    protected void clickYEsperarTexto(By localizador, String textoEsperado) {
        clickHastaCumplir(localizador, ExpectedConditions.textToBePresentInElementLocated(
                localizador,
                textoEsperado));
    }

    protected void clickYEsperarUrlContiene(By localizador, String fragmentoUrl) {
        clickHastaCumplir(localizador, ExpectedConditions.urlContains(fragmentoUrl));
    }

    protected void escribir(By localizador, String texto) {
        WebElement elemento = esperarVisible(localizador);
        elemento.clear();
        elemento.sendKeys(texto);
        esperarValorEstable(localizador, texto);
    }

    protected String obtenerTexto(By localizador) {
        return esperarVisible(localizador).getText();
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

    protected boolean esVisible(By localizador) {
        try {
            List<WebElement> elementos = driver.findElements(localizador);
            return !elementos.isEmpty() && elementos.get(0).isDisplayed();
        } catch (WebDriverException exception) {
            logger.debug("El elemento {} no está visible", localizador, exception);
            return false;
        }
    }

    protected void esperarInvisibilidad(By localizador) {
        wait.until(ExpectedConditions.invisibilityOfElementLocated(localizador));
    }

    protected List<WebElement> obtenerTodos(By localizador) {
        return wait.until(ExpectedConditions.visibilityOfAllElementsLocatedBy(localizador));
    }

    protected void esperarUrlContiene(String fragmentoUrl) {
        wait.until(ExpectedConditions.urlContains(fragmentoUrl));
    }

    protected void scrollA(By localizador) {
        WebElement elemento = esperarVisible(localizador);
        ((JavascriptExecutor) driver).executeScript("arguments[0].scrollIntoView({block: 'center'});", elemento);
    }

    protected void abrirUrl(String url) {
        driver.navigate().to(url);
    }
}
