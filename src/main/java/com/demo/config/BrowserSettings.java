package com.demo.config;

import java.net.MalformedURLException;
import java.net.URI;
import java.net.URL;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.function.IntSupplier;

/**
 * Decisiones puras sobre la configuración del navegador (ADR-002, D8).
 *
 * <p>Recibe los valores ya leídos y no toca el sistema, archivos ni Selenium. Normaliza y
 * valida el navegador, interpreta la URL remota (vacía significa ejecución local) y deriva
 * los argumentos de arranque. El ancho y el alto se piden solo en modo headless, como antes
 * de extraer la clase; por eso llegan como proveedores y no como enteros.</p>
 *
 * <p>Chrome lleva además la preferencia de perfil que desactiva la comprobación de contraseñas filtradas:
 * tras un inicio de sesión, su aviso modal (invisible en headless) hace que el navegador descarte los clics y
 * las teclas nativos dirigidos a la página mientras está abierto.</p>
 *
 * <p>Chrome arranca también sin la consulta de hora de red ({@value #CHROME_DISABLE_NETWORK_TIME}). Al arrancar, Chrome
 * pide la hora a un servicio de Google y, cuando llega la respuesta, reconstruye su verificador de certificados con esa
 * hora y corta las peticiones HTTPS en curso con {@code net::ERR_CERT_VERIFIER_CHANGED}. Si la respuesta llega mientras
 * la primera navegación al SUT está en vuelo, esa navegación falla. Sin la consulta, el verificador usa la hora del
 * sistema, como cualquier cliente TLS, y no se reconstruye después del arranque.</p>
 */
public final class BrowserSettings {

    /** Preferencia de perfil de Chrome que activa la comprobación de contraseñas filtradas tras un envío. */
    private static final String CHROME_LEAK_DETECTION_PREFERENCE = "profile.password_manager_leak_detection";

    /** Desactiva la consulta de hora de red, cuya respuesta reconstruye el verificador de certificados en vuelo. */
    private static final String CHROME_DISABLE_NETWORK_TIME = "--disable-features=NetworkTimeServiceQuerying";

    /** Navegadores soportados. */
    public enum Browser {
        CHROME,
        FIREFOX
    }

    private final Browser browser;
    private final boolean headless;
    private final URL remoteUrl;
    private final List<String> arguments;
    private final Map<String, Object> chromePreferences;

    private BrowserSettings(Browser browser, boolean headless, URL remoteUrl, List<String> arguments,
                            Map<String, Object> chromePreferences) {
        this.browser = browser;
        this.headless = headless;
        this.remoteUrl = remoteUrl;
        this.arguments = arguments;
        this.chromePreferences = chromePreferences;
    }

    /**
     * @param browser   nombre del navegador; se recorta y se pasa a minúsculas
     * @param remoteUrl URL del Grid; en blanco significa ejecución local
     * @param headless  si el navegador corre sin interfaz
     * @param width     ancho de ventana; solo se consulta si {@code headless} es verdadero
     * @param height    alto de ventana; solo se consulta si {@code headless} es verdadero
     * @throws IllegalArgumentException si el navegador no está soportado o la URL no es válida
     */
    public static BrowserSettings of(String browser, String remoteUrl, boolean headless,
                                     IntSupplier width, IntSupplier height) {
        Objects.requireNonNull(browser, "El navegador no puede ser null");
        Objects.requireNonNull(remoteUrl, "La URL remota no puede ser null");
        Objects.requireNonNull(width, "El proveedor del ancho no puede ser null");
        Objects.requireNonNull(height, "El proveedor del alto no puede ser null");

        String normalizedBrowser = browser.trim().toLowerCase(Locale.ROOT);
        Browser selectedBrowser = switch (normalizedBrowser) {
            case "chrome" -> Browser.CHROME;
            case "firefox" -> Browser.FIREFOX;
            default -> throw new IllegalArgumentException(
                    "Navegador no soportado: '%s'. Usa chrome o firefox".formatted(normalizedBrowser));
        };

        List<String> arguments = new ArrayList<>();
        if (selectedBrowser == Browser.CHROME) {
            arguments.add("--no-sandbox");
            arguments.add("--disable-dev-shm-usage");
            arguments.add("--disable-component-update");
            arguments.add(CHROME_DISABLE_NETWORK_TIME);
            if (headless) {
                arguments.add("--headless=new");
                arguments.add("--window-size=%d,%d".formatted(width.getAsInt(), height.getAsInt()));
            }
        } else if (headless) {
            arguments.add("-headless");
            arguments.add("--width=%d".formatted(width.getAsInt()));
            arguments.add("--height=%d".formatted(height.getAsInt()));
        }

        String trimmedRemoteUrl = remoteUrl.trim();
        URL parsedRemoteUrl = trimmedRemoteUrl.isBlank() ? null : toUrl(trimmedRemoteUrl);

        Map<String, Object> chromePreferences = selectedBrowser == Browser.CHROME
                ? Map.of(CHROME_LEAK_DETECTION_PREFERENCE, false)
                : Map.of();

        return new BrowserSettings(selectedBrowser, headless, parsedRemoteUrl, List.copyOf(arguments),
                chromePreferences);
    }

    public Browser browser() {
        return browser;
    }

    public boolean headless() {
        return headless;
    }

    /** Vacío en ejecución local. */
    public Optional<URL> remoteUrl() {
        return Optional.ofNullable(remoteUrl);
    }

    /** Argumentos de arranque en orden; inmutable. */
    public List<String> arguments() {
        return arguments;
    }

    /** Preferencias del perfil de Chrome; vacío con Firefox; inmutable. */
    public Map<String, Object> chromePreferences() {
        return chromePreferences;
    }

    /**
     * El error nunca lleva la URL ni la excepción original, cuyo mensaje la repite: una URL de Grid puede llevar su
     * clave en el usuario o en la consulta (PI-09). Solo nombra el host, como la línea de destino de red
     * (ADR-003, D6), y el tipo de error del JDK.
     */
    private static URL toUrl(String remoteUrl) {
        try {
            return URI.create(remoteUrl).toURL();
        } catch (IllegalArgumentException | MalformedURLException exception) {
            throw new IllegalArgumentException("La configuración remote.url no es una URL válida (host=%s, error=%s)"
                    .formatted(ConfigResolver.describeHost(remoteUrl), exception.getClass().getSimpleName()));
        }
    }
}
