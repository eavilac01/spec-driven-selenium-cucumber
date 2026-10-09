package com.demo.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/**
 * Pruebas unitarias del parser de {@code .env} (ADR-001, D3). El contenido es sintético y en
 * memoria; los valores son inventados y nunca corresponden a credenciales reales.
 */
class DotEnvParserTest {

    // --- Líneas ignoradas ---

    @Test
    void emptyInputGivesEmptyMap() {
        assertEquals(Map.of(), DotEnvParser.parse(List.of()));
    }

    @Test
    void ignoresBlankAndCommentLines() {
        List<String> lines = List.of("", "   ", "# comentario", "   # comentario con sangría", "K=valor-secreto-1");

        assertEquals(Map.of("K", "valor-secreto-1"), DotEnvParser.parse(lines));
    }

    @Test
    void commentLineWithAssignmentIsIgnored() {
        assertEquals(Map.of(), DotEnvParser.parse(List.of("#K=valor-secreto-1")));
    }

    // --- Asignaciones ---

    @Test
    void parsesSimpleAssignment() {
        assertEquals(Map.of("K", "valor-secreto-1"), DotEnvParser.parse(List.of("K=valor-secreto-1")));
    }

    @Test
    void acceptsExportPrefix() {
        assertEquals(Map.of("K", "valor-secreto-1"), DotEnvParser.parse(List.of("export K=valor-secreto-1")));
    }

    @Test
    void acceptsExportPrefixFollowedByExtraSpaces() {
        assertEquals(Map.of("K", "valor-secreto-1"), DotEnvParser.parse(List.of("export    K=valor-secreto-1")));
    }

    @Test
    void exportWithoutSpaceIsPartOfTheKey() {
        assertEquals(Map.of("exportK", "valor-secreto-1"), DotEnvParser.parse(List.of("exportK=valor-secreto-1")));
    }

    @Test
    void doubleEqualsKeepsTheSecondOneInTheValue() {
        assertEquals(Map.of("K", "=valor-secreto-1"), DotEnvParser.parse(List.of("K==valor-secreto-1")));
    }

    @Test
    void valueMayContainEqualsInTheMiddleAndHashSigns() {
        assertEquals(Map.of("K", "a=b#c"), DotEnvParser.parse(List.of("K=a=b#c")));
    }

    @Test
    void trimsLineKeyAndValue() {
        assertEquals(Map.of("K", "valor-secreto-1"), DotEnvParser.parse(List.of("   K  =  valor-secreto-1   ")));
    }

    @Test
    void emptyValueIsAllowed() {
        assertEquals(Map.of("K", ""), DotEnvParser.parse(List.of("K=")));
    }

    @Test
    void acceptsLowercaseAndUnderscoreKeys() {
        Map<String, String> values = DotEnvParser.parse(List.of("k=a", "_K1=b", "Z9_=c"));

        assertEquals(Map.of("k", "a", "_K1", "b", "Z9_", "c"), values);
    }

    @Test
    void lastAssignmentOfARepeatedKeyWins() {
        assertEquals(Map.of("K", "segundo"), DotEnvParser.parse(List.of("K=primero", "K=segundo")));
    }

    @Test
    void parsesSeveralKeysInOneFile() {
        List<String> lines = List.of("A=valor-1", "", "# separador", "export B=valor-2", "C='valor-3'");

        assertEquals(Map.of("A", "valor-1", "B", "valor-2", "C", "valor-3"), DotEnvParser.parse(lines));
    }

    // --- Comillas ---

    @Test
    void removesDoubleQuotes() {
        assertEquals(Map.of("K", "v"), DotEnvParser.parse(List.of("K=\"v\"")));
    }

    @Test
    void removesSingleQuotes() {
        assertEquals(Map.of("K", "v"), DotEnvParser.parse(List.of("K='v'")));
    }

    @Test
    void removesOnlyOnePairOfQuotes() {
        assertEquals(Map.of("K", "\"v\""), DotEnvParser.parse(List.of("K=\"\"v\"\"")));
    }

    @Test
    void emptyQuotedValuesGiveEmptyString() {
        assertEquals(Map.of("A", "", "B", ""), DotEnvParser.parse(List.of("A=\"\"", "B=''")));
    }

    @Test
    void keepsQuotedValuePaddingInsideTheQuotes() {
        assertEquals(Map.of("K", " v "), DotEnvParser.parse(List.of("K=\" v \"")));
    }

    @Test
    void keepsMismatchedQuotes() {
        assertEquals(Map.of("A", "\"v'", "B", "'v\""), DotEnvParser.parse(List.of("A=\"v'", "B='v\"")));
    }

    @Test
    void keepsALoneQuoteCharacter() {
        assertEquals(Map.of("A", "\"", "B", "'"), DotEnvParser.parse(List.of("A=\"", "B='")));
    }

    @Test
    void keepsQuoteOnlyAtOneEnd() {
        assertEquals(Map.of("A", "\"v", "B", "v\""), DotEnvParser.parse(List.of("A=\"v", "B=v\"")));
    }

    // --- Rechazos: el error indica la línea y nunca el contenido ---

    @Test
    void rejectsLineWithoutKeyNamingTheLine() {
        IllegalStateException exception = assertThrows(IllegalStateException.class,
                () -> DotEnvParser.parse(List.of("=valor-secreto-1")));

        assertEquals("Formato inválido en .env, línea 1", exception.getMessage());
        assertDoesNotLeak(exception, "valor-secreto-1", "=valor-secreto-1");
    }

    @Test
    void rejectsLineWithoutEqualsNamingTheLine() {
        IllegalStateException exception = assertThrows(IllegalStateException.class,
                () -> DotEnvParser.parse(List.of("K valor-secreto-2")));

        assertEquals("Formato inválido en .env, línea 1", exception.getMessage());
        assertDoesNotLeak(exception, "valor-secreto-2", "K valor-secreto-2");
    }

    @Test
    void rejectsKeyOnlyLine() {
        IllegalStateException exception = assertThrows(IllegalStateException.class,
                () -> DotEnvParser.parse(List.of("SOLO_CLAVE")));

        assertEquals("Formato inválido en .env, línea 1", exception.getMessage());
    }

    @Test
    void rejectsExportWithoutAssignment() {
        IllegalStateException exception = assertThrows(IllegalStateException.class,
                () -> DotEnvParser.parse(List.of("export ")));

        assertEquals("Formato inválido en .env, línea 1", exception.getMessage());
    }

    @Test
    void rejectsExportFollowedByEmptyKey() {
        IllegalStateException exception = assertThrows(IllegalStateException.class,
                () -> DotEnvParser.parse(List.of("export =valor-secreto-3")));

        assertEquals("Formato inválido en .env, línea 1", exception.getMessage());
        assertDoesNotLeak(exception, "valor-secreto-3", "export =valor-secreto-3");
    }

    @Test
    void rejectsExportFollowedByOnlySpacesBeforeEquals() {
        IllegalStateException exception = assertThrows(IllegalStateException.class,
                () -> DotEnvParser.parse(List.of("export   =valor-secreto-9")));

        assertEquals("Formato inválido en .env, línea 1", exception.getMessage());
        assertDoesNotLeak(exception, "valor-secreto-9", "export   =valor-secreto-9");
    }

    @Test
    void rejectsKeyStartingWithDigitNamingTheLine() {
        IllegalStateException exception = assertThrows(IllegalStateException.class,
                () -> DotEnvParser.parse(List.of("1K=valor-secreto-4")));

        assertEquals("Nombre de variable inválido en .env, línea 1", exception.getMessage());
        assertDoesNotLeak(exception, "valor-secreto-4", "1K=valor-secreto-4");
    }

    @Test
    void rejectsKeyWithHyphenOrInnerSpace() {
        IllegalStateException hyphen = assertThrows(IllegalStateException.class,
                () -> DotEnvParser.parse(List.of("A-B=valor-secreto-5")));
        IllegalStateException space = assertThrows(IllegalStateException.class,
                () -> DotEnvParser.parse(List.of("A B=valor-secreto-6")));

        assertEquals("Nombre de variable inválido en .env, línea 1", hyphen.getMessage());
        assertEquals("Nombre de variable inválido en .env, línea 1", space.getMessage());
        assertDoesNotLeak(hyphen, "valor-secreto-5", "A-B=valor-secreto-5");
        assertDoesNotLeak(space, "valor-secreto-6", "A B=valor-secreto-6");
    }

    @Test
    void lineNumberCountsBlankAndCommentLines() {
        List<String> lines = List.of("A=valor-1", "", "# comentario", "1K=valor-secreto-7");

        IllegalStateException exception = assertThrows(IllegalStateException.class, () -> DotEnvParser.parse(lines));

        assertEquals("Nombre de variable inválido en .env, línea 4", exception.getMessage());
        assertDoesNotLeak(exception, "valor-secreto-7", "1K=valor-secreto-7");
    }

    @Test
    void formatErrorOnALaterLineNamesThatLine() {
        List<String> lines = List.of("A=valor-1", "B=valor-2", "sin igual valor-secreto-8");

        IllegalStateException exception = assertThrows(IllegalStateException.class, () -> DotEnvParser.parse(lines));

        assertEquals("Formato inválido en .env, línea 3", exception.getMessage());
        assertDoesNotLeak(exception, "valor-secreto-8", "sin igual valor-secreto-8");
    }

    @Test
    void nullLinesAreRejectedWithMessage() {
        NullPointerException exception = assertThrows(NullPointerException.class, () -> DotEnvParser.parse(null));

        assertEquals("Las líneas del .env no pueden ser null", exception.getMessage());
    }

    private static void assertDoesNotLeak(Exception exception, String secretValue, String fullLine) {
        assertFalse(exception.getMessage().contains(secretValue));
        assertFalse(exception.getMessage().contains(fullLine));
    }
}
