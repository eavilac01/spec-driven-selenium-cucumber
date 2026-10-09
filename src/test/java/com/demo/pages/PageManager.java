package com.demo.pages;

import com.demo.utils.TestContext;

/**
 * Punto único de acceso a los Page Objects del escenario.
 * PicoContainer crea una instancia por escenario y la comparte entre todas las clases de steps,
 * de modo que cada página se instancia una sola vez y siempre con el WebDriver del escenario actual.
 */
public final class PageManager {

    private final TestContext testContext;
    private LoginPage loginPage;
    private InventoryPage inventoryPage;
    private CartPage cartPage;
    private CheckoutPage checkoutPage;

    public PageManager(TestContext testContext) {
        this.testContext = testContext;
    }

    public LoginPage loginPage() {
        if (loginPage == null) {
            loginPage = new LoginPage(testContext.getDriver());
        }
        return loginPage;
    }

    public InventoryPage inventoryPage() {
        if (inventoryPage == null) {
            inventoryPage = new InventoryPage(testContext.getDriver());
        }
        return inventoryPage;
    }

    public CartPage cartPage() {
        if (cartPage == null) {
            cartPage = new CartPage(testContext.getDriver());
        }
        return cartPage;
    }

    public CheckoutPage checkoutPage() {
        if (checkoutPage == null) {
            checkoutPage = new CheckoutPage(testContext.getDriver());
        }
        return checkoutPage;
    }
}
