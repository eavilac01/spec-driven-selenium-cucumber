package com.demo.utils;

import com.demo.config.ConfigResolver;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Properties;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

public final class ConfigReader {

    private static final String CONFIG_RESOURCE = "config.properties";
    private static final Logger LOGGER = LoggerFactory.getLogger(ConfigReader.class);
    private static final Set<String> ESPERADOS_AVISADOS = ConcurrentHashMap.newKeySet();
    private static final Set<String> DESTINOS_REGISTRADOS = ConcurrentHashMap.newKeySet();
    private static final Properties PROPERTIES = loadProperties();
    private static final ConfigResolver RESOLVER =
            new ConfigResolver(System::getProperty, System::getenv, PROPERTIES);

    private ConfigReader() {
    }

    public static String getRequired(String key) {
        avisarSiSobrescribeEsperado(key);
        registrarDestinoDeRed(key);
        return RESOLVER.getRequired(key);
    }

    public static String getOptional(String key) {
        avisarSiSobrescribeEsperado(key);
        registrarDestinoDeRed(key);
        return RESOLVER.getOptional(key);
    }

    public static boolean getBoolean(String key) {
        avisarSiSobrescribeEsperado(key);
        registrarDestinoDeRed(key);
        return RESOLVER.getBoolean(key);
    }

    public static int getPositiveInt(String key) {
        avisarSiSobrescribeEsperado(key);
        registrarDestinoDeRed(key);
        return RESOLVER.getPositiveInt(key);
    }

    public static int getNonNegativeInt(String key) {
        avisarSiSobrescribeEsperado(key);
        registrarDestinoDeRed(key);
        return RESOLVER.getNonNegativeInt(key);
    }

    public static List<String> getList(String key) {
        avisarSiSobrescribeEsperado(key);
        registrarDestinoDeRed(key);
        return RESOLVER.getList(key);
    }

    /**
     * ADR-003, D3: un esperado que viene de una propiedad del sistema solo es válido en el control negativo.
     * Avisa una vez por clave y por JVM; nunca registra el valor, que puede venir de MAVEN_ARGS.
     */
    private static void avisarSiSobrescribeEsperado(String key) {
        if (RESOLVER.overridesExpectedValue(key) && ESPERADOS_AVISADOS.add(key)) {
            LOGGER.warn("La clave de esperado '{}' viene de una propiedad del sistema (-D): "
                    + "solo es válido en el control negativo (CHK-10)", key);
        }
    }

    /**
     * ADR-003, D6: deja en INFO, una vez por clave y por JVM, la fuente y el host de cada destino de red. La línea
     * la compone ConfigResolver y nunca lleva el valor; va como argumento, no como formato.
     */
    private static void registrarDestinoDeRed(String key) {
        RESOLVER.describeNetworkDestination(key)
                .filter(linea -> DESTINOS_REGISTRADOS.add(key))
                .ifPresent(linea -> LOGGER.info("{}", linea));
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
