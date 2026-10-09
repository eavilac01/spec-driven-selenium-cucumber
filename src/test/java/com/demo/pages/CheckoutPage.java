package com.demo.pages;

import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;

import com.demo.utils.ConfigReader;

public final class CheckoutPage extends BasePage {

    private static final By CAMPO_NOMBRE = By.id("first-name");
    private static final By CAMPO_APELLIDO = By.id("last-name");
    private static final By CAMPO_CODIGO_POSTAL = By.id("postal-code");
    private static final By BOTON_CONTINUAR = By.id("continue");
    private static final By BOTON_FINALIZAR = By.id("finish");
    private static final By MENSAJE_CONFIRMACION = By.cssSelector("[data-test='complete-header']");

    public CheckoutPage(WebDriver driver) {
        super(driver);
    }

    public void completarInformacionEnvio(String nombre, String apellido, String codigoPostal) {
        esperarUrlContiene(ConfigReader.getRequired("route.checkout.information"));
        escribir(CAMPO_NOMBRE, nombre);
        escribir(CAMPO_APELLIDO, apellido);
        escribir(CAMPO_CODIGO_POSTAL, codigoPostal);
        clickYEsperarUrlContiene(
                BOTON_CONTINUAR,
                ConfigReader.getRequired("route.checkout.summary"));
    }

    public void finalizarCompra() {
        scrollA(BOTON_FINALIZAR);
        clickYEsperarUrlContiene(
                BOTON_FINALIZAR,
                ConfigReader.getRequired("route.checkout.complete"));
        esperarInvisibilidad(BOTON_FINALIZAR);
    }

    public String obtenerMensajeConfirmacion() {
        return obtenerTexto(MENSAJE_CONFIRMACION);
    }
}
