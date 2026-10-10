package com.demo.pages;

import java.util.Objects;

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
        this.navegador = Objects.requireNonNull(navegador, "El navegador no puede ser null");
    }

    public void abrir() {
        navegador.abrir(ConfigReader.getRequired("base.url"));
        navegador.esperarVisible(CAMPO_USUARIO);
    }

    /** Un usuario o una contraseña vacíos no escriben nada en su campo. */
    public void iniciarSesion(String usuario, String contrasena) {
        Objects.requireNonNull(usuario, "El usuario no puede ser null");
        Objects.requireNonNull(contrasena, "La contraseña no puede ser null");
        if (!usuario.isEmpty()) {
            navegador.escribir(CAMPO_USUARIO, usuario);
        }
        if (!contrasena.isEmpty()) {
            navegador.escribir(CAMPO_CONTRASENA, contrasena);
        }
        navegador.click(BOTON_INICIAR_SESION);
    }

    /** Observa, dentro del tiempo máximo, si se muestra el inicio de sesión fuera de la ruta del catálogo. */
    public boolean seMuestraInicioSesion() {
        return navegador.apareceEnTiempoMaximo(CAMPO_USUARIO)
                && navegador.esVisible(BOTON_INICIAR_SESION)
                && !navegador.urlContiene(ConfigReader.getRequired("route.inventory"));
    }

    public String obtenerMensajeError() {
        return navegador.texto(MENSAJE_ERROR);
    }

    public boolean seMuestraMensajeError() {
        return navegador.apareceEnTiempoMaximo(MENSAJE_ERROR);
    }
}
