package com.demo.config;

import java.util.Map;
import java.util.Objects;
import java.util.function.UnaryOperator;

/**
 * Lógica pura de resolución de secretos (ADR-001, D2).
 *
 * <p>No lee el sistema ni archivos: recibe el entorno como búsqueda y el contenido del
 * {@code .env} ya interpretado. El entorno gana al {@code .env}; un valor en blanco del entorno
 * no cae al {@code .env}. Un secreto ausente o en blanco lanza {@link IllegalStateException}.</p>
 *
 * <p>Seguridad (PI-09): ningún mensaje de error incluye el valor del secreto, solo su nombre.</p>
 */
public final class SecretResolver {

    private final UnaryOperator<String> environmentLookup;
    private final Map<String, String> dotEnv;

    public SecretResolver(UnaryOperator<String> environmentLookup, Map<String, String> dotEnv) {
        this.environmentLookup = Objects.requireNonNull(
                environmentLookup, "La fuente del entorno no puede ser null");
        this.dotEnv = Map.copyOf(Objects.requireNonNull(dotEnv, "La fuente del .env no puede ser null"));
    }

    public String getRequired(String environmentVariable) {
        Objects.requireNonNull(environmentVariable, "El nombre de la variable no puede ser null");
        if (!environmentVariable.matches("[A-Z_][A-Z0-9_]*")) {
            throw new IllegalArgumentException(
                    "Nombre de variable de entorno no válido: " + environmentVariable);
        }

        String value = environmentLookup.apply(environmentVariable);
        if (value == null) {
            value = dotEnv.get(environmentVariable);
        }
        if (value == null || value.isBlank()) {
            throw new IllegalStateException(
                    "La variable sensible obligatoria '%s' no tiene valor".formatted(environmentVariable));
        }
        return value;
    }
}
