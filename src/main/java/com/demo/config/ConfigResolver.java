package com.demo.config;

import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.Objects;
import java.util.Properties;
import java.util.function.UnaryOperator;
import java.util.regex.Pattern;

/**
 * Lógica pura de resolución y validación de configuración (ADR-001, D2).
 *
 * <p>No lee el sistema ni archivos: recibe sus tres fuentes ya construidas. Precedencia:
 * propiedades del sistema, entorno con la clave exacta, entorno con la clave normalizada
 * (por ejemplo {@code a.b-c} pasa a {@code A_B_C}) y, por último, el archivo. Un valor en
 * blanco en una fuente prioritaria gana: no se consulta la siguiente.</p>
 *
 * <p>Excepción (ADR-003): los valores esperados (algún segmento empieza por {@code expected}) y los
 * destinos de red (el último segmento es {@code url} o termina en {@code -url}) no aceptan el
 * entorno. Su precedencia es propiedad del sistema ({@code -D}) y luego el archivo; si una clave
 * así solo está en el entorno, se trata como ausente.</p>
 */
public final class ConfigResolver {

    /** Esperado (ADR-003, D1): algún segmento separado por punto empieza por "expected". */
    private static final Pattern EXPECTED_KEY = Pattern.compile("(^|\\.)expected", Pattern.CASE_INSENSITIVE);
    /** Destino de red (ADR-003, D5): el último segmento es "url" o termina en "-url". */
    private static final Pattern NETWORK_DESTINATION_KEY = Pattern.compile("(^|[.-])url$", Pattern.CASE_INSENSITIVE);

    private final UnaryOperator<String> systemLookup;
    private final UnaryOperator<String> environmentLookup;
    private final Properties fileProperties;

    public ConfigResolver(UnaryOperator<String> systemLookup,
                          UnaryOperator<String> environmentLookup,
                          Properties fileProperties) {
        this.systemLookup = Objects.requireNonNull(systemLookup, "La fuente del sistema no puede ser null");
        this.environmentLookup = Objects.requireNonNull(environmentLookup, "La fuente del entorno no puede ser null");
        this.fileProperties = Objects.requireNonNull(fileProperties, "La fuente del archivo no puede ser null");
    }

    public String getRequired(String key) {
        String value = resolve(key);
        if (value == null || value.isBlank()) {
            throw new IllegalStateException(
                    "La configuración obligatoria '%s' no tiene valor".formatted(key));
        }
        return value;
    }

    public String getOptional(String key) {
        String value = resolve(key);
        return value == null ? "" : value;
    }

    public boolean getBoolean(String key) {
        String value = getRequired(key).trim();
        if (!"true".equalsIgnoreCase(value) && !"false".equalsIgnoreCase(value)) {
            throw new IllegalArgumentException(
                    "La configuración '%s' debe ser true o false, pero fue '%s'".formatted(key, value));
        }
        return Boolean.parseBoolean(value);
    }

    public int getPositiveInt(String key) {
        return getIntAtLeast(key, 1, "mayor que cero");
    }

    public int getNonNegativeInt(String key) {
        return getIntAtLeast(key, 0, "mayor o igual que cero");
    }

    public List<String> getList(String key) {
        List<String> values = Arrays.stream(getRequired(key).split(",", -1))
                .map(String::trim)
                .toList();
        if (values.stream().anyMatch(String::isBlank)) {
            throw new IllegalArgumentException(
                    "La configuración '%s' contiene un elemento vacío".formatted(key));
        }
        return values;
    }

    private int getIntAtLeast(String key, int minimum, String requirement) {
        String value = getRequired(key).trim();
        try {
            int parsedValue = Integer.parseInt(value);
            if (parsedValue < minimum) {
                throw new IllegalArgumentException(
                        "La configuración '%s' debe ser %s, pero fue '%s'".formatted(key, requirement, value));
            }
            return parsedValue;
        } catch (NumberFormatException exception) {
            throw new IllegalArgumentException(
                    "La configuración '%s' debe ser un entero, pero fue '%s'".formatted(key, value), exception);
        }
    }

    /**
     * Indica si la propiedad del sistema ({@code -D}) define un valor esperado, aunque esté en blanco
     * (ADR-003, D3). Es falso para los destinos de red y para el resto de las claves.
     */
    public boolean overridesExpectedValue(String key) {
        Objects.requireNonNull(key, "La clave de configuración no puede ser null");
        return EXPECTED_KEY.matcher(key).find() && systemLookup.apply(key) != null;
    }

    private String resolve(String key) {
        Objects.requireNonNull(key, "La clave de configuración no puede ser null");

        String systemValue = systemLookup.apply(key);
        if (systemValue != null) {
            return systemValue;
        }

        if (!acceptsEnvironment(key)) {
            return fileProperties.getProperty(key);
        }

        String environmentValue = resolveFromEnvironment(key);
        if (environmentValue != null) {
            return environmentValue;
        }

        return fileProperties.getProperty(key);
    }

    /** Única regla que decide si el entorno es fuente de una clave (ADR-003, D2). */
    private static boolean acceptsEnvironment(String key) {
        return !(EXPECTED_KEY.matcher(key).find() || NETWORK_DESTINATION_KEY.matcher(key).find());
    }

    private String resolveFromEnvironment(String key) {
        String exactValue = environmentLookup.apply(key);
        if (exactValue != null) {
            return exactValue;
        }

        return environmentLookup.apply(normalizeEnvironmentKey(key));
    }

    private static String normalizeEnvironmentKey(String key) {
        return key.replace('.', '_')
                .replace('-', '_')
                .toUpperCase(Locale.ROOT);
    }
}
