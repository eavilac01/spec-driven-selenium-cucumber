package com.demo.pages;

import java.util.List;

import org.openqa.selenium.By;

import com.demo.transport.Navegador;
import com.demo.utils.ConfigReader;

public final class CartPage {

    private static final By TITULO = By.cssSelector("[data-test='title']");
    private static final By BOTON_CHECKOUT = By.id("checkout");
    private static final By LISTA_CARRITO = By.cssSelector("[data-test='cart-list']");
    private static final By NOMBRES_PRODUCTOS =
            By.cssSelector("[data-test='cart-list'] [data-test='inventory-item-name']");

    private final Navegador navegador;

    public CartPage(Navegador navegador) {
        this.navegador = navegador;
    }

    public void iniciarCheckout() {
        navegador.esperarUrlContiene(ConfigReader.getRequired("route.cart"));
        navegador.esperarVisible(TITULO);
        navegador.clickYEsperarUrlContiene(
                BOTON_CHECKOUT,
                ConfigReader.getRequired("route.checkout.information"));
    }

    public List<String> obtenerNombresProductos() {
        navegador.esperarUrlContiene(ConfigReader.getRequired("route.cart"));
        navegador.esperarVisible(LISTA_CARRITO);
        return navegador.textos(NOMBRES_PRODUCTOS);
    }
}
