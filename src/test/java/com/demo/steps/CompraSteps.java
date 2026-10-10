package com.demo.steps;

import static org.junit.jupiter.api.Assertions.assertEquals;
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
