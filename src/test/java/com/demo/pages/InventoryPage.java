package com.demo.pages;

import org.openqa.selenium.By;

import com.demo.transport.Navegador;
import com.demo.utils.ConfigReader;

public final class InventoryPage {

    private static final String XPATH_BOTON_AGREGAR =
            "//div[@data-test='inventory-item'][.//div[@data-test='inventory-item-name' and normalize-space()=%s]]//button";

    private static final By TITULO = By.cssSelector("[data-test='title']");
    private static final By INSIGNIA_CARRITO = By.cssSelector("[data-test='shopping-cart-badge']");
    private static final By ENLACE_CARRITO = By.cssSelector("[data-test='shopping-cart-link']");

    private final Navegador navegador;

    public InventoryPage(Navegador navegador) {
        this.navegador = navegador;
    }

    public String obtenerTitulo() {
        navegador.esperarUrlContiene(ConfigReader.getRequired("route.inventory"));
        return navegador.texto(TITULO);
    }

    public void agregarProductoAlCarrito(String nombreProducto) {
        By botonAgregar = By.xpath(XPATH_BOTON_AGREGAR.formatted(literalXPath(nombreProducto)));
        navegador.desplazarA(botonAgregar);
        navegador.clickYEsperarTexto(botonAgregar, ConfigReader.getRequired("inventory.remove-button.text"));
    }

    public int obtenerCantidadProductosEnCarrito() {
        return Integer.parseInt(navegador.texto(INSIGNIA_CARRITO));
    }

    public void abrirCarrito() {
        navegador.clickYEsperarUrlContiene(ENLACE_CARRITO, ConfigReader.getRequired("route.cart"));
    }

    private String literalXPath(String valor) {
        if (!valor.contains("'")) {
            return "'" + valor + "'";
        }
        if (!valor.contains("\"")) {
            return "\"" + valor + "\"";
        }
        return "concat('" + valor.replace("'", "', \"'\", '") + "')";
    }
}
