package com.demo.pages;

import java.util.List;
import java.util.Objects;

import org.openqa.selenium.By;

import com.demo.transport.Navegador;
import com.demo.utils.ConfigReader;

public final class CartPage {

    private static final String XPATH_BOTON_QUITAR =
            "//div[@data-test='cart-list']//div[@data-test='inventory-item']"
                    + "[.//div[@data-test='inventory-item-name' and normalize-space()=%s]]//button";

    private static final By TITULO = By.cssSelector("[data-test='title']");
    private static final By BOTON_CHECKOUT = By.id("checkout");
    private static final By LISTA_CARRITO = By.cssSelector("[data-test='cart-list']");
    private static final By NOMBRES_PRODUCTOS =
            By.cssSelector("[data-test='cart-list'] [data-test='inventory-item-name']");

    private final Navegador navegador;

    public CartPage(Navegador navegador) {
        this.navegador = Objects.requireNonNull(navegador, "El navegador no puede ser null");
    }

    /** Pulsa el botón de tramitar y exige que la compra avance a los datos de envío. */
    public void iniciarCheckout() {
        Navegador.ResultadoClic resultado = pulsarTramitar();
        if (resultado != Navegador.ResultadoClic.AVANZO) {
            throw new IllegalStateException("La compra no avanzó a los datos de envío tras pulsar el botón de tramitar");
        }
    }

    /**
     * Pulsa el botón de tramitar sin exigir que la compra avance: quien lo llama observa el estado con
     * {@link #permaneceEnCarrito()} y la ruta de datos de envío. Un control no disponible lanza error.
     */
    public void intentarIniciarCheckout() {
        pulsarTramitar();
    }

    /** Prueba positiva de permanencia: la URL es la del carrito y su contenedor está visible. */
    public boolean permaneceEnCarrito() {
        return navegador.urlContiene(ConfigReader.getRequired("route.cart"))
                && navegador.esVisible(LISTA_CARRITO);
    }

    public List<String> obtenerNombresProductos() {
        navegador.esperarUrlContiene(ConfigReader.getRequired("route.cart"));
        navegador.esperarVisible(LISTA_CARRITO);
        return navegador.textos(NOMBRES_PRODUCTOS);
    }

    /** Cuenta los productos del carrito; con el carrito sin productos devuelve cero sin esperar de más. */
    public int contarProductos() {
        navegador.esperarUrlContiene(ConfigReader.getRequired("route.cart"));
        navegador.esperarVisible(LISTA_CARRITO);
        return navegador.contar(NOMBRES_PRODUCTOS);
    }

    public void quitarProducto(String nombreProducto) {
        esperarCarritoListo();
        By botonQuitar = By.xpath(XPATH_BOTON_QUITAR.formatted(XPathLiteral.de(nombreProducto)));
        navegador.clickYEsperarInvisible(botonQuitar);
    }

    private Navegador.ResultadoClic pulsarTramitar() {
        esperarCarritoListo();
        return navegador.clickYObservarUrlContiene(
                BOTON_CHECKOUT,
                ConfigReader.getRequired("route.checkout.information"));
    }

    /** El carrito está listo cuando su URL, su título, su contenedor y el botón de tramitar son visibles. */
    private void esperarCarritoListo() {
        navegador.esperarUrlContiene(ConfigReader.getRequired("route.cart"));
        navegador.esperarVisible(TITULO);
        navegador.esperarVisible(LISTA_CARRITO);
        navegador.esperarVisible(BOTON_CHECKOUT);
    }
}
