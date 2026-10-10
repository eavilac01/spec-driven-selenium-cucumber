package com.demo.pages;

/**
 * Convierte un texto en un literal XPath seguro para componer selectores de las páginas.
 * El texto solo se inserta como literal entre comillas: nunca se evalúa (PI-05).
 */
final class XPathLiteral {

    private XPathLiteral() {
    }

    static String de(String valor) {
        if (!valor.contains("'")) {
            return "'" + valor + "'";
        }
        if (!valor.contains("\"")) {
            return "\"" + valor + "\"";
        }
        return "concat('" + valor.replace("'", "', \"'\", '") + "')";
    }
}
