package com.demo.pages;

import java.util.Objects;

import org.openqa.selenium.By;

import com.demo.transport.Navegador;

public final class MenuPage {

    private static final By BOTON_MENU = By.id("react-burger-menu-btn");
    private static final By ENLACE_CERRAR_SESION = By.id("logout_sidebar_link");

    private final Navegador navegador;

    public MenuPage(Navegador navegador) {
        this.navegador = Objects.requireNonNull(navegador, "El navegador no puede ser null");
    }

    /** Abre el menú lateral y cierra la sesión; espera a que el enlace de cierre deje de estar visible. */
    public void cerrarSesion() {
        navegador.clickYEsperarVisible(BOTON_MENU, ENLACE_CERRAR_SESION);
        navegador.clickYEsperarInvisible(ENLACE_CERRAR_SESION);
    }
}
