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

    public boolean seMuestraContadorCarrito() {
        return inventoryPage.seMuestraContadorCarrito();
    }

    public List<String> revisarCarrito() {
        inventoryPage.abrirCarrito();
        return cartPage.obtenerNombresProductos();
    }

    public int contarProductosEnCarrito() {
        inventoryPage.abrirCarrito();
        return cartPage.contarProductos();
    }

    public void quitarProductoDelCarrito(String producto) {
        inventoryPage.abrirCarrito();
        cartPage.quitarProducto(producto);
    }

    public List<String> consultarProductosDelCatalogo() {
        inventoryPage.solicitarDirectamente();
        return inventoryPage.obtenerNombresCatalogo();
    }

    public int contarProductosDelCatalogoPorAgregar() {
        inventoryPage.solicitarDirectamente();
        return inventoryPage.contarProductosPorAgregar();
    }

    public void tramitarCompra(String nombre, String apellido, String codigoPostal) {
        inventoryPage.abrirCarrito();
        cartPage.iniciarCheckout();
        checkoutPage.completarInformacionEnvio(nombre, apellido, codigoPostal);
        checkoutPage.finalizarCompra();
    }

    /** Un dato vacío no se escribe: así el escenario omite ese dato de envío. */
    public void intentarTramitarCompra(String nombre, String apellido, String codigoPostal) {
        inventoryPage.abrirCarrito();
        cartPage.iniciarCheckout();
        checkoutPage.intentarContinuarConInformacionEnvio(nombre, apellido, codigoPostal);
    }

    public void intentarTramitarCompraConCarritoSinProductos() {
        inventoryPage.abrirCarrito();
        cartPage.intentarIniciarCheckout();
    }

    /** "No avanza" exige permanecer en el carrito de forma observable; en cualquier otro caso se considera avance. */
    public boolean avanzaADatosDeEnvio() {
        return !cartPage.permaneceEnCarrito() || checkoutPage.estaEnDatosEnvio();
    }

    public boolean estaEnDatosDeEnvio() {
        return checkoutPage.estaEnDatosEnvio();
    }

    public boolean seMuestraErrorDeEnvio() {
        return checkoutPage.seMuestraMensajeError();
    }

    public String obtenerMensajeErrorDeEnvio() {
        return checkoutPage.obtenerMensajeError();
    }

    public String obtenerMensajeConfirmacion() {
        return checkoutPage.obtenerMensajeConfirmacion();
    }
}
