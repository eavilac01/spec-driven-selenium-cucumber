package com.demo.steps;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import com.demo.actions.LoginActions;
import com.demo.data.Credentials;
import com.demo.utils.ConfigReader;
import com.demo.utils.CredentialsProvider;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;

@SuppressWarnings("unused") // Cucumber resuelve los métodos anotados desde los textos Gherkin.
public final class LoginSteps {

    private final LoginActions login;

    public LoginSteps(LoginActions login) {
        this.login = login;
    }

    @Given("que el usuario abre la página de inicio de sesión")
    public void abrirPaginaInicioSesion() {
        login.abrirInicioSesion();
    }

    @When("inicia sesión con las credenciales estándar configuradas")
    public void iniciarSesionConCredencialesConfiguradas() {
        login.iniciarSesion(CredentialsProvider.standardUser());
    }

    @When("intenta iniciar sesión con el caso configurado {word}")
    public void intentarIniciarSesion(String caso) {
        login.iniciarSesion(obtenerCredencialesDelCaso(caso));
    }

    @When("solicita directamente el catálogo")
    public void solicitarCatalogoDirectamente() {
        login.solicitarCatalogoDirectamente();
    }

    @When("cierra la sesión")
    public void cerrarSesion() {
        login.cerrarSesion();
    }

    @Then("accede al inventario")
    public void validarAccesoInventario() {
        assertEquals(
                ConfigReader.getRequired("inventory.expected.title"),
                login.obtenerTituloCatalogo(),
                "El usuario autenticado debería acceder al inventario");
    }

    @Then("vuelve al inicio de sesión")
    public void validarRegresoAlInicioSesion() {
        assertTrue(
                login.seMuestraInicioSesion(),
                "El cliente debería volver al inicio de sesión");
    }

    @Then("el acceso es rechazado con el mensaje configurado para {word}")
    public void validarAccesoRechazado(String caso) {
        assertTrue(
                login.seMuestraRechazo(),
                "El rechazo de autenticación debería mostrar un mensaje de error");
        assertEquals(
                obtenerMensajeErrorEsperado(caso),
                login.obtenerMensajeRechazo(),
                "El rechazo de autenticación debería informar el motivo exacto");
    }

    private Credentials obtenerCredencialesDelCaso(String caso) {
        return switch (caso) {
            case "locked-user" -> CredentialsProvider.lockedUser();
            case "invalid-password" -> CredentialsProvider.invalidPassword();
            case "nonexistent-user" -> CredentialsProvider.nonexistentUser();
            case "empty-username" -> CredentialsProvider.emptyUsername();
            case "empty-password" -> CredentialsProvider.emptyPassword();
            case "empty-both" -> CredentialsProvider.emptyBoth();
            default -> throw new IllegalArgumentException("Caso de login sin credenciales configuradas: " + caso);
        };
    }

    private String obtenerMensajeErrorEsperado(String caso) {
        String clave = switch (caso) {
            case "locked-user" -> "test.login.cases.locked-user.expected-error";
            case "invalid-password" -> "test.login.cases.invalid-password.expected-error";
            case "nonexistent-user" -> "test.login.cases.nonexistent-user.expected-error";
            case "empty-username" -> "test.login.cases.empty-username.expected-error";
            case "empty-password" -> "test.login.cases.empty-password.expected-error";
            case "empty-both" -> "test.login.cases.empty-both.expected-error";
            case "anonymous-access" -> "test.login.cases.anonymous-access.expected-error";
            default -> throw new IllegalArgumentException("Caso de login sin mensaje configurado: " + caso);
        };
        return ConfigReader.getRequired(clave);
    }
}
