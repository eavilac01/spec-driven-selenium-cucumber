package com.demo.pages;

import org.openqa.selenium.By;

import com.demo.transport.Navegador;
import com.demo.utils.ConfigReader;

public final class LoginPage {

    private static final By CAMPO_USUARIO = By.id("user-name");
    private static final By CAMPO_CONTRASENA = By.id("password");
    private static final By BOTON_INICIAR_SESION = By.id("login-button");
    private static final By MENSAJE_ERROR = By.cssSelector("[data-test='error']");

    private final Navegador navegador;

    public LoginPage(Navegador navegador) {
        this.navegador = navegador;
    }

    public void abrir() {
        navegador.abrir(ConfigReader.getRequired("base.url"));
        navegador.esperarVisible(CAMPO_USUARIO);
    }

    public void iniciarSesion(String usuario, String contrasena) {
        navegador.escribir(CAMPO_USUARIO, usuario);
        navegador.escribir(CAMPO_CONTRASENA, contrasena);
        navegador.click(BOTON_INICIAR_SESION);
    }

    public String obtenerMensajeError() {
        return navegador.texto(MENSAJE_ERROR);
    }

    public boolean seMuestraMensajeError() {
        return navegador.esVisible(MENSAJE_ERROR);
    }
}
