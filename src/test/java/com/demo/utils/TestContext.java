package com.demo.utils;

import java.util.Objects;

public final class TestContext {

    private String prefijoEsperadoCarrito;

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
