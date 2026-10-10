package com.demo.actions;

import java.util.Objects;
import com.demo.data.Credentials;
import com.demo.pages.InventoryPage;
import com.demo.pages.LoginPage;
import com.demo.pages.MenuPage;

/**
 * Acciones de negocio del inicio de sesión (ADR-002, D3). Reciben los datos por parámetro,
 * devuelven valores observados y no contienen aserciones ni leen configuración de esperados.
 * PicoContainer las crea por escenario junto con las páginas.
 */
public final class LoginActions {

    private final LoginPage loginPage;
    private final InventoryPage inventoryPage;
    private final MenuPage menuPage;

    public LoginActions(LoginPage loginPage, InventoryPage inventoryPage, MenuPage menuPage) {
        this.loginPage = Objects.requireNonNull(loginPage, "La página de inicio de sesión no puede ser null");
        this.inventoryPage = Objects.requireNonNull(inventoryPage, "La página del inventario no puede ser null");
        this.menuPage = Objects.requireNonNull(menuPage, "La página del menú no puede ser null");
    }

    public void abrirInicioSesion() {
        loginPage.abrir();
    }

    public void iniciarSesion(Credentials credentials) {
        Objects.requireNonNull(credentials, "Las credenciales no pueden ser null");
        loginPage.iniciarSesion(credentials.username(), credentials.password());
    }

    public void solicitarCatalogoDirectamente() {
        inventoryPage.solicitarDirectamente();
    }

    public void cerrarSesion() {
        menuPage.cerrarSesion();
    }

    public boolean seMuestraInicioSesion() {
        return loginPage.seMuestraInicioSesion();
    }

    public String obtenerTituloCatalogo() {
        return inventoryPage.obtenerTitulo();
    }

    public boolean seMuestraRechazo() {
        return loginPage.seMuestraMensajeError();
    }

    public String obtenerMensajeRechazo() {
        return loginPage.obtenerMensajeError();
    }
}
