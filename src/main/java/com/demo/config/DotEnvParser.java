package com.demo.config;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

/**
 * Parser puro de las líneas de un archivo {@code .env} (ADR-001, D2).
 *
 * <p>No lee archivos: recibe las líneas ya leídas. Ignora las líneas vacías y las que empiezan
 * por {@code #}, acepta el prefijo {@code export } y quita un par de comillas simples o dobles que
 * rodee todo el valor. Si una clave se repite, gana la última.</p>
 *
 * <p>Seguridad (PI-09): los mensajes de error indican solo el número de línea. Nunca incluyen el
 * contenido de la línea ni su valor.</p>
 */
public final class DotEnvParser {

    private static final String EXPORT_PREFIX = "export ";

    private DotEnvParser() {
    }

    public static Map<String, String> parse(List<String> lines) {
        Objects.requireNonNull(lines, "Las líneas del .env no pueden ser null");

        Map<String, String> values = new HashMap<>();
        int lineNumber = 0;
        for (String line : lines) {
            lineNumber++;
            parseLine(values, line, lineNumber);
        }
        return values;
    }

    private static void parseLine(Map<String, String> values, String line, int lineNumber) {
        String normalizedLine = line.trim();
        if (normalizedLine.isEmpty() || normalizedLine.startsWith("#")) {
            return;
        }
        if (normalizedLine.startsWith(EXPORT_PREFIX)) {
            normalizedLine = normalizedLine.substring(EXPORT_PREFIX.length()).trim();
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
        values.put(key, removeMatchingQuotes(value));
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
