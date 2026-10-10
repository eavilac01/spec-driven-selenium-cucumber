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
        CasoLogin casoLogin = obtenerCasoLogin(caso);
        login.iniciarSesion(casoLogin.credentials());
    }

    @Then("accede al inventario")
    public void validarAccesoInventario() {
        assertEquals(
                ConfigReader.getRequired("inventory.expected.title"),
                login.obtenerTituloCatalogo(),
                "El usuario autenticado debería acceder al inventario");
    }

    @Then("el acceso es rechazado con el mensaje configurado para {word}")
    public void validarAccesoRechazado(String caso) {
        assertTrue(
                login.seMuestraRechazo(),
                "El rechazo de autenticación debería mostrar un mensaje de error");
        assertEquals(
                obtenerCasoLogin(caso).mensajeErrorEsperado(),
                login.obtenerMensajeRechazo(),
                "El rechazo de autenticación debería informar el motivo exacto");
    }

    private CasoLogin obtenerCasoLogin(String caso) {
        return switch (caso) {
            case "locked-user" -> new CasoLogin(
                    CredentialsProvider.lockedUser(),
                    ConfigReader.getRequired("test.login.cases.locked-user.expected-error"));
            case "invalid-password" -> new CasoLogin(
                    CredentialsProvider.invalidPassword(),
                    ConfigReader.getRequired("test.login.cases.invalid-password.expected-error"));
            default -> throw new IllegalArgumentException("Caso de login no configurado: " + caso);
        };
    }

    private record CasoLogin(Credentials credentials, String mensajeErrorEsperado) {
    }
}
