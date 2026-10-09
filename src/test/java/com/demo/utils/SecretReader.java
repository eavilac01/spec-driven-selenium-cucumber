package com.demo.utils;

import com.demo.config.DotEnvParser;
import com.demo.config.SecretResolver;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;

public final class SecretReader {

    private static final Path DOTENV_PATH = Path.of(".env");
    private static final SecretResolver RESOLVER =
            new SecretResolver(System::getenv, loadDotEnv());

    private SecretReader() {
    }

    public static String getRequired(String environmentVariable) {
        return RESOLVER.getRequired(environmentVariable);
    }

    private static Map<String, String> loadDotEnv() {
        if (!Files.isRegularFile(DOTENV_PATH)) {
            return Map.of();
        }

        try {
            List<String> lines = Files.readAllLines(DOTENV_PATH, StandardCharsets.UTF_8);
            return DotEnvParser.parse(lines);
        } catch (IOException exception) {
            throw new IllegalStateException("No se pudo cargar el archivo .env local", exception);
        }
    }
}
