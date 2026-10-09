package com.demo.pages;

import java.util.List;

import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;

import com.demo.utils.ConfigReader;

public final class CartPage extends BasePage {

    private static final By TITULO = By.cssSelector("[data-test='title']");
    private static final By BOTON_CHECKOUT = By.id("checkout");
    private static final By LISTA_CARRITO = By.cssSelector("[data-test='cart-list']");
    private static final By NOMBRES_PRODUCTOS =
            By.cssSelector("[data-test='cart-list'] [data-test='inventory-item-name']");

    public CartPage(WebDriver driver) {
        super(driver);
    }

    public void iniciarCheckout() {
        esperarUrlContiene(ConfigReader.getRequired("route.cart"));
        esperarVisible(TITULO);
        clickYEsperarUrlContiene(
                BOTON_CHECKOUT,
                ConfigReader.getRequired("route.checkout.information"));
    }

    public List<String> obtenerNombresProductos() {
        esperarUrlContiene(ConfigReader.getRequired("route.cart"));
        esperarVisible(LISTA_CARRITO);
        return obtenerTodos(NOMBRES_PRODUCTOS).stream()
                .map(WebElement::getText)
                .toList();
    }
}
