package com.demo.utils;

import java.util.List;
import java.util.Objects;

import org.openqa.selenium.WebDriver;

public final class TestContext {

    private WebDriver driver;
    private List<String> productosSeleccionados = List.of();

    public WebDriver getDriver() {
        if (driver == null) {
            throw new IllegalStateException("El WebDriver aún no fue asignado al escenario");
        }
        return driver;
    }

    public void setDriver(WebDriver driver) {
        this.driver = Objects.requireNonNull(driver, "El WebDriver no puede ser null");
    }

    public List<String> getProductosSeleccionados() {
        return productosSeleccionados;
    }

    public void setProductosSeleccionados(List<String> productosSeleccionados) {
        this.productosSeleccionados = List.copyOf(Objects.requireNonNull(
                productosSeleccionados,
                "Los productos seleccionados no pueden ser null"));
    }
}
