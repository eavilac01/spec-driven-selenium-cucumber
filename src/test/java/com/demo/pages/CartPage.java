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
        esperarCarritoListo();
        navegador.clickYEsperarUrlContiene(
                BOTON_CHECKOUT,
                ConfigReader.getRequired("route.checkout.information"));
    }

    /**
     * Intenta tramitar sin exigir que la compra avance. Quien lo llama observa el estado con
     * {@link #permaneceEnCarrito()} y la ruta de datos de envío. "No se puede tramitar" solo se acepta con prueba
     * positiva: el carrito cargó (ruta, título y contenedor) y el botón de tramitar está presente en el DOM pero
     * no estuvo visible y habilitado en todo el tiempo máximo (deshabilitado u oculto), sin clic. Si el botón no
     * existe en el DOM falla cerrado: un botón eliminado no se distingue de un localizador roto.
     */
    public void intentarIniciarCheckout() {
        esperarCarritoCargado();
        exigirBotonTramitarPresente();
        Navegador.ResultadoClic resultado = navegador.clickYObservarUrlContiene(
                BOTON_CHECKOUT,
                ConfigReader.getRequired("route.checkout.information"));
        if (resultado == Navegador.ResultadoClic.NO_DISPONIBLE) {
            exigirBotonTramitarPresente();
        }
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
        return navegador.contarEstable(NOMBRES_PRODUCTOS);
    }

    public void quitarProducto(String nombreProducto) {
        esperarCarritoListo();
        By botonQuitar = By.xpath(XPATH_BOTON_QUITAR.formatted(XPathLiteral.de(nombreProducto)));
        navegador.clickYEsperarInvisible(botonQuitar);
    }

    /** El carrito está listo cuando su URL, su título, su contenedor y el botón de tramitar son visibles. */
    private void esperarCarritoListo() {
        esperarCarritoCargado();
        navegador.esperarVisible(BOTON_CHECKOUT);
    }

    private void exigirBotonTramitarPresente() {
        if (!navegador.existeEnTiempoMaximo(BOTON_CHECKOUT)) {
            throw new IllegalStateException(
                    "El control de tramitar no existe en el carrito: ¿localizador roto o el sistema lo eliminó?");
        }
    }

    /** El carrito cargó cuando su URL, su título y su contenedor son visibles; no exige el botón de tramitar. */
    private void esperarCarritoCargado() {
        navegador.esperarUrlContiene(ConfigReader.getRequired("route.cart"));
        navegador.esperarVisible(TITULO);
        navegador.esperarVisible(LISTA_CARRITO);
    }
}
