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
}
