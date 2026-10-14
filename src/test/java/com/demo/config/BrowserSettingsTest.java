package com.demo.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.net.MalformedURLException;
import java.net.URI;
import java.net.URL;
import java.util.List;
import java.util.Map;
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

    // --- Preferencias del perfil de Chrome ---

    @Test
    void chromeDisablesPasswordLeakDetectionInEveryMode() {
        Map<String, Object> expected = Map.of("profile.password_manager_leak_detection", false);

        assertEquals(expected, of("chrome", "", true).chromePreferences());
        assertEquals(expected, of("chrome", "", false).chromePreferences());
        assertEquals(expected, of("chrome", "http://grid:4444", true).chromePreferences());
    }

    @Test
    void firefoxHasNoChromePreferences() {
        assertEquals(Map.of(), of("firefox", "", true).chromePreferences());
        assertEquals(Map.of(), of("firefox", "http://grid:4444", false).chromePreferences());
    }

    @Test
    void chromePreferencesAreImmutable() {
        BrowserSettings settings = of("chrome", "", true);

        assertThrows(UnsupportedOperationException.class,
                () -> settings.chromePreferences().put("profile.password_manager_leak_detection", true));
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

    // El tipo de error esperado sale de la misma API del JDK con la misma entrada; el mensaje y la causa nunca
    // llevan la URL (PI-09): solo su host, como la línea de destino de red (ADR-003, D6).

    @Test
    void urlWithoutSchemeIsRejectedWithoutTheValueAndWithoutCause() {
        IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                () -> of("chrome", "localhost:4444", false));

        assertThrows(MalformedURLException.class, () -> URI.create("localhost:4444").toURL());
        assertEquals("La configuración remote.url no es una URL válida (host=(invalido), error=MalformedURLException)",
                error.getMessage());
        assertNull(error.getCause());
    }

    @Test
    void urlWithSpacesIsRejectedAsInvalid() {
        IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                () -> of("chrome", "http://not a url", false));

        assertThrows(IllegalArgumentException.class, () -> URI.create("http://not a url"));
        assertEquals(
                "La configuración remote.url no es una URL válida (host=(invalido), error=IllegalArgumentException)",
                error.getMessage());
        assertNull(error.getCause());
    }

    @Test
    void relativeUriIsRejectedAsInvalid() {
        IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                () -> of("firefox", "/wd/hub", false));

        assertEquals(
                "La configuración remote.url no es una URL válida (host=(invalido), error=IllegalArgumentException)",
                error.getMessage());
    }

    @Test
    void unknownProtocolIsRejectedShowingOnlyItsHost() {
        IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                () -> of("chrome", "foo://grid:4444", false));

        assertThrows(MalformedURLException.class, () -> URI.create("foo://grid:4444").toURL());
        assertEquals("La configuración remote.url no es una URL válida (host=grid:4444, error=MalformedURLException)",
                error.getMessage());
        assertNull(error.getCause());
    }

    @Test
    void invalidUrlIsDescribedAfterTrimming() {
        IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                () -> of("chrome", "  foo://Grid.Example:4444  ", false));

        assertEquals("La configuración remote.url no es una URL válida"
                + " (host=grid.example:4444, error=MalformedURLException)", error.getMessage());
    }

    @Test
    void invalidUrlWithCredentialsNeverShowsThem() {
        for (String value : List.of("http://usuario:clave@ho st:4444/wd?token=secreto#frag",
                "foo://usuario:clave@grid.example:4444/wd?token=secreto#frag")) {
            IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                    () -> of("chrome", value, false));

            assertNull(error.getCause(), value);
            for (String secret : List.of("usuario", "clave", "secreto", "wd", "frag", "token")) {
                assertFalse(error.getMessage().contains(secret), secret);
            }
        }
        assertEquals("La configuración remote.url no es una URL válida"
                        + " (host=grid.example:4444, error=MalformedURLException)",
                assertThrows(IllegalArgumentException.class, () -> of("chrome",
                        "foo://usuario:clave@grid.example:4444/wd?token=secreto#frag", false)).getMessage());
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
