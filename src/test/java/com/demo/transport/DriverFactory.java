package com.demo.transport;

import java.net.URL;
import java.time.Duration;
import org.openqa.selenium.Capabilities;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebDriverException;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.chrome.ChromeOptions;
import org.openqa.selenium.firefox.FirefoxDriver;
import org.openqa.selenium.firefox.FirefoxOptions;
import org.openqa.selenium.remote.RemoteWebDriver;
import com.demo.config.BrowserSettings;
import com.demo.config.ConfigResolver;
import com.demo.utils.ConfigReader;

/** Traduce {@link BrowserSettings} a opciones de Selenium y crea el driver (ADR-002, D8). */
final class DriverFactory {

    private DriverFactory() {
    }

    static WebDriver crear() {
        BrowserSettings settings = BrowserSettings.of(
                ConfigReader.getRequired("browser"),
                ConfigReader.getOptional("remote.url"),
                ConfigReader.getBoolean("headless"),
                () -> ConfigReader.getPositiveInt("browser.window.width"),
                () -> ConfigReader.getPositiveInt("browser.window.height"));

        WebDriver driver = switch (settings.browser()) {
            case CHROME -> createChromeDriver(settings);
            case FIREFOX -> createFirefoxDriver(settings);
        };

        driver.manage().timeouts().implicitlyWait(Duration.ZERO);
        if (!settings.headless()) {
            driver.manage().window().maximize();
        }
        return driver;
    }

    private static WebDriver createChromeDriver(BrowserSettings settings) {
        ChromeOptions options = new ChromeOptions();
        options.addArguments(settings.arguments());
        options.setExperimentalOption("prefs", settings.chromePreferences());

        return settings.remoteUrl().isPresent()
                ? crearRemoto(settings.remoteUrl().get(), options)
                : new ChromeDriver(options);
    }

    private static WebDriver createFirefoxDriver(BrowserSettings settings) {
        FirefoxOptions options = new FirefoxOptions();
        if (!settings.arguments().isEmpty()) {
            options.addArguments(settings.arguments());
        }

        return settings.remoteUrl().isPresent()
                ? crearRemoto(settings.remoteUrl().get(), options)
                : new FirefoxDriver(options);
    }

    /**
     * PI-09: si el Grid no crea la sesión, el error de Selenium repite la ruta y la consulta de la URL remota, que
     * pueden llevar una clave de acceso. Se relanza sin causa, con solo el host y el tipo de error.
     */
    private static WebDriver crearRemoto(URL remoteUrl, Capabilities options) {
        try {
            return new RemoteWebDriver(remoteUrl, options);
        } catch (WebDriverException exception) {
            throw new IllegalStateException("No se pudo crear la sesión en el Grid '%s' (%s)".formatted(
                    ConfigResolver.describeHost(remoteUrl.toString()), exception.getClass().getSimpleName()));
        }
    }
}
