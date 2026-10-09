package com.demo.utils;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.Objects;
import java.util.Properties;

public final class ConfigReader {

    private static final String CONFIG_RESOURCE = "config.properties";
    private static final Properties PROPERTIES = loadProperties();

    private ConfigReader() {
    }

    public static String getRequired(String key) {
        String value = resolve(key);
        if (value == null || value.isBlank()) {
            throw new IllegalStateException(
                    "La configuración obligatoria '%s' no tiene valor".formatted(key));
        }
        return value;
    }

    public static String getOptional(String key) {
        String value = resolve(key);
        return value == null ? "" : value;
    }

    public static boolean getBoolean(String key) {
        String value = getRequired(key).trim();
        if (!"true".equalsIgnoreCase(value) && !"false".equalsIgnoreCase(value)) {
            throw new IllegalArgumentException(
                    "La configuración '%s' debe ser true o false, pero fue '%s'".formatted(key, value));
        }
        return Boolean.parseBoolean(value);
    }

    public static int getPositiveInt(String key) {
        String value = getRequired(key).trim();
        try {
            int parsedValue = Integer.parseInt(value);
            if (parsedValue <= 0) {
                throw new IllegalArgumentException(
                        "La configuración '%s' debe ser mayor que cero, pero fue '%s'".formatted(key, value));
            }
            return parsedValue;
        } catch (NumberFormatException exception) {
            throw new IllegalArgumentException(
                    "La configuración '%s' debe ser un entero, pero fue '%s'".formatted(key, value), exception);
        }
    }

    public static List<String> getList(String key) {
        List<String> values = Arrays.stream(getRequired(key).split(",", -1))
                .map(String::trim)
                .toList();
        if (values.stream().anyMatch(String::isBlank)) {
            throw new IllegalArgumentException(
                    "La configuración '%s' contiene un elemento vacío".formatted(key));
        }
        return values;
    }

    private static String resolve(String key) {
        Objects.requireNonNull(key, "La clave de configuración no puede ser null");

        String systemValue = System.getProperty(key);
        if (systemValue != null) {
            return systemValue;
        }

        String environmentValue = getEnvironmentValue(key);
        if (environmentValue != null) {
            return environmentValue;
        }

        return PROPERTIES.getProperty(key);
    }

    private static String getEnvironmentValue(String key) {
        String exactValue = System.getenv(key);
        if (exactValue != null) {
            return exactValue;
        }

        String normalizedKey = normalizeEnvironmentKey(key);
        return System.getenv(normalizedKey);
    }

    private static String normalizeEnvironmentKey(String key) {
        return key.replace('.', '_')
                .replace('-', '_')
                .toUpperCase(Locale.ROOT);
    }

    private static Properties loadProperties() {
        Properties properties = new Properties();
        try (InputStream inputStream = ConfigReader.class.getClassLoader()
                .getResourceAsStream(CONFIG_RESOURCE)) {
            if (inputStream == null) {
                throw new IllegalStateException(
                        "No se encontró '%s' en el classpath".formatted(CONFIG_RESOURCE));
            }
            properties.load(new InputStreamReader(inputStream, StandardCharsets.UTF_8));
            return properties;
        } catch (IOException exception) {
            throw new IllegalStateException(
                    "No se pudo cargar '%s'".formatted(CONFIG_RESOURCE), exception);
        }
    }
}
