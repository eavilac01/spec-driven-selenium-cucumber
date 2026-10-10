package com.demo.pages;

/**
 * Punto único de acceso a los Page Objects del escenario (se retira en el paso 2 del ADR-002).
 * PicoContainer crea una instancia por escenario y también las páginas, que comparten el
 * {@code Navegador} del escenario actual.
 */
public final class PageManager {

    private final LoginPage loginPage;
    private final InventoryPage inventoryPage;
    private final CartPage cartPage;
    private final CheckoutPage checkoutPage;

    public PageManager(
            LoginPage loginPage,
            InventoryPage inventoryPage,
            CartPage cartPage,
            CheckoutPage checkoutPage) {
        this.loginPage = loginPage;
        this.inventoryPage = inventoryPage;
        this.cartPage = cartPage;
        this.checkoutPage = checkoutPage;
    }

    public LoginPage loginPage() {
        return loginPage;
    }

    public InventoryPage inventoryPage() {
        return inventoryPage;
    }

    public CartPage cartPage() {
        return cartPage;
    }

    public CheckoutPage checkoutPage() {
        return checkoutPage;
    }
}
