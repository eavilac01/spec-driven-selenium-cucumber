package com.demo.steps;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import java.util.List;
import com.demo.actions.CompraActions;
import com.demo.actions.LoginActions;
import com.demo.utils.ConfigReader;
import com.demo.utils.CredentialsProvider;
import com.demo.utils.TestContext;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;

@SuppressWarnings("unused") // Cucumber resuelve los métodos anotados desde los textos Gherkin.
public final class CompraSteps {

    private static final String PREFIJO_ESPERADO_VARIOS = "cart.expected";
    private static final String PREFIJO_ESPERADO_UNICO = "cart.expected.single-product";
    private static final String PREFIJO_ESPERADO_CINCO = "cart.expected.five-products";
    private static final String PREFIJO_ESPERADO_TODOS = "cart.expected.all-products";
    private static final String PREFIJO_ESPERADO_TRAS_QUITAR = "cart.expected.after-removal";

    private final TestContext testContext;
    private final LoginActions login;
    private final CompraActions compra;

    public CompraSteps(TestContext testContext, LoginActions login, CompraActions compra) {
        this.testContext = testContext;
        this.login = login;
        this.compra = compra;
    }

    @Given("que el usuario está autenticado para comprar")
    public void autenticarUsuarioParaComprar() {
        login.abrirInicioSesion();
        login.iniciarSesion(CredentialsProvider.standardUser());
        assertEquals(
                ConfigReader.getRequired("inventory.expected.title"),
                login.obtenerTituloCatalogo(),
                "La compra requiere que el usuario acceda correctamente al inventario");
    }

    @When("agrega los productos configurados al carrito")
    public void agregarProductosConfiguradosAlCarrito() {
        List<String> productos = ConfigReader.getList("test.purchase.products");
        testContext.setPrefijoEsperadoCarrito(PREFIJO_ESPERADO_VARIOS);
        compra.agregarProductos(productos);
    }

    @When("agrega el producto individual configurado al carrito")
    public void agregarProductoIndividualConfiguradoAlCarrito() {
        String producto = ConfigReader.getRequired("test.purchase.single-product");
        testContext.setPrefijoEsperadoCarrito(PREFIJO_ESPERADO_UNICO);
        compra.agregarProducto(producto);
    }

    @When("agrega los cinco productos configurados al carrito")
    public void agregarCincoProductosConfiguradosAlCarrito() {
        List<String> productos = ConfigReader.getList("test.purchase.five-products");
        testContext.setPrefijoEsperadoCarrito(PREFIJO_ESPERADO_CINCO);
        compra.agregarProductos(productos);
    }

    @When("agrega todos los productos del catálogo al carrito")
    public void agregarTodosLosProductosDelCatalogoAlCarrito() {
        List<String> productos = ConfigReader.getList("test.purchase.all-products");
        testContext.setPrefijoEsperadoCarrito(PREFIJO_ESPERADO_TODOS);
        compra.agregarProductos(productos);
    }

    @When("quita del carrito el producto configurado para quitar")
    public void quitarDelCarritoElProductoConfigurado() {
        testContext.setPrefijoEsperadoCarrito(PREFIJO_ESPERADO_TRAS_QUITAR);
        compra.quitarProductoDelCarrito(ConfigReader.getRequired("test.purchase.removed-product"));
    }

    @When("quita del carrito el producto individual configurado")
    public void quitarDelCarritoElProductoIndividualConfigurado() {
        compra.quitarProductoDelCarrito(ConfigReader.getRequired("test.purchase.single-product"));
    }

    @When("intenta tramitar la compra con el carrito sin productos")
    public void intentarTramitarCompraConCarritoSinProductos() {
        compra.intentarTramitarCompraConCarritoSinProductos();
    }

    @When("tramita la compra sin informar el dato de envío {word}")
    public void tramitarCompraSinInformarDato(String dato) {
        String nombre = ConfigReader.getRequired("test.checkout.first-name");
        String apellido = ConfigReader.getRequired("test.checkout.last-name");
        String codigoPostal = ConfigReader.getRequired("test.checkout.postal-code");
        switch (dato) {
            case "first-name" -> nombre = "";
            case "last-name" -> apellido = "";
            case "postal-code" -> codigoPostal = "";
            default -> throw new IllegalArgumentException("Dato de envío no configurado: " + dato);
        }
        compra.intentarTramitarCompra(nombre, apellido, codigoPostal);
    }

    @Then("el contador del carrito no se muestra")
    public void validarContadorCarritoNoSeMuestra() {
        assertEquals(
                ConfigReader.getBoolean("cart.expected.empty.counter-displayed"),
                compra.seMuestraContadorCarrito(),
                "El contador del carrito sin productos no debería mostrarse");
    }

    @Then("el carrito no contiene productos")
    public void validarCarritoSinProductos() {
        assertEquals(
                ConfigReader.getNonNegativeInt("cart.expected.empty.count"),
                compra.contarProductosEnCarrito(),
                "El carrito no debería contener productos");
    }

    @Then("el catálogo ofrece los productos esperados")
    public void validarProductosDelCatalogo() {
        List<String> observados = compra.consultarProductosDelCatalogo();
        assertEquals(
                ConfigReader.getPositiveInt("catalog.expected.count"),
                observados.size(),
                "El catálogo debería ofrecer la cantidad de productos esperada");
        assertEquals(
                ConfigReader.getList("catalog.expected.products"),
                observados,
                "El catálogo debería ofrecer exactamente los productos esperados, en su orden");
    }

    @Then("no quedan productos del catálogo por agregar")
    public void validarNoQuedanProductosPorAgregar() {
        assertEquals(
                ConfigReader.getNonNegativeInt("catalog.expected.remaining-to-add"),
                compra.contarProductosDelCatalogoPorAgregar(),
                "No deberían quedar productos del catálogo por agregar al carrito");
    }

    @Then("la compra no avanza a los datos de envío")
    public void validarCompraNoAvanzaADatosDeEnvio() {
        assertEquals(
                ConfigReader.getBoolean("checkout.expected.empty-cart.advances"),
                compra.avanzaADatosDeEnvio(),
                "Con el carrito sin productos la compra no debería avanzar a los datos de envío");
    }

    @Then("la compra no continúa y se informa el mensaje configurado para {word}")
    public void validarCompraNoContinuaConMensaje(String dato) {
        String claveMensajeEsperado = switch (dato) {
            case "first-name" -> "checkout.expected.errors.first-name";
            case "last-name" -> "checkout.expected.errors.last-name";
            case "postal-code" -> "checkout.expected.errors.postal-code";
            default -> throw new IllegalArgumentException("Dato de envío no configurado: " + dato);
        };
        assertTrue(
                compra.seMuestraErrorDeEnvio(),
                "El dato de envío faltante debería mostrar un mensaje de error");
        assertEquals(
                ConfigReader.getRequired(claveMensajeEsperado),
                compra.obtenerMensajeErrorDeEnvio(),
                "El mensaje de error debería informar el dato de envío faltante");
        assertTrue(
                compra.estaEnDatosDeEnvio(),
                "La compra no debería continuar mientras falte un dato de envío");
    }

    @Then("el carrito refleja la cantidad de productos configurada")
    public void validarCantidadProductosEnCarrito() {
        assertEquals(
                ConfigReader.getPositiveInt(testContext.getPrefijoEsperadoCarrito() + ".count"),
                compra.obtenerCantidadEnCarrito(),
                "La insignia del carrito debería reflejar todos los productos seleccionados");
    }

    @Then("el carrito contiene los productos seleccionados")
    public void validarProductosEnCarrito() {
        assertEquals(
                ConfigReader.getList(testContext.getPrefijoEsperadoCarrito() + ".products"),
                compra.revisarCarrito(),
                "El carrito debería contener exactamente los productos seleccionados");
    }

    @When("tramita la compra con los datos de envío configurados")
    public void tramitarCompraConDatosConfigurados() {
        compra.tramitarCompra(
                ConfigReader.getRequired("test.checkout.first-name"),
                ConfigReader.getRequired("test.checkout.last-name"),
                ConfigReader.getRequired("test.checkout.postal-code"));
    }

    @Then("la compra se confirma con el mensaje configurado")
    public void validarConfirmacionCompra() {
        assertEquals(
                ConfigReader.getRequired("checkout.expected.confirmation"),
                compra.obtenerMensajeConfirmacion(),
                "La compra completada debería mostrar el mensaje de confirmación esperado");
    }
}
