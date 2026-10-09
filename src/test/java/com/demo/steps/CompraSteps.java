package com.demo.steps;

import static org.junit.jupiter.api.Assertions.assertEquals;
import java.util.List;
import com.demo.data.Credentials;
import com.demo.pages.PageManager;
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

    private final TestContext testContext;
    private final PageManager pages;

    public CompraSteps(TestContext testContext, PageManager pages) {
        this.testContext = testContext;
        this.pages = pages;
    }

    @Given("que el usuario está autenticado para comprar")
    public void autenticarUsuarioParaComprar() {
        pages.loginPage().abrir();
        Credentials credentials = CredentialsProvider.standardUser();
        pages.loginPage().iniciarSesion(credentials.username(), credentials.password());
        assertEquals(
                ConfigReader.getRequired("inventory.expected.title"),
                pages.inventoryPage().obtenerTitulo(),
                "La compra requiere que el usuario acceda correctamente al inventario");
    }

    @When("agrega los productos configurados al carrito")
    public void agregarProductosConfiguradosAlCarrito() {
        List<String> productos = ConfigReader.getList("test.purchase.products");
        testContext.setPrefijoEsperadoCarrito(PREFIJO_ESPERADO_VARIOS);
        productos.forEach(producto -> pages.inventoryPage().agregarProductoAlCarrito(producto));
    }

    @When("agrega el producto individual configurado al carrito")
    public void agregarProductoIndividualConfiguradoAlCarrito() {
        String producto = ConfigReader.getRequired("test.purchase.single-product");
        testContext.setPrefijoEsperadoCarrito(PREFIJO_ESPERADO_UNICO);
        pages.inventoryPage().agregarProductoAlCarrito(producto);
    }

    @Then("el carrito refleja la cantidad de productos configurada")
    public void validarCantidadProductosEnCarrito() {
        assertEquals(
                ConfigReader.getPositiveInt(testContext.getPrefijoEsperadoCarrito() + ".count"),
                pages.inventoryPage().obtenerCantidadProductosEnCarrito(),
                "La insignia del carrito debería reflejar todos los productos seleccionados");
    }

    @Then("el carrito contiene los productos seleccionados")
    public void validarProductosEnCarrito() {
        pages.inventoryPage().abrirCarrito();
        assertEquals(
                ConfigReader.getList(testContext.getPrefijoEsperadoCarrito() + ".products"),
                pages.cartPage().obtenerNombresProductos(),
                "El carrito debería contener exactamente los productos seleccionados");
    }

    @When("tramita la compra con los datos de envío configurados")
    public void tramitarCompraConDatosConfigurados() {
        pages.cartPage().iniciarCheckout();
        pages.checkoutPage().completarInformacionEnvio(
                ConfigReader.getRequired("test.checkout.first-name"),
                ConfigReader.getRequired("test.checkout.last-name"),
                ConfigReader.getRequired("test.checkout.postal-code"));
        pages.checkoutPage().finalizarCompra();
    }

    @Then("la compra se confirma con el mensaje configurado")
    public void validarConfirmacionCompra() {
        assertEquals(
                ConfigReader.getRequired("checkout.expected.confirmation"),
                pages.checkoutPage().obtenerMensajeConfirmacion(),
                "La compra completada debería mostrar el mensaje de confirmación esperado");
    }
}
