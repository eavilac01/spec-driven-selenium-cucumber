package com.demo.pages;

import java.util.Objects;

import org.openqa.selenium.By;

import com.demo.transport.Navegador;
import com.demo.utils.ConfigReader;

public final class CheckoutPage {

    private static final By CAMPO_NOMBRE = By.id("first-name");
    private static final By CAMPO_APELLIDO = By.id("last-name");
    private static final By CAMPO_CODIGO_POSTAL = By.id("postal-code");
    private static final By BOTON_CONTINUAR = By.id("continue");
    private static final By BOTON_FINALIZAR = By.id("finish");
    private static final By MENSAJE_CONFIRMACION = By.cssSelector("[data-test='complete-header']");
    private static final By MENSAJE_ERROR = By.cssSelector("[data-test='error']");

    private final Navegador navegador;

    public CheckoutPage(Navegador navegador) {
        this.navegador = Objects.requireNonNull(navegador, "El navegador no puede ser null");
    }

    public void completarInformacionEnvio(String nombre, String apellido, String codigoPostal) {
        navegador.esperarUrlContiene(ConfigReader.getRequired("route.checkout.information"));
        navegador.escribir(CAMPO_NOMBRE, nombre);
        navegador.escribir(CAMPO_APELLIDO, apellido);
        navegador.escribir(CAMPO_CODIGO_POSTAL, codigoPostal);
        navegador.clickYEsperarUrlContiene(
                BOTON_CONTINUAR,
                ConfigReader.getRequired("route.checkout.summary"));
    }

    /**
     * Escribe solo los datos informados (un texto vacío deja el campo intacto) y pulsa continuar hasta que
     * el clic tenga un resultado observable (un mensaje de error o el resumen de la compra): quien lo
     * llama observa cuál de los dos ocurrió.
     */
    public void intentarContinuarConInformacionEnvio(String nombre, String apellido, String codigoPostal) {
        navegador.esperarUrlContiene(ConfigReader.getRequired("route.checkout.information"));
        escribirSiInformado(CAMPO_NOMBRE, nombre);
        escribirSiInformado(CAMPO_APELLIDO, apellido);
        escribirSiInformado(CAMPO_CODIGO_POSTAL, codigoPostal);
        navegador.clickYEsperarVisibleOUrlContiene(
                BOTON_CONTINUAR,
                MENSAJE_ERROR,
                ConfigReader.getRequired("route.checkout.summary"));
    }

    public void finalizarCompra() {
        navegador.desplazarA(BOTON_FINALIZAR);
        navegador.clickYEsperarUrlContiene(
                BOTON_FINALIZAR,
                ConfigReader.getRequired("route.checkout.complete"));
        navegador.esperarInvisible(BOTON_FINALIZAR);
    }

    public String obtenerMensajeConfirmacion() {
        return navegador.texto(MENSAJE_CONFIRMACION);
    }

    /** Lectura inmediata: indica si el cliente está en la pantalla de datos de envío. */
    public boolean estaEnDatosEnvio() {
        return navegador.urlContiene(ConfigReader.getRequired("route.checkout.information"));
    }

    /** Observa, dentro del tiempo máximo, si se informó un error de datos de envío. */
    public boolean seMuestraMensajeError() {
        return navegador.apareceEnTiempoMaximo(MENSAJE_ERROR);
    }

    public String obtenerMensajeError() {
        return navegador.texto(MENSAJE_ERROR);
    }

    private void escribirSiInformado(By campo, String valor) {
        Objects.requireNonNull(valor, "El dato de envío no puede ser null");
        if (!valor.isEmpty()) {
            navegador.escribir(campo, valor);
        }
    }
}
