package com.demo.data;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

import org.junit.jupiter.api.Test;

/**
 * Pruebas unitarias de {@link Credentials} (ADR-001, D3). Los valores son inventados; no se toca
 * {@code CredentialsProvider} ni el {@code .env} real.
 */
class CredentialsTest {

    private static final String USERNAME = "usuario-sintetico";
    private static final String PASSWORD = "clave-sintetica-1";

    @Test
    void toStringIsExactlyTheMaskedForm() {
        Credentials credentials = new Credentials(USERNAME, PASSWORD);

        assertEquals("Credentials[username=***, password=***]", credentials.toString());
    }

    @Test
    void toStringDoesNotContainUsernameNorPassword() {
        String text = new Credentials(USERNAME, PASSWORD).toString();

        assertFalse(text.contains(USERNAME));
        assertFalse(text.contains(PASSWORD));
    }

    @Test
    void stringConcatenationAndFormattingUseTheMaskedForm() {
        Credentials credentials = new Credentials(USERNAME, PASSWORD);

        assertEquals("c=Credentials[username=***, password=***]", "c=" + credentials);
        assertEquals("c=Credentials[username=***, password=***]", "c=%s".formatted(credentials));
    }

    @Test
    void accessorsReturnTheGivenValues() {
        Credentials credentials = new Credentials(USERNAME, PASSWORD);

        assertEquals(USERNAME, credentials.username());
        assertEquals(PASSWORD, credentials.password());
    }

    @Test
    void accessorsKeepUsernameAndPasswordSeparate() {
        Credentials credentials = new Credentials("usuario-sintetico-2", "clave-sintetica-2");

        assertEquals("usuario-sintetico-2", credentials.username());
        assertEquals("clave-sintetica-2", credentials.password());
    }

    @Test
    void emptyValuesAreAcceptedKeptAsEmptyAndStillMasked() {
        Credentials emptyUsername = new Credentials("", PASSWORD);
        Credentials emptyPassword = new Credentials(USERNAME, "");
        Credentials emptyBoth = new Credentials("", "");

        assertEquals("", emptyUsername.username());
        assertEquals(PASSWORD, emptyUsername.password());
        assertEquals(USERNAME, emptyPassword.username());
        assertEquals("", emptyPassword.password());
        assertEquals("", emptyBoth.username());
        assertEquals("", emptyBoth.password());
        assertEquals("Credentials[username=***, password=***]", emptyBoth.toString());
        assertFalse(emptyUsername.toString().contains(PASSWORD));
        assertFalse(emptyPassword.toString().contains(USERNAME));
    }
}
