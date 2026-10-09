package com.demo.data;

/**
 * Par usuario/contraseña de un perfil de prueba (ADR-001, D1).
 *
 * <p>Seguridad (PI-09): {@link #toString()} enmascara ambos valores para que no aparezcan en
 * logs, reportes ni mensajes de error. Es la única defensa de esta clase: si se rompe, ningún
 * E2E falla y las credenciales se filtran.</p>
 */
public record Credentials(String username, String password) {

    @Override
    public String toString() {
        return "Credentials[username=***, password=***]";
    }
}
