package com.demo.hooks;

import com.demo.transport.Navegador;
import com.demo.utils.ConfigReader;

import io.cucumber.java.After;
import io.cucumber.java.AfterStep;
import io.cucumber.java.Before;
import io.cucumber.java.Scenario;

@SuppressWarnings("unused") // Cucumber invoca esta clase y sus hooks mediante reflexión.
public final class Hooks {

    private final Navegador navegador;

    public Hooks(Navegador navegador) {
        this.navegador = navegador;
    }

    @Before
    public void iniciarNavegador() {
        navegador.iniciar();
    }

    @AfterStep
    public void adjuntarEvidenciaSiFalla(Scenario scenario) {
        if (scenario.isFailed()) {
            byte[] captura = navegador.capturarPantalla();
            scenario.attach(
                    captura,
                    ConfigReader.getRequired("evidence.screenshot.media-type"),
                    ConfigReader.getRequired("evidence.screenshot.name-prefix") + " - " + scenario.getName());
        }
    }

    @After
    public void cerrarNavegador() {
        navegador.cerrar();
    }
}
