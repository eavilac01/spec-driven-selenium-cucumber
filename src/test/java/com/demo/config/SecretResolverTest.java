package com.demo.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.UnaryOperator;
import org.junit.jupiter.api.Test;

/**
 * Pruebas unitarias de la resolución de secretos (ADR-001, D3). Las fuentes están en memoria y
 * los valores son inventados; no se toca {@code SecretReader} ni el {@code .env} real.
 */
class SecretResolverTest {

    private final Map<String, String> environment = new HashMap<>();
    private final Map<String, String> dotEnv = new HashMap<>();

    private SecretResolver resolver() {
        return new SecretResolver(environment::get, dotEnv);
    }

    // --- Nombre de variable ---

    @Test
    void acceptsUpperCaseAndUnderscoreNames() {
        environment.put("A", "valor-secreto-1");
        environment.put("_X1", "valor-secreto-2");

        assertEquals("valor-secreto-1", resolver().getRequired("A"));
        assertEquals("valor-secreto-2", resolver().getRequired("_X1"));
    }

    @Test
    void acceptsNamesWithDigitsAndUnderscoresInside() {
        environment.put("TEST_USER_9_PASSWORD", "valor-secreto-3");

        assertEquals("valor-secreto-3", resolver().getRequired("TEST_USER_9_PASSWORD"));
    }

    @Test
    void rejectsInvalidNamesNamingThem() {
        for (String invalid : List.of("a", "1A", "A-B", "", "A B", "Ab")) {
            environment.put(invalid, "valor-secreto-4");

            IllegalArgumentException exception = assertThrows(IllegalArgumentException.class,
                    () -> resolver().getRequired(invalid));

            assertEquals("Nombre de variable de entorno no válido: " + invalid, exception.getMessage());
            assertFalse(exception.getMessage().contains("valor-secreto-4"));
        }
    }

    @Test
    void rejectsNameWithTrailingLineBreakEvenIfTheEnvironmentHasIt() {
        environment.put("A\n", "valor-secreto-5");

        assertThrows(IllegalArgumentException.class, () -> resolver().getRequired("A\n"));
    }

    @Test
    void nullNameIsRejectedWithMessage() {
        NullPointerException exception = assertThrows(NullPointerException.class,
                () -> resolver().getRequired(null));

        assertEquals("El nombre de la variable no puede ser null", exception.getMessage());
    }

    // --- Precedencia ---

    @Test
    void environmentWinsOverDotEnv() {
        environment.put("K", "valor-secreto-entorno");
        dotEnv.put("K", "valor-secreto-dotenv");

        assertEquals("valor-secreto-entorno", resolver().getRequired("K"));
    }

    @Test
    void dotEnvIsUsedWhenTheEnvironmentHasNoValue() {
        dotEnv.put("K", "valor-secreto-dotenv");

        assertEquals("valor-secreto-dotenv", resolver().getRequired("K"));
    }

    @Test
    void valueIsReturnedWithoutTrimming() {
        environment.put("K", " valor-secreto-6 ");

        assertEquals(" valor-secreto-6 ", resolver().getRequired("K"));
    }

    @Test
    void worksWithTheOutputOfTheParser() {
        Map<String, String> parsed = DotEnvParser.parse(List.of("export K=\"valor-secreto-7\""));

        assertEquals("valor-secreto-7", new SecretResolver(environment::get, parsed).getRequired("K"));
    }

    @Test
    void laterChangesToTheDotEnvMapDoNotAffectTheResolver() {
        dotEnv.put("K", "valor-secreto-8");
        SecretResolver resolver = resolver();

        dotEnv.put("K", "valor-secreto-9");

        assertEquals("valor-secreto-8", resolver.getRequired("K"));
    }

    // --- Ausente o en blanco ---

    @Test
    void missingSecretThrowsIllegalStateNamingTheVariable() {
        IllegalStateException exception = assertThrows(IllegalStateException.class,
                () -> resolver().getRequired("FALTA"));

        assertEquals("La variable sensible obligatoria 'FALTA' no tiene valor", exception.getMessage());
    }

    @Test
    void emptyAndBlankSecretsThrowIllegalState() {
        environment.put("VACIO", "");
        environment.put("BLANCO", "   ");
        dotEnv.put("VACIO_DOTENV", "");
        dotEnv.put("BLANCO_DOTENV", "\t ");

        for (String name : List.of("VACIO", "BLANCO", "VACIO_DOTENV", "BLANCO_DOTENV")) {
            IllegalStateException exception = assertThrows(IllegalStateException.class,
                    () -> resolver().getRequired(name));

            assertEquals("La variable sensible obligatoria '%s' no tiene valor".formatted(name),
                    exception.getMessage());
        }
    }

    @Test
    void blankEnvironmentValueDoesNotFallThroughToDotEnvAndDoesNotRevealIt() {
        environment.put("K", "   ");
        dotEnv.put("K", "valor-secreto-10");

        IllegalStateException exception = assertThrows(IllegalStateException.class,
                () -> resolver().getRequired("K"));

        assertEquals("La variable sensible obligatoria 'K' no tiene valor", exception.getMessage());
        assertFalse(exception.getMessage().contains("valor-secreto-10"));
    }

    @Test
    void emptyEnvironmentValueDoesNotFallThroughToDotEnv() {
        environment.put("K", "");
        dotEnv.put("K", "valor-secreto-11");

        IllegalStateException exception = assertThrows(IllegalStateException.class,
                () -> resolver().getRequired("K"));

        assertFalse(exception.getMessage().contains("valor-secreto-11"));
    }

    @Test
    void unicodeSpaceOnlySecretIsBlank() {
        environment.put("K", "\u2003");

        IllegalStateException exception = assertThrows(IllegalStateException.class,
                () -> resolver().getRequired("K"));

        assertEquals("La variable sensible obligatoria 'K' no tiene valor", exception.getMessage());
    }

    // --- Fuentes obligatorias ---

    @Test
    void sourcesAreRequired() {
        UnaryOperator<String> lookup = environment::get;

        assertEquals("La fuente del entorno no puede ser null",
                assertThrows(NullPointerException.class, () -> new SecretResolver(null, dotEnv)).getMessage());
        assertEquals("La fuente del .env no puede ser null",
                assertThrows(NullPointerException.class, () -> new SecretResolver(lookup, null)).getMessage());
    }
}
