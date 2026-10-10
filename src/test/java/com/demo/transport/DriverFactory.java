package com.demo.transport;

import java.net.MalformedURLException;
import java.net.URI;
import java.net.URL;
import java.time.Duration;
import java.util.Locale;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.chrome.ChromeOptions;
import org.openqa.selenium.firefox.FirefoxDriver;
import org.openqa.selenium.firefox.FirefoxOptions;
import org.openqa.selenium.remote.RemoteWebDriver;
import com.demo.utils.ConfigReader;

final class DriverFactory {

    private DriverFactory() {
    }

    static WebDriver crear() {
        String browser = ConfigReader.getRequired("browser")
                .trim()
                .toLowerCase(Locale.ROOT);
        String remoteUrl = ConfigReader.getOptional("remote.url").trim();
        boolean headless = ConfigReader.getBoolean("headless");

        WebDriver driver = switch (browser) {
            case "chrome" -> createChromeDriver(remoteUrl, headless);
            case "firefox" -> createFirefoxDriver(remoteUrl, headless);
            default -> throw new IllegalArgumentException(
                    "Navegador no soportado: '%s'. Usa chrome o firefox".formatted(browser));
        };

        driver.manage().timeouts().implicitlyWait(Duration.ZERO);
        if (!headless) {
            driver.manage().window().maximize();
        }
        return driver;
    }

    private static WebDriver createChromeDriver(String remoteUrl, boolean headless) {
        ChromeOptions options = new ChromeOptions();
        options.addArguments("--no-sandbox", "--disable-dev-shm-usage");
        if (headless) {
            options.addArguments(
                    "--headless=new",
                    "--window-size=%d,%d".formatted(
                            ConfigReader.getPositiveInt("browser.window.width"),
                            ConfigReader.getPositiveInt("browser.window.height")));
        }

        return isRemote(remoteUrl)
                ? new RemoteWebDriver(toUrl(remoteUrl), options)
                : new ChromeDriver(options);
    }

    private static WebDriver createFirefoxDriver(String remoteUrl, boolean headless) {
        FirefoxOptions options = new FirefoxOptions();
        if (headless) {
            options.addArguments(
                    "-headless",
                    "--width=%d".formatted(ConfigReader.getPositiveInt("browser.window.width")),
                    "--height=%d".formatted(ConfigReader.getPositiveInt("browser.window.height")));
        }

        return isRemote(remoteUrl)
                ? new RemoteWebDriver(toUrl(remoteUrl), options)
                : new FirefoxDriver(options);
    }

    private static boolean isRemote(String remoteUrl) {
        return !remoteUrl.isBlank();
    }

    private static URL toUrl(String remoteUrl) {
        try {
            return URI.create(remoteUrl).toURL();
        } catch (IllegalArgumentException | MalformedURLException exception) {
            throw new IllegalArgumentException(
                    "La configuración remote.url no es una URL válida: '%s'".formatted(remoteUrl), exception);
        }
    }
}
