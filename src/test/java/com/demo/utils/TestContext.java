package com.demo.utils;

import java.util.Objects;

import org.openqa.selenium.WebDriver;

public final class TestContext {

    private WebDriver driver;
    private String prefijoEsperadoCarrito;

    public WebDriver getDriver() {
        if (driver == null) {
            throw new IllegalStateException("El WebDriver aún no fue asignado al escenario");
        }
        return driver;
    }

    public void setDriver(WebDriver driver) {
        this.driver = Objects.requireNonNull(driver, "El WebDriver no puede ser null");
    }

    public String getPrefijoEsperadoCarrito() {
        if (prefijoEsperadoCarrito == null) {
            throw new IllegalStateException(
                    "El escenario aún no registró el conjunto de valores esperados del carrito");
        }
        return prefijoEsperadoCarrito;
    }

    public void setPrefijoEsperadoCarrito(String prefijoEsperadoCarrito) {
        this.prefijoEsperadoCarrito = Objects.requireNonNull(
                prefijoEsperadoCarrito,
                "El prefijo de valores esperados del carrito no puede ser null");
    }
}
