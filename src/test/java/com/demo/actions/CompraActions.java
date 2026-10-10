package com.demo.actions;

import java.util.List;
import java.util.Objects;
import com.demo.pages.CartPage;
import com.demo.pages.CheckoutPage;
import com.demo.pages.InventoryPage;

/**
 * Acciones de negocio de la compra (ADR-002, D3). Reciben los datos por parámetro,
 * devuelven valores observados y no contienen aserciones ni leen configuración de esperados.
 * PicoContainer las crea por escenario junto con las páginas.
 */
public final class CompraActions {

    private final InventoryPage inventoryPage;
    private final CartPage cartPage;
    private final CheckoutPage checkoutPage;

    public CompraActions(InventoryPage inventoryPage, CartPage cartPage, CheckoutPage checkoutPage) {
        this.inventoryPage = Objects.requireNonNull(inventoryPage, "La página del inventario no puede ser null");
        this.cartPage = Objects.requireNonNull(cartPage, "La página del carrito no puede ser null");
        this.checkoutPage = Objects.requireNonNull(checkoutPage, "La página de compra no puede ser null");
    }

    public void agregarProducto(String producto) {
        inventoryPage.agregarProductoAlCarrito(producto);
    }

    public void agregarProductos(List<String> productos) {
        productos.forEach(inventoryPage::agregarProductoAlCarrito);
    }

    public int obtenerCantidadEnCarrito() {
        return inventoryPage.obtenerCantidadProductosEnCarrito();
    }

    public List<String> revisarCarrito() {
        inventoryPage.abrirCarrito();
        return cartPage.obtenerNombresProductos();
    }

    public void tramitarCompra(String nombre, String apellido, String codigoPostal) {
        cartPage.iniciarCheckout();
        checkoutPage.completarInformacionEnvio(nombre, apellido, codigoPostal);
        checkoutPage.finalizarCompra();
    }

    public String obtenerMensajeConfirmacion() {
        return checkoutPage.obtenerMensajeConfirmacion();
    }
}
