package com.demo.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.net.MalformedURLException;
import java.net.URI;
import java.net.URL;
import java.util.List;
import java.util.Properties;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.IntSupplier;
import org.junit.jupiter.api.Test;

/** Pruebas unitarias de las decisiones del navegador (ADR-002, D8). Todo está en memoria. */
class BrowserSettingsTest {

    private static final IntSupplier WIDTH = () -> 1920;
    private static final IntSupplier HEIGHT = () -> 1080;

    private static BrowserSettings of(String browser, String remoteUrl, boolean headless) {
        return BrowserSettings.of(browser, remoteUrl, headless, WIDTH, HEIGHT);
    }

    // --- Navegador ---

    @Test
    void chromeIsRecognized() {
        assertEquals(BrowserSettings.Browser.CHROME, of("chrome", "", false).browser());
    }

    @Test
    void firefoxIsRecognized() {
        assertEquals(BrowserSettings.Browser.FIREFOX, of("firefox", "", false).browser());
    }

    @Test
    void browserNameIgnoresCaseAndSurroundingSpaces() {
        assertEquals(BrowserSettings.Browser.CHROME, of("  ChRoMe\t", "", false).browser());
        assertEquals(BrowserSettings.Browser.FIREFOX, of(" FIREFOX ", "", false).browser());
    }

    @Test
    void unknownBrowserIsRejectedWithExactMessage() {
        IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                () -> of("safari", "", false));

        assertEquals("Navegador no soportado: 'safari'. Usa chrome o firefox", error.getMessage());
    }

    @Test
    void unknownBrowserMessageShowsTheNormalizedName() {
        IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                () -> of("  Edge ", "", true));

        assertEquals("Navegador no soportado: 'edge'. Usa chrome o firefox", error.getMessage());
    }

    @Test
    void emptyBrowserIsRejected() {
        IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                () -> of("   ", "", false));

        assertEquals("Navegador no soportado: ''. Usa chrome o firefox", error.getMessage());
    }

    @Test
    void browserNameIsNotAPrefixMatch() {
        assertEquals("Navegador no soportado: 'chrome2'. Usa chrome o firefox",
                assertThrows(IllegalArgumentException.class, () -> of("chrome2", "", false)).getMessage());
        assertEquals("Navegador no soportado: 'chrom'. Usa chrome o firefox",
                assertThrows(IllegalArgumentException.class, () -> of("chrom", "", false)).getMessage());
        assertEquals("Navegador no soportado: 'firefoxes'. Usa chrome o firefox",
                assertThrows(IllegalArgumentException.class, () -> of("firefoxes", "", false)).getMessage());
    }

    @Test
    void unknownBrowserFailsBeforeAskingForTheWindowSize() {
        AtomicInteger calls = new AtomicInteger();
        IntSupplier counting = () -> calls.incrementAndGet();

        assertThrows(IllegalArgumentException.class,
                () -> BrowserSettings.of("safari", "", true, counting, counting));

        assertEquals(0, calls.get());
    }

    // --- Headless y argumentos de Chrome ---

    @Test
    void chromeHeadfulUsesOnlyTheBaseArguments() {
        BrowserSettings settings = of("chrome", "", false);

        assertFalse(settings.headless());
        assertEquals(List.of("--no-sandbox", "--disable-dev-shm-usage", "--disable-component-update"),
                settings.arguments());
    }

    @Test
    void chromeHeadlessAddsHeadlessAndWindowSizeInOrder() {
        BrowserSettings settings = of("chrome", "", true);

        assertTrue(settings.headless());
        assertEquals(List.of("--no-sandbox", "--disable-dev-shm-usage", "--disable-component-update",
                "--headless=new", "--window-size=1920,1080"), settings.arguments());
    }

    @Test
    void chromeWindowSizePutsWidthBeforeHeight() {
        BrowserSettings settings = BrowserSettings.of("chrome", "", true, () -> 800, () -> 600);

        assertEquals("--window-size=800,600", settings.arguments().get(4));
    }

    // --- Argumentos de Firefox ---

    @Test
    void firefoxHeadfulHasNoArguments() {
        BrowserSettings settings = of("firefox", "", false);

        assertFalse(settings.headless());
        assertEquals(List.of(), settings.arguments());
    }

    @Test
    void firefoxHeadlessAddsHeadlessWidthAndHeightInOrder() {
        BrowserSettings settings = BrowserSettings.of("firefox", "", true, () -> 1280, () -> 720);

        assertTrue(settings.headless());
        assertEquals(List.of("-headless", "--width=1280", "--height=720"), settings.arguments());
    }

    // --- Dimensiones: se piden solo en headless ---

    @Test
    void windowSizeIsNotAskedWhenNotHeadless() {
        AtomicInteger calls = new AtomicInteger();
        IntSupplier counting = () -> calls.incrementAndGet();

        BrowserSettings.of("chrome", "", false, counting, counting);
        BrowserSettings.of("firefox", "", false, counting, counting);

        assertEquals(0, calls.get());
    }

    @Test
    void windowSizeIsAskedOncePerDimensionWhenHeadless() {
        AtomicInteger widthCalls = new AtomicInteger();
        AtomicInteger heightCalls = new AtomicInteger();

        BrowserSettings.of("chrome", "", true,
                () -> widthCalls.incrementAndGet(), () -> heightCalls.incrementAndGet());
        BrowserSettings.of("firefox", "", true,
                () -> widthCalls.incrementAndGet(), () -> heightCalls.incrementAndGet());

        assertEquals(2, widthCalls.get());
        assertEquals(2, heightCalls.get());
    }

    @Test
    void invalidWindowSizeFromTheResolverPropagatesItsMessageOnlyInHeadless() {
        Properties file = new Properties();
        file.setProperty("browser.window.width", "0");
        file.setProperty("browser.window.height", "-5");
        ConfigResolver resolver = new ConfigResolver(key -> null, key -> null, file);
        IntSupplier width = () -> resolver.getPositiveInt("browser.window.width");
        IntSupplier height = () -> resolver.getPositiveInt("browser.window.height");

        IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                () -> BrowserSettings.of("chrome", "", true, width, height));
        assertEquals("La configuración 'browser.window.width' debe ser mayor que cero, pero fue '0'",
                error.getMessage());

        file.setProperty("browser.window.width", "1920");
        IllegalArgumentException heightError = assertThrows(IllegalArgumentException.class,
                () -> BrowserSettings.of("firefox", "", true, width, height));
        assertEquals("La configuración 'browser.window.height' debe ser mayor que cero, pero fue '-5'",
                heightError.getMessage());

        assertEquals(List.of("--no-sandbox", "--disable-dev-shm-usage", "--disable-component-update"),
                BrowserSettings.of("chrome", "", false, width, height).arguments());
    }

    // --- URL remota ---

    @Test
    void emptyRemoteUrlMeansLocal() {
        assertTrue(of("chrome", "", false).remoteUrl().isEmpty());
    }

    @Test
    void blankRemoteUrlMeansLocal() {
        assertTrue(of("chrome", "   \t", false).remoteUrl().isEmpty());
        assertTrue(of("firefox", " ", true).remoteUrl().isEmpty());
    }

    @Test
    void nonEmptyRemoteUrlIsParsedAndTrimmed() {
        BrowserSettings settings = of("chrome", "  http://localhost:4444/wd/hub \n", false);

        assertTrue(settings.remoteUrl().isPresent());
        URL url = settings.remoteUrl().get();
        assertEquals("http", url.getProtocol());
        assertEquals("localhost", url.getHost());
        assertEquals(4444, url.getPort());
        assertEquals("/wd/hub", url.getPath());
        assertEquals("http://localhost:4444/wd/hub", url.toString());
    }

    @Test
    void remoteUrlDoesNotChangeTheArguments() {
        assertEquals(of("chrome", "", true).arguments(),
                of("chrome", "http://grid:4444", true).arguments());
        assertEquals(of("firefox", "", true).arguments(),
                of("firefox", "http://grid:4444", true).arguments());
    }

    @Test
    void urlWithoutSchemeIsRejectedWithExactMessageAndCause() {
        IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                () -> of("chrome", "localhost:4444", false));

        assertEquals("La configuración remote.url no es una URL válida: 'localhost:4444'", error.getMessage());
        assertEquals(MalformedURLException.class, error.getCause().getClass());
        // El esperado sale de la misma API del JDK con la misma entrada: no depende de la versión del texto.
        MalformedURLException delJdk = assertThrows(MalformedURLException.class,
                () -> URI.create("localhost:4444").toURL());
        assertEquals(delJdk.getMessage(), error.getCause().getMessage());
    }

    @Test
    void urlWithSpacesIsRejectedAsInvalid() {
        IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                () -> of("chrome", "http://not a url", false));

        assertEquals("La configuración remote.url no es una URL válida: 'http://not a url'", error.getMessage());
        assertEquals(IllegalArgumentException.class, error.getCause().getClass());
        // El esperado sale de la misma API del JDK con la misma entrada: no depende de la versión del texto.
        IllegalArgumentException delJdk = assertThrows(IllegalArgumentException.class,
                () -> URI.create("http://not a url"));
        assertEquals(delJdk.getMessage(), error.getCause().getMessage());
    }

    @Test
    void relativeUriIsRejectedAsInvalid() {
        IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                () -> of("firefox", "/wd/hub", false));

        assertEquals("La configuración remote.url no es una URL válida: '/wd/hub'", error.getMessage());
    }

    @Test
    void unknownProtocolIsRejectedAsInvalidWithItsCause() {
        IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                () -> of("chrome", "foo://grid:4444", false));

        assertEquals("La configuración remote.url no es una URL válida: 'foo://grid:4444'", error.getMessage());
        assertEquals(MalformedURLException.class, error.getCause().getClass());
        MalformedURLException delJdk = assertThrows(MalformedURLException.class,
                () -> URI.create("foo://grid:4444").toURL());
        assertEquals(delJdk.getMessage(), error.getCause().getMessage());
    }

    @Test
    void invalidUrlMessageShowsTheTrimmedValue() {
        IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                () -> of("chrome", "  nope  ", false));

        assertEquals("La configuración remote.url no es una URL válida: 'nope'", error.getMessage());
    }

    // --- Inmutabilidad y nulos ---

    @Test
    void argumentsAreImmutable() {
        BrowserSettings settings = of("chrome", "", true);

        assertThrows(UnsupportedOperationException.class, () -> settings.arguments().add("--extra"));
    }

    @Test
    void nullInputsAreRejectedWithClearMessages() {
        assertEquals("El navegador no puede ser null",
                assertThrows(NullPointerException.class, () -> of(null, "", false)).getMessage());
        assertEquals("La URL remota no puede ser null",
                assertThrows(NullPointerException.class, () -> of("chrome", null, false)).getMessage());
        assertEquals("El proveedor del ancho no puede ser null",
                assertThrows(NullPointerException.class,
                        () -> BrowserSettings.of("chrome", "", false, null, HEIGHT)).getMessage());
        assertEquals("El proveedor del alto no puede ser null",
                assertThrows(NullPointerException.class,
                        () -> BrowserSettings.of("chrome", "", false, WIDTH, null)).getMessage());
    }
}
