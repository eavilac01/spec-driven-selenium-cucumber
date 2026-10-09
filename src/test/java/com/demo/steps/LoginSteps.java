package com.demo.steps;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import com.demo.pages.PageManager;
import com.demo.utils.ConfigReader;
import com.demo.utils.CredentialsProvider;
import com.demo.utils.CredentialsProvider.Credentials;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;

@SuppressWarnings("unused") // Cucumber resuelve los métodos anotados desde los textos Gherkin.
public final class LoginSteps {

    private final PageManager pages;

    public LoginSteps(PageManager pages) {
        this.pages = pages;
    }

    @Given("que el usuario abre la página de inicio de sesión")
    public void abrirPaginaInicioSesion() {
        pages.loginPage().abrir();
    }

    @When("inicia sesión con las credenciales estándar configuradas")
    public void iniciarSesionConCredencialesConfiguradas() {
        Credentials credentials = CredentialsProvider.standardUser();
        pages.loginPage().iniciarSesion(credentials.username(), credentials.password());
    }

    @When("intenta iniciar sesión con el caso configurado {word}")
    public void intentarIniciarSesion(String caso) {
        CasoLogin casoLogin = obtenerCasoLogin(caso);
        pages.loginPage().iniciarSesion(
                casoLogin.credentials().username(),
                casoLogin.credentials().password());
    }

    @Then("accede al inventario")
    public void validarAccesoInventario() {
        assertEquals(
                ConfigReader.getRequired("inventory.expected.title"),
                pages.inventoryPage().obtenerTitulo(),
                "El usuario autenticado debería acceder al inventario");
    }

    @Then("el acceso es rechazado con el mensaje configurado para {word}")
    public void validarAccesoRechazado(String caso) {
        assertTrue(
                pages.loginPage().seMuestraMensajeError(),
                "El rechazo de autenticación debería mostrar un mensaje de error");
        assertEquals(
                obtenerCasoLogin(caso).mensajeErrorEsperado(),
                pages.loginPage().obtenerMensajeError(),
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
