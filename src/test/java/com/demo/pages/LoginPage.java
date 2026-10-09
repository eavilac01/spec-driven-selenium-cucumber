package com.demo.pages;

import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;

import com.demo.utils.ConfigReader;

public final class LoginPage extends BasePage {

    private static final By CAMPO_USUARIO = By.id("user-name");
    private static final By CAMPO_CONTRASENA = By.id("password");
    private static final By BOTON_INICIAR_SESION = By.id("login-button");
    private static final By MENSAJE_ERROR = By.cssSelector("[data-test='error']");

    public LoginPage(WebDriver driver) {
        super(driver);
    }

    public void abrir() {
        abrirUrl(ConfigReader.getRequired("base.url"));
        esperarVisible(CAMPO_USUARIO);
    }

    public void iniciarSesion(String usuario, String contrasena) {
        escribir(CAMPO_USUARIO, usuario);
        escribir(CAMPO_CONTRASENA, contrasena);
        click(BOTON_INICIAR_SESION);
    }

    public String obtenerMensajeError() {
        return obtenerTexto(MENSAJE_ERROR);
    }

    public boolean seMuestraMensajeError() {
        return esVisible(MENSAJE_ERROR);
    }
}
