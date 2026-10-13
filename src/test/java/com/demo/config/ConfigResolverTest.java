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

    // --- Valores esperados y destinos de red sin entorno (ADR-003) ---

    @Test
    void environmentDoesNotOverrideExpectedKeys() {
        file.setProperty("cart.expected.single-product.count", "1");
        environment.put("CART_EXPECTED_SINGLE_PRODUCT_COUNT", "7");
        environment.put("cart.expected.single-product.count", "7");

        assertEquals(1, resolver.getPositiveInt("cart.expected.single-product.count"));
    }

    @Test
    void expectedErrorSuffixIgnoresEnvironment() {
        file.setProperty("test.login.cases.locked-user.expected-error", "archivo");
        environment.put("TEST_LOGIN_CASES_LOCKED_USER_EXPECTED_ERROR", "entorno");

        assertEquals("archivo", resolver.getRequired("test.login.cases.locked-user.expected-error"));
    }

    @Test
    void expectedKeyOnlyInEnvironmentIsAbsent() {
        environment.put("INVENTORY_EXPECTED_TITLE", "entorno");

        assertEquals("", resolver.getOptional("inventory.expected.title"));
        IllegalStateException exception = assertThrows(IllegalStateException.class,
                () -> resolver.getRequired("inventory.expected.title"));
        assertEquals("La configuración obligatoria 'inventory.expected.title' no tiene valor",
                exception.getMessage());
    }

    @Test
    void expectedAsFirstSegmentIgnoresEnvironment() {
        file.setProperty("expected.x", "archivo");
        environment.put("EXPECTED_X", "entorno");

        assertEquals("archivo", resolver.getRequired("expected.x"));
    }

    @Test
    void expectedSegmentIsCaseInsensitive() {
        file.setProperty("a.Expected.b", "archivo");
        environment.put("a.Expected.b", "entorno");

        assertEquals("archivo", resolver.getRequired("a.Expected.b"));
    }

    @Test
    void segmentStartingWithExpectedIsTreatedAsExpected() {
        file.setProperty("a.expectedValue", "archivo");
        environment.put("A_EXPECTEDVALUE", "entorno");

        assertEquals("archivo", resolver.getRequired("a.expectedValue"));
    }

    @Test
    void blankSystemValueWinsForExpectedKey() {
        file.setProperty("cart.expected.count", "2");
        system.put("cart.expected.count", " ");

        assertEquals(" ", resolver.getOptional("cart.expected.count"));
    }

    @Test
    void remoteUrlIgnoresEnvironment() {
        file.setProperty("remote.url", "");
        environment.put("REMOTE_URL", "http://localhost:9");
        environment.put("remote.url", "http://localhost:9");

        assertEquals("", resolver.getOptional("remote.url"));
    }

    @Test
    void baseUrlIgnoresEnvironment() {
        file.setProperty("base.url", "https://www.saucedemo.com");
        environment.put("BASE_URL", "http://otro-host.invalid");
        environment.put("base.url", "http://otro-host.invalid");

        assertEquals("https://www.saucedemo.com", resolver.getRequired("base.url"));
    }

    @Test
    void networkDestinationOnlyInEnvironmentIsAbsent() {
        environment.put("BASE_URL", "http://otro-host.invalid");

        assertEquals("", resolver.getOptional("base.url"));
    }

    @Test
    void systemWinsForNetworkDestinations() {
        file.setProperty("remote.url", "");
        environment.put("REMOTE_URL", "http://localhost:9");
        system.put("remote.url", "http://localhost:4444");

        assertEquals("http://localhost:4444", resolver.getOptional("remote.url"));

        system.put("remote.url", "");

        assertEquals("", resolver.getOptional("remote.url"));
    }

    @Test
    void networkDestinationPatternIsCaseInsensitiveAndAcceptsDashedSuffix() {
        file.setProperty("a.Base.URL", "archivo");
        environment.put("a.Base.URL", "entorno");
        file.setProperty("grid-url", "archivo");
        environment.put("GRID_URL", "entorno");

        assertEquals("archivo", resolver.getRequired("a.Base.URL"));
        assertEquals("archivo", resolver.getRequired("grid-url"));
    }

    @Test
    void keysThatLookSimilarButAreNeitherExpectedNorDestinationKeepEnvironment() {
        file.setProperty("a.unexpected.b", "archivo");
        environment.put("A_UNEXPECTED_B", "entorno");
        file.setProperty("a.url.b", "archivo");
        environment.put("A_URL_B", "entorno");
        file.setProperty("a.curl", "archivo");
        environment.put("A_CURL", "entorno");

        assertEquals("entorno", resolver.getRequired("a.unexpected.b"));
        assertEquals("entorno", resolver.getRequired("a.url.b"));
        assertEquals("entorno", resolver.getRequired("a.curl"));
    }

    @Test
    void headlessKeepsTheEnvironment() {
        file.setProperty("headless", "false");
        environment.put("HEADLESS", "true");

        assertTrue(resolver.getBoolean("headless"));
    }

    @Test
    void overridesExpectedValueIsTrueForAnExpectedKeyDefinedInTheSystem() {
        system.put("cart.expected.count", "9");
        system.put("test.login.cases.locked-user.expected-error", "x");

        assertTrue(resolver.overridesExpectedValue("cart.expected.count"));
        assertTrue(resolver.overridesExpectedValue("test.login.cases.locked-user.expected-error"));
    }

    @Test
    void overridesExpectedValueIsTrueEvenWhenTheSystemValueIsEmptyOrBlank() {
        system.put("cart.expected.count", "");
        system.put("cart.expected.other", " ");

        assertTrue(resolver.overridesExpectedValue("cart.expected.count"));
        assertTrue(resolver.overridesExpectedValue("cart.expected.other"));
    }

    @Test
    void overridesExpectedValueIsFalseWhenOnlyTheEnvironmentOrTheFileDefineTheKey() {
        environment.put("CART_EXPECTED_COUNT", "9");
        file.setProperty("cart.expected.count", "2");
        file.setProperty("cart.expected.only-file", "2");

        assertFalse(resolver.overridesExpectedValue("cart.expected.count"));
        assertFalse(resolver.overridesExpectedValue("cart.expected.only-file"));
        assertFalse(resolver.overridesExpectedValue("cart.expected.undefined"));
    }

    @Test
    void overridesExpectedValueIsFalseForNetworkDestinationsAndOtherKeys() {
        system.put("remote.url", "http://localhost:4444");
        system.put("base.url", "http://localhost:3000");
        system.put("headless", "true");

        assertFalse(resolver.overridesExpectedValue("remote.url"));
        assertFalse(resolver.overridesExpectedValue("base.url"));
        assertFalse(resolver.overridesExpectedValue("headless"));
    }

    @Test
    void overridesExpectedValueRejectsNullKey() {
        NullPointerException exception = assertThrows(NullPointerException.class,
                () -> resolver.overridesExpectedValue(null));

        assertEquals("La clave de configuración no puede ser null", exception.getMessage());
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

    @Test
    void getRequiredTreatsAUnicodeSpaceAsBlank() {
        file.setProperty("unicode", "\u2003");

        IllegalStateException exception = assertThrows(IllegalStateException.class,
                () -> resolver.getRequired("unicode"));

        assertEquals("La configuración obligatoria 'unicode' no tiene valor", exception.getMessage());
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

    @Test
    void getPositiveIntRejectsZeroNamingKeyAndValue() {
        file.setProperty("n", "0");

        IllegalArgumentException exception = assertThrows(IllegalArgumentException.class,
                () -> resolver.getPositiveInt("n"));

        assertEquals("La configuración 'n' debe ser mayor que cero, pero fue '0'", exception.getMessage());
    }

    // --- getNonNegativeInt ---

    @Test
    void getNonNegativeIntAcceptsZeroOneAndPaddedSix() {
        file.setProperty("cero", "0");
        file.setProperty("uno", "1");
        file.setProperty("seis", " 6 ");

        assertEquals(0, resolver.getNonNegativeInt("cero"));
        assertEquals(1, resolver.getNonNegativeInt("uno"));
        assertEquals(6, resolver.getNonNegativeInt("seis"));
    }

    @Test
    void getNonNegativeIntRejectsMinusOneNamingKeyAndValue() {
        file.setProperty("n", "-1");

        IllegalArgumentException exception = assertThrows(IllegalArgumentException.class,
                () -> resolver.getNonNegativeInt("n"));

        assertEquals("La configuración 'n' debe ser mayor o igual que cero, pero fue '-1'",
                exception.getMessage());
        assertNull(exception.getCause());
    }

    @Test
    void getNonNegativeIntRejectsTextKeepingNumberFormatExceptionAsCause() {
        file.setProperty("n", "abc");

        IllegalArgumentException exception = assertThrows(IllegalArgumentException.class,
                () -> resolver.getNonNegativeInt("n"));

        assertEquals("La configuración 'n' debe ser un entero, pero fue 'abc'", exception.getMessage());
        assertInstanceOf(NumberFormatException.class, exception.getCause());
    }

    @Test
    void getNonNegativeIntRejectsMissingAndBlankValues() {
        file.setProperty("vacio", "   ");

        IllegalStateException missing = assertThrows(IllegalStateException.class,
                () -> resolver.getNonNegativeInt("ausente"));
        IllegalStateException blank = assertThrows(IllegalStateException.class,
                () -> resolver.getNonNegativeInt("vacio"));

        assertEquals("La configuración obligatoria 'ausente' no tiene valor", missing.getMessage());
        assertEquals("La configuración obligatoria 'vacio' no tiene valor", blank.getMessage());
    }

    @Test
    void getNonNegativeIntAcceptsMaximumIntAndRejectsOverflow() {
        file.setProperty("max", "2147483647");
        file.setProperty("over", "2147483648");

        assertEquals(Integer.MAX_VALUE, resolver.getNonNegativeInt("max"));
        assertInstanceOf(NumberFormatException.class,
                assertThrows(IllegalArgumentException.class, () -> resolver.getNonNegativeInt("over")).getCause());
    }

    @Test
    void getNonNegativeIntFollowsTheSamePrecedenceAsOtherGetters() {
        file.setProperty("n", "3");
        system.put("n", "0");

        assertEquals(0, resolver.getNonNegativeInt("n"));
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
    void getListTreatsAUnicodeSpaceElementAsEmpty() {
        file.setProperty("l", "a,\u2003,b");

        IllegalArgumentException exception = assertThrows(IllegalArgumentException.class,
                () -> resolver.getList("l"));

        assertEquals("La configuración 'l' contiene un elemento vacío", exception.getMessage());
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
