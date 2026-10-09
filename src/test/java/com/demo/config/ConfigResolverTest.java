package com.demo.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.function.UnaryOperator;
import org.junit.jupiter.api.Test;

/** Pruebas unitarias de la lógica de configuración (ADR-001, D3). Todas las fuentes están en memoria. */
class ConfigResolverTest {

    private final Map<String, String> system = new HashMap<>();
    private final Map<String, String> environment = new HashMap<>();
    private final Properties file = new Properties();
    private final ConfigResolver resolver = new ConfigResolver(system::get, environment::get, file);

    // --- Precedencia ---

    @Test
    void systemWinsOverEnvironmentAndFile() {
        system.put("a.b-c", "desde-sistema");
        environment.put("a.b-c", "entorno-exacto");
        environment.put("A_B_C", "entorno-normalizado");
        file.setProperty("a.b-c", "desde-archivo");

        assertEquals("desde-sistema", resolver.getRequired("a.b-c"));
    }

    @Test
    void exactEnvironmentWinsOverNormalizedEnvironmentAndFile() {
        environment.put("a.b-c", "entorno-exacto");
        environment.put("A_B_C", "entorno-normalizado");
        file.setProperty("a.b-c", "desde-archivo");

        assertEquals("entorno-exacto", resolver.getRequired("a.b-c"));
    }

    @Test
    void normalizedEnvironmentWinsOverFile() {
        environment.put("A_B_C", "entorno-normalizado");
        file.setProperty("a.b-c", "desde-archivo");

        assertEquals("entorno-normalizado", resolver.getRequired("a.b-c"));
    }

    @Test
    void fileIsUsedWhenNoOtherSourceHasTheKey() {
        file.setProperty("a.b-c", "desde-archivo");

        assertEquals("desde-archivo", resolver.getRequired("a.b-c"));
    }

    @Test
    void normalizationReplacesDotsAndHyphensWithUnderscoreAndUppercases() {
        environment.put("X_Y_Z", "valor-punto");
        environment.put("P_Q_R", "valor-guion");

        assertEquals("valor-punto", resolver.getRequired("x.y.z"));
        assertEquals("valor-guion", resolver.getRequired("p-q-r"));
    }

    @Test
    void normalizedKeyIsLookedUpWithoutKeepingTheOriginalCase() {
        environment.put("a_b", "no-debe-usarse");

        assertEquals("", resolver.getOptional("a.b"));
    }

    @Test
    void blankSystemValueDoesNotFallThroughToEnvironment() {
        system.put("k", "  ");
        environment.put("K", "entorno");

        assertEquals("  ", resolver.getOptional("k"));
    }

    @Test
    void emptySystemValueDoesNotFallThroughToFile() {
        system.put("k", "");
        file.setProperty("k", "archivo");

        assertEquals("", resolver.getOptional("k"));
    }

    @Test
    void blankExactEnvironmentValueDoesNotFallThroughToNormalizedEnvironment() {
        environment.put("a.b", "");
        environment.put("A_B", "normalizado");

        assertEquals("", resolver.getOptional("a.b"));
    }

    @Test
    void blankNormalizedEnvironmentValueDoesNotFallThroughToFile() {
        environment.put("A_B", " ");
        file.setProperty("a.b", "archivo");

        assertEquals(" ", resolver.getOptional("a.b"));
    }

    @Test
    void nullKeyThrowsNullPointerExceptionWithMessage() {
        NullPointerException exception = assertThrows(NullPointerException.class, () -> resolver.getOptional(null));

        assertEquals("La clave de configuración no puede ser null", exception.getMessage());
    }

    @Test
    void sourcesAreRequired() {
        UnaryOperator<String> lookup = system::get;

        assertEquals("La fuente del sistema no puede ser null",
                assertThrows(NullPointerException.class, () -> new ConfigResolver(null, lookup, file)).getMessage());
        assertEquals("La fuente del entorno no puede ser null",
                assertThrows(NullPointerException.class, () -> new ConfigResolver(lookup, null, file)).getMessage());
        assertEquals("La fuente del archivo no puede ser null",
                assertThrows(NullPointerException.class, () -> new ConfigResolver(lookup, lookup, null)).getMessage());
    }

    // --- Comportamiento actual fijado (P2 abiertos de MEMORY.md; se deciden aparte) ---

    @Test
    void environmentCanOverrideExpectedKeysTodayP2() {
        file.setProperty("cart.expected.single-product.count", "1");
        environment.put("CART_EXPECTED_SINGLE_PRODUCT_COUNT", "7");

        assertEquals(7, resolver.getPositiveInt("cart.expected.single-product.count"));
    }

    @Test
    void systemOverridesExpectedKeysSoTheNegativeControlWorks() {
        file.setProperty("cart.expected.single-product.count", "1");
        system.put("cart.expected.single-product.count", "2");

        assertEquals(2, resolver.getPositiveInt("cart.expected.single-product.count"));
    }

    @Test
    void positiveIntRejectsZeroTodayP2() {
        file.setProperty("n", "0");

        IllegalArgumentException exception = assertThrows(IllegalArgumentException.class,
                () -> resolver.getPositiveInt("n"));

        assertEquals("La configuración 'n' debe ser mayor que cero, pero fue '0'", exception.getMessage());
    }

    // --- getRequired ---

    @Test
    void getRequiredReturnsTheValueWithoutTrimming() {
        file.setProperty("k", " valor ");

        assertEquals(" valor ", resolver.getRequired("k"));
    }

    @Test
    void getRequiredRejectsMissingKeyNamingTheKey() {
        IllegalStateException exception = assertThrows(IllegalStateException.class,
                () -> resolver.getRequired("falta.clave"));

        assertEquals("La configuración obligatoria 'falta.clave' no tiene valor", exception.getMessage());
    }

    @Test
    void getRequiredRejectsEmptyAndBlankValuesWithoutRevealingThem() {
        file.setProperty("vacio", "");
        file.setProperty("blanco", "   ");

        IllegalStateException empty = assertThrows(IllegalStateException.class, () -> resolver.getRequired("vacio"));
        IllegalStateException blank = assertThrows(IllegalStateException.class, () -> resolver.getRequired("blanco"));

        assertEquals("La configuración obligatoria 'vacio' no tiene valor", empty.getMessage());
        assertEquals("La configuración obligatoria 'blanco' no tiene valor", blank.getMessage());
    }

    // --- getOptional ---

    @Test
    void getOptionalReturnsEmptyStringWhenMissing() {
        assertEquals("", resolver.getOptional("no.existe"));
    }

    @Test
    void getOptionalReturnsTheValueWhenPresent() {
        file.setProperty("k", "valor");

        assertEquals("valor", resolver.getOptional("k"));
    }

    // --- getBoolean ---

    @Test
    void getBooleanAcceptsTrueFalseAndPaddedValuesIgnoringCase() {
        file.setProperty("t", "true");
        file.setProperty("f", "FALSE");
        file.setProperty("p", " true ");
        file.setProperty("m", "False");

        assertTrue(resolver.getBoolean("t"));
        assertFalse(resolver.getBoolean("f"));
        assertTrue(resolver.getBoolean("p"));
        assertFalse(resolver.getBoolean("m"));
    }

    @Test
    void getBooleanRejectsYesAndOneNamingKeyAndValue() {
        file.setProperty("y", "yes");
        file.setProperty("u", "1");

        IllegalArgumentException yes = assertThrows(IllegalArgumentException.class, () -> resolver.getBoolean("y"));
        IllegalArgumentException one = assertThrows(IllegalArgumentException.class, () -> resolver.getBoolean("u"));

        assertEquals("La configuración 'y' debe ser true o false, pero fue 'yes'", yes.getMessage());
        assertEquals("La configuración 'u' debe ser true o false, pero fue '1'", one.getMessage());
    }

    @Test
    void getBooleanRejectsMissingKey() {
        assertThrows(IllegalStateException.class, () -> resolver.getBoolean("falta"));
    }

    @Test
    void getBooleanRejectsValueThatOnlyStartsWithTrueOrFalse() {
        file.setProperty("a", "truex");
        file.setProperty("b", "xfalse");

        assertThrows(IllegalArgumentException.class, () -> resolver.getBoolean("a"));
        assertThrows(IllegalArgumentException.class, () -> resolver.getBoolean("b"));
    }

    // --- getPositiveInt ---

    @Test
    void getPositiveIntAcceptsOneAndPaddedFive() {
        file.setProperty("uno", "1");
        file.setProperty("cinco", " 5 ");

        assertEquals(1, resolver.getPositiveInt("uno"));
        assertEquals(5, resolver.getPositiveInt("cinco"));
    }

    @Test
    void getPositiveIntRejectsNegativeNamingKeyAndValue() {
        file.setProperty("n", "-1");

        IllegalArgumentException exception = assertThrows(IllegalArgumentException.class,
                () -> resolver.getPositiveInt("n"));

        assertEquals("La configuración 'n' debe ser mayor que cero, pero fue '-1'", exception.getMessage());
        assertNull(exception.getCause());
    }

    @Test
    void getPositiveIntRejectsTextKeepingNumberFormatExceptionAsCause() {
        file.setProperty("n", "abc");

        IllegalArgumentException exception = assertThrows(IllegalArgumentException.class,
                () -> resolver.getPositiveInt("n"));

        assertEquals("La configuración 'n' debe ser un entero, pero fue 'abc'", exception.getMessage());
        assertInstanceOf(NumberFormatException.class, exception.getCause());
    }

    @Test
    void getPositiveIntAcceptsMaximumIntAndRejectsOverflow() {
        file.setProperty("max", "2147483647");
        file.setProperty("over", "2147483648");

        assertEquals(Integer.MAX_VALUE, resolver.getPositiveInt("max"));
        assertInstanceOf(NumberFormatException.class,
                assertThrows(IllegalArgumentException.class, () -> resolver.getPositiveInt("over")).getCause());
    }

    // --- getList ---

    @Test
    void getListSplitsAndTrimsElements() {
        file.setProperty("l", "a, b");

        assertEquals(List.of("a", "b"), resolver.getList("l"));
    }

    @Test
    void getListAcceptsASingleElement() {
        file.setProperty("l", " solo ");

        assertEquals(List.of("solo"), resolver.getList("l"));
    }

    @Test
    void getListKeepsElementOrder() {
        file.setProperty("l", "z,y,x");

        assertEquals(List.of("z", "y", "x"), resolver.getList("l"));
    }

    @Test
    void getListRejectsEmptyElementsNamingTheKey() {
        file.setProperty("medio", "a,,b");
        file.setProperty("final", "a,");
        file.setProperty("coma", ",");
        file.setProperty("inicio", ",a");
        file.setProperty("espacios", "a, ,b");

        for (String key : List.of("medio", "final", "coma", "inicio", "espacios")) {
            IllegalArgumentException exception = assertThrows(IllegalArgumentException.class,
                    () -> resolver.getList(key));
            assertEquals("La configuración '%s' contiene un elemento vacío".formatted(key), exception.getMessage());
        }
    }

    @Test
    void getListRejectsMissingKey() {
        assertThrows(IllegalStateException.class, () -> resolver.getList("falta"));
    }

    @Test
    void getListResultIsImmutable() {
        file.setProperty("l", "a,b");

        List<String> values = resolver.getList("l");

        assertThrows(UnsupportedOperationException.class, () -> values.add("c"));
    }
}
