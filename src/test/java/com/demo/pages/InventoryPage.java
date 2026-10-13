package com.demo.pages;

import java.util.List;
import java.util.Objects;

import org.openqa.selenium.By;

import com.demo.transport.Navegador;
import com.demo.utils.ConfigReader;

public final class InventoryPage {

    private static final String XPATH_BOTON_AGREGAR =
            "//div[@data-test='inventory-item'][.//div[@data-test='inventory-item-name' and normalize-space()=%s]]//button";

    private static final By TITULO = By.cssSelector("[data-test='title']");
    private static final By INSIGNIA_CARRITO = By.cssSelector("[data-test='shopping-cart-badge']");
    private static final By ENLACE_CARRITO = By.cssSelector("[data-test='shopping-cart-link']");
    private static final By NOMBRES_CATALOGO = By.cssSelector("[data-test='inventory-item-name']");
    private static final By BOTONES_AGREGAR = By.cssSelector("button[data-test^='add-to-cart']");
    private static final By BOTONES_QUITAR = By.cssSelector("button[data-test^='remove']");

    private final Navegador navegador;

    public InventoryPage(Navegador navegador) {
        this.navegador = Objects.requireNonNull(navegador, "El navegador no puede ser null");
    }

    public String obtenerTitulo() {
        navegador.esperarUrlContiene(ConfigReader.getRequired("route.inventory"));
        return navegador.texto(TITULO);
    }

    /** Solicita la ruta del catálogo por URL, sin pasar por la interfaz; no espera a que cargue su contenido. */
    public void solicitarDirectamente() {
        String base = ConfigReader.getRequired("base.url");
        String baseSinBarraFinal = base.endsWith("/") ? base.substring(0, base.length() - 1) : base;
        navegador.abrir(baseSinBarraFinal + "/" + ConfigReader.getRequired("route.inventory"));
    }

    public List<String> obtenerNombresCatalogo() {
        navegador.esperarUrlContiene(ConfigReader.getRequired("route.inventory"));
        return navegador.textos(NOMBRES_CATALOGO);
    }

    /**
     * Cuenta los productos que aún se pueden agregar. Falla cerrado: cada producto del catálogo tiene un botón de
     * agregar o uno de quitar, así que si ambas cuentas no suman los productos visibles, algún selector dejó de
     * coincidir y el cero no prueba nada.
     */
    public int contarProductosPorAgregar() {
        navegador.esperarUrlContiene(ConfigReader.getRequired("route.inventory"));
        navegador.esperarVisible(NOMBRES_CATALOGO);
        int productos = navegador.contarEstable(NOMBRES_CATALOGO);
        int porAgregar = navegador.contarEstable(BOTONES_AGREGAR);
        int enElCarrito = navegador.contarEstable(BOTONES_QUITAR);
        if (porAgregar + enElCarrito != productos) {
            throw new IllegalStateException(
                    ("Los botones de agregar (%d) y de quitar (%d) no suman los productos del catálogo (%d): "
                            + "algún selector dejó de coincidir").formatted(porAgregar, enElCarrito, productos));
        }
        return porAgregar;
    }

    public void agregarProductoAlCarrito(String nombreProducto) {
        By botonAgregar = By.xpath(XPATH_BOTON_AGREGAR.formatted(XPathLiteral.de(nombreProducto)));
        navegador.desplazarA(botonAgregar);
        navegador.clickYEsperarTexto(botonAgregar, ConfigReader.getRequired("inventory.remove-button.text"));
    }

    public int obtenerCantidadProductosEnCarrito() {
        return Integer.parseInt(navegador.texto(INSIGNIA_CARRITO));
    }

    /** Indica si la insignia del carrito está visible, una vez que el encabezado de la página está listo. */
    public boolean seMuestraContadorCarrito() {
        navegador.esperarVisible(ENLACE_CARRITO);
        return navegador.esVisibleEstable(INSIGNIA_CARRITO);
    }

    public void abrirCarrito() {
        navegador.clickYEsperarUrlContiene(ENLACE_CARRITO, ConfigReader.getRequired("route.cart"));
    }
}
