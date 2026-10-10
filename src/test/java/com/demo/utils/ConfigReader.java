package com.demo.utils;

import com.demo.config.ConfigResolver;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Properties;

public final class ConfigReader {

    private static final String CONFIG_RESOURCE = "config.properties";
    private static final Properties PROPERTIES = loadProperties();
    private static final ConfigResolver RESOLVER =
            new ConfigResolver(System::getProperty, System::getenv, PROPERTIES);

    private ConfigReader() {
    }

    public static String getRequired(String key) {
        return RESOLVER.getRequired(key);
    }

    public static String getOptional(String key) {
        return RESOLVER.getOptional(key);
    }

    public static boolean getBoolean(String key) {
        return RESOLVER.getBoolean(key);
    }

    public static int getPositiveInt(String key) {
        return RESOLVER.getPositiveInt(key);
    }

    public static int getNonNegativeInt(String key) {
        return RESOLVER.getNonNegativeInt(key);
    }

    public static List<String> getList(String key) {
        return RESOLVER.getList(key);
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
