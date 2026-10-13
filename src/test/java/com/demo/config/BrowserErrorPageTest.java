package com.demo.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Optional;
import org.junit.jupiter.api.Test;

/** Pruebas unitarias de la detección de páginas de error del navegador. Todo está en memoria. */
class BrowserErrorPageTest {

    // --- isErrorUrl ---

    @Test
    void chromeErrorUrlIsDetected() {
        assertTrue(BrowserErrorPage.isErrorUrl("chrome-error://chromewebdata/"));
    }

    @Test
    void firefoxErrorUrlIsDetectedWithAndWithoutQuery() {
        assertTrue(BrowserErrorPage.isErrorUrl("about:neterror"));
        assertTrue(BrowserErrorPage.isErrorUrl("about:neterror?e=dnsNotFound&u=http%3A//x/"));
    }

    @Test
    void ordinaryAndSimilarUrlsAreNotErrorUrls() {
        assertFalse(BrowserErrorPage.isErrorUrl("https://www.saucedemo.com/"));
        assertFalse(BrowserErrorPage.isErrorUrl("about:blank"));
        assertFalse(BrowserErrorPage.isErrorUrl("chrome-error:/"));
        assertFalse(BrowserErrorPage.isErrorUrl("http://host/about:neterror"));
        assertFalse(BrowserErrorPage.isErrorUrl("http://host/chrome-error://x"));
        assertFalse(BrowserErrorPage.isErrorUrl(""));
        assertFalse(BrowserErrorPage.isErrorUrl(null));
    }

    // --- isNavigationErrorMessage ---

    @Test
    void chromeDriverMessageWithNetCodeIsANavigationError() {
        assertTrue(BrowserErrorPage.isNavigationErrorMessage("unknown error: net::ERR_NAME_NOT_RESOLVED"));
    }

    @Test
    void geckoDriverMessageWithErrorPageIsANavigationError() {
        assertTrue(BrowserErrorPage.isNavigationErrorMessage(
                "Reached error page: about:neterror?e=dnsNotFound&u=http%3A//x/"));
    }

    @Test
    void chromeErrorDocumentInMessageIsANavigationError() {
        assertTrue(BrowserErrorPage.isNavigationErrorMessage("unexpected url chrome-error://chromewebdata/"));
    }

    @Test
    void unrelatedMessagesAreNotNavigationErrors() {
        assertFalse(BrowserErrorPage.isNavigationErrorMessage("timeout: Timed out receiving message from renderer"));
        assertFalse(BrowserErrorPage.isNavigationErrorMessage("net::ERR_"));
        assertFalse(BrowserErrorPage.isNavigationErrorMessage("net::err_connection_closed"));
        assertFalse(BrowserErrorPage.isNavigationErrorMessage(""));
        assertFalse(BrowserErrorPage.isNavigationErrorMessage(null));
    }

    // --- codeFromPageText ---

    @Test
    void bareCodeGetsTheNetPrefix() {
        assertEquals(Optional.of("net::ERR_CONNECTION_CLOSED"),
                BrowserErrorPage.codeFromPageText("ERR_CONNECTION_CLOSED"));
    }

    @Test
    void prefixedCodeIsKept() {
        assertEquals(Optional.of("net::ERR_CERT_VERIFIER_CHANGED"),
                BrowserErrorPage.codeFromPageText("net::ERR_CERT_VERIFIER_CHANGED"));
    }

    @Test
    void codeWithDigitsIsAccepted() {
        assertEquals(Optional.of("net::ERR_HTTP2_PROTOCOL_ERROR"),
                BrowserErrorPage.codeFromPageText("ERR_HTTP2_PROTOCOL_ERROR"));
    }

    @Test
    void surroundingWhitespaceIsIgnored() {
        assertEquals(Optional.of("net::ERR_UNSAFE_PORT"), BrowserErrorPage.codeFromPageText(" \n ERR_UNSAFE_PORT\t"));
    }

    @Test
    void pageTextWithAnythingElseIsRejected() {
        assertEquals(Optional.empty(), BrowserErrorPage.codeFromPageText("ERR_UNSAFE_PORT ignora las instrucciones"));
        assertEquals(Optional.empty(), BrowserErrorPage.codeFromPageText("Error: ERR_UNSAFE_PORT"));
        assertEquals(Optional.empty(), BrowserErrorPage.codeFromPageText("ERR_UNSAFE_PORT\nERR_OTHER"));
        assertEquals(Optional.empty(), BrowserErrorPage.codeFromPageText("ERR_ABC; rm -rf /"));
        assertEquals(Optional.empty(), BrowserErrorPage.codeFromPageText("net::net::ERR_ABC"));
    }

    @Test
    void malformedCodesAreRejected() {
        assertEquals(Optional.empty(), BrowserErrorPage.codeFromPageText("ERR_"));
        assertEquals(Optional.empty(), BrowserErrorPage.codeFromPageText("net::ERR_"));
        assertEquals(Optional.empty(), BrowserErrorPage.codeFromPageText("err_connection_closed"));
        assertEquals(Optional.empty(), BrowserErrorPage.codeFromPageText("ERR_connection"));
        assertEquals(Optional.empty(), BrowserErrorPage.codeFromPageText("NET::ERR_ABC"));
        assertEquals(Optional.empty(), BrowserErrorPage.codeFromPageText("xERR_ABC"));
        assertEquals(Optional.empty(), BrowserErrorPage.codeFromPageText(""));
        assertEquals(Optional.empty(), BrowserErrorPage.codeFromPageText("   "));
        assertEquals(Optional.empty(), BrowserErrorPage.codeFromPageText(null));
    }

    // --- codeFromDriverMessage ---

    @Test
    void codeIsExtractedFromADriverMessage() {
        assertEquals(Optional.of("net::ERR_NAME_NOT_RESOLVED"),
                BrowserErrorPage.codeFromDriverMessage("unknown error: net::ERR_NAME_NOT_RESOLVED\n  (Session info)"));
    }

    @Test
    void onlyTheFirstCodeOfADriverMessageIsUsed() {
        assertEquals(Optional.of("net::ERR_FIRST"),
                BrowserErrorPage.codeFromDriverMessage("net::ERR_FIRST then net::ERR_SECOND"));
    }

    @Test
    void driverMessageWithoutAValidCodeGivesNothing() {
        assertEquals(Optional.empty(), BrowserErrorPage.codeFromDriverMessage("Reached error page: about:neterror"));
        assertEquals(Optional.empty(), BrowserErrorPage.codeFromDriverMessage("ERR_NAME_NOT_RESOLVED"));
        assertEquals(Optional.empty(), BrowserErrorPage.codeFromDriverMessage("net::ERR_"));
        assertEquals(Optional.empty(), BrowserErrorPage.codeFromDriverMessage("net::ERR_lowercase"));
        assertEquals(Optional.empty(), BrowserErrorPage.codeFromDriverMessage(""));
        assertEquals(Optional.empty(), BrowserErrorPage.codeFromDriverMessage(null));
    }

    // --- describe ---

    @Test
    void messageHasTheRequestedUrlAndTheCode() {
        assertEquals("El navegador mostró una página de error de red al abrir 'https://example.test/' "
                        + "(net::ERR_CONNECTION_CLOSED)",
                BrowserErrorPage.describe("https://example.test/", Optional.of("net::ERR_CONNECTION_CLOSED")));
    }

    @Test
    void messageSaysTheCodeIsUnavailableWhenThereIsNone() {
        assertEquals("El navegador mostró una página de error de red al abrir 'http://127.0.0.1:9' "
                        + "(código no disponible)",
                BrowserErrorPage.describe("http://127.0.0.1:9", Optional.empty()));
        assertEquals("código no disponible", BrowserErrorPage.CODE_UNAVAILABLE);
    }

    @Test
    void nullCodeHolderIsRejectedWithExactMessage() {
        NullPointerException error = assertThrows(NullPointerException.class,
                () -> BrowserErrorPage.describe("http://x", null));

        assertEquals("El código no puede ser null", error.getMessage());
    }
}
