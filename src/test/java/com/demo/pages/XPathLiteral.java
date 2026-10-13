package com.demo.pages;

/**
 * Convierte un texto en un literal XPath entre comillas simples para componer selectores de las páginas.
 * El texto solo se inserta como literal: nunca se evalúa (PI-05). Un valor con comilla simple se rechaza
 * (ADR-002, enmienda 2026-10-13): ningún dato ni AC lo necesita y el literal alternativo no tendría prueba.
 */
final class XPathLiteral {

    private XPathLiteral() {
    }

    static String de(String valor) {
        if (valor.contains("'")) {
            // El mensaje no repite el valor: puede venir de -D o del entorno.
            throw new IllegalArgumentException(
                    "El literal XPath no admite comillas simples (ADR-002, enmienda 2026-10-13)");
        }
        return "'" + valor + "'";
    }
}
