package com.demo.config;

import java.util.Objects;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Decisiones puras sobre las páginas de error que el propio navegador muestra cuando la
 * navegación falla (por ejemplo {@code net::ERR_CONNECTION_CLOSED} en Chrome).
 *
 * <p>Recibe cadenas ya leídas y no toca Selenium. Su contrato de seguridad (PI-05): del texto
 * de la página solo sale un código con la forma {@code net::ERR_[A-Z0-9_]+}; cualquier otra
 * cosa se descarta, de modo que el mensaje de error nunca repite contenido del navegador o
 * de la aplicación bajo prueba.</p>
 */
public final class BrowserErrorPage {

    /** Texto que se muestra cuando no se pudo extraer un código válido. */
    public static final String CODE_UNAVAILABLE = "código no disponible";

    private static final String CHROME_ERROR_URL_PREFIX = "chrome-error://";
    private static final String FIREFOX_ERROR_URL_PREFIX = "about:neterror";
    private static final String CODE_BODY = "ERR_[A-Z0-9_]+";
    private static final Pattern CODE_FROM_PAGE = Pattern.compile("(?:net::)?(" + CODE_BODY + ")");
    /** Detecta un fallo de navegación: basta el comienzo de un código, aunque el resto no sea válido. */
    private static final Pattern CODE_IN_MESSAGE = Pattern.compile("net::" + CODE_BODY);
    /** Extrae solo códigos completos: el código no puede continuar con otro carácter de palabra. */
    private static final Pattern VALID_CODE_IN_MESSAGE =
            Pattern.compile("net::" + CODE_BODY + "(?![A-Za-z0-9_])");

    private BrowserErrorPage() {
    }

    /** Indica si la URL es la de una página de error interna de Chrome o de Firefox. */
    public static boolean isErrorUrl(String url) {
        return url != null
                && (url.startsWith(CHROME_ERROR_URL_PREFIX) || url.startsWith(FIREFOX_ERROR_URL_PREFIX));
    }

    /**
     * Indica si el mensaje de una excepción del driver describe un fallo de navegación: Chrome
     * informa {@code net::ERR_…} y Firefox {@code Reached error page: about:neterror…}.
     */
    public static boolean isNavigationErrorMessage(String message) {
        return message != null
                && (CODE_IN_MESSAGE.matcher(message).find()
                || message.contains(FIREFOX_ERROR_URL_PREFIX)
                || message.contains(CHROME_ERROR_URL_PREFIX));
    }

    /**
     * Valida el texto del código leído de la página: debe ser exactamente {@code ERR_…} o
     * {@code net::ERR_…}, sin espacios ni texto adicional. Devuelve siempre la forma con prefijo.
     */
    public static Optional<String> codeFromPageText(String text) {
        if (text == null) {
            return Optional.empty();
        }
        Matcher matcher = CODE_FROM_PAGE.matcher(text.strip());
        return matcher.matches() ? Optional.of("net::" + matcher.group(1)) : Optional.empty();
    }

    /**
     * Extrae el primer {@code net::ERR_…} completo de un mensaje de excepción del driver. Un código
     * seguido de letras, dígitos o guion bajo no válidos (por ejemplo {@code net::ERR_ABCdef}) se rechaza
     * en lugar de truncarse.
     */
    public static Optional<String> codeFromDriverMessage(String message) {
        if (message == null) {
            return Optional.empty();
        }
        Matcher matcher = VALID_CODE_IN_MESSAGE.matcher(message);
        return matcher.find() ? Optional.of(matcher.group()) : Optional.empty();
    }

    /** Mensaje de la excepción: la URL solicitada y el código, o que el código no está disponible. */
    public static String describe(String requestedUrl, Optional<String> code) {
        Objects.requireNonNull(code, "El código no puede ser null");
        return "El navegador mostró una página de error de red al abrir '%s' (%s)"
                .formatted(requestedUrl, code.orElse(CODE_UNAVAILABLE));
    }
}
