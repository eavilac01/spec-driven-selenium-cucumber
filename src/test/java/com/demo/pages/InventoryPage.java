package com.demo.pages;

import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;

import com.demo.utils.ConfigReader;

public final class InventoryPage extends BasePage {

    private static final String XPATH_BOTON_AGREGAR =
            "//div[@data-test='inventory-item'][.//div[@data-test='inventory-item-name' and normalize-space()=%s]]//button";

    private static final By TITULO = By.cssSelector("[data-test='title']");
    private static final By INSIGNIA_CARRITO = By.cssSelector("[data-test='shopping-cart-badge']");
    private static final By ENLACE_CARRITO = By.cssSelector("[data-test='shopping-cart-link']");

    public InventoryPage(WebDriver driver) {
        super(driver);
    }

    public String obtenerTitulo() {
        esperarUrlContiene(ConfigReader.getRequired("route.inventory"));
        return obtenerTexto(TITULO);
    }

    public void agregarProductoAlCarrito(String nombreProducto) {
        By botonAgregar = By.xpath(XPATH_BOTON_AGREGAR.formatted(literalXPath(nombreProducto)));
        scrollA(botonAgregar);
        clickYEsperarTexto(botonAgregar, ConfigReader.getRequired("inventory.remove-button.text"));
    }

    public int obtenerCantidadProductosEnCarrito() {
        return Integer.parseInt(obtenerTexto(INSIGNIA_CARRITO));
    }

    public void abrirCarrito() {
        clickYEsperarUrlContiene(ENLACE_CARRITO, ConfigReader.getRequired("route.cart"));
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
