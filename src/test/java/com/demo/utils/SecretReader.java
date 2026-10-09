package com.demo.utils;

import java.io.BufferedReader;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Objects;
import java.util.Properties;

public final class SecretReader {

    private static final Path DOTENV_PATH = Path.of(".env");
    private static final Properties DOTENV = loadDotEnv();

    private SecretReader() {
    }

    public static String getRequired(String environmentVariable) {
        Objects.requireNonNull(environmentVariable, "El nombre de la variable no puede ser null");
        if (!environmentVariable.matches("[A-Z_][A-Z0-9_]*")) {
            throw new IllegalArgumentException(
                    "Nombre de variable de entorno no válido: " + environmentVariable);
        }

        String value = System.getenv(environmentVariable);
        if (value == null) {
            value = DOTENV.getProperty(environmentVariable);
        }
        if (value == null || value.isBlank()) {
            throw new IllegalStateException(
                    "La variable sensible obligatoria '%s' no tiene valor".formatted(environmentVariable));
        }
        return value;
    }

    private static Properties loadDotEnv() {
        Properties dotEnv = new Properties();
        if (!Files.isRegularFile(DOTENV_PATH)) {
            return dotEnv;
        }

        try (BufferedReader reader = Files.newBufferedReader(DOTENV_PATH, StandardCharsets.UTF_8)) {
            String line;
            int lineNumber = 0;
            while ((line = reader.readLine()) != null) {
                lineNumber++;
                parseDotEnvLine(dotEnv, line, lineNumber);
            }
            return dotEnv;
        } catch (IOException exception) {
            throw new IllegalStateException("No se pudo cargar el archivo .env local", exception);
        }
    }

    private static void parseDotEnvLine(Properties dotEnv, String line, int lineNumber) {
        String normalizedLine = line.trim();
        if (normalizedLine.isEmpty() || normalizedLine.startsWith("#")) {
            return;
        }
        if (normalizedLine.startsWith("export ")) {
            normalizedLine = normalizedLine.substring("export ".length()).trim();
        }

        int separatorIndex = normalizedLine.indexOf('=');
        if (separatorIndex <= 0) {
            throw new IllegalStateException("Formato inválido en .env, línea " + lineNumber);
        }

        String key = normalizedLine.substring(0, separatorIndex).trim();
        if (!key.matches("[A-Za-z_][A-Za-z0-9_]*")) {
            throw new IllegalStateException("Nombre de variable inválido en .env, línea " + lineNumber);
        }

        String value = normalizedLine.substring(separatorIndex + 1).trim();
        dotEnv.setProperty(key, removeMatchingQuotes(value));
    }

    private static String removeMatchingQuotes(String value) {
        if (value.length() >= 2) {
            char firstCharacter = value.charAt(0);
            char lastCharacter = value.charAt(value.length() - 1);
            if ((firstCharacter == '\'' && lastCharacter == '\'')
                    || (firstCharacter == '"' && lastCharacter == '"')) {
                return value.substring(1, value.length() - 1);
            }
        }
        return value;
    }
}
