package com.demo.config;

import java.util.Objects;
import java.util.Optional;
import java.util.function.BooleanSupplier;
import java.util.function.Supplier;

/**
 * Decisión pura del clic nativo único de una acción (ADR-004, D2; ADR-002, D1): como mucho una pulsación por acción,
 * y solo cuenta la que retornó sin excepción.
 *
 * <p>No conoce Selenium (CHK-15): recibe la postcondición y un proveedor de la pulsación, y el transporte los
 * construye. Cada sondeo de la espera llama a {@link #sondear}. Una instancia por acción, sin estado compartido
 * entre hilos.</p>
 */
public final class ClicNativoUnico {

    private final String control;
    private boolean intentado;
    private int clicsEfectivos;

    /** @param control descripción del control para el mensaje de error; el transporte pasa su localizador */
    public ClicNativoUnico(String control) {
        this.control = Objects.requireNonNull(control, "La descripción del control no puede ser null");
    }

    /**
     * Un sondeo de la espera, en este orden:
     * <ol>
     *   <li>si la postcondición se cumple, devuelve {@code true} sin pedir la pulsación;</li>
     *   <li>si ya hubo un intento, devuelve {@code false};</li>
     *   <li>pide la pulsación: vacía (control no visible o deshabilitado) devuelve {@code false} sin marcar
     *   intento;</li>
     *   <li>marca el intento y después pulsa;</li>
     *   <li>si la pulsación lanza, no cuenta el clic y lanza {@link IllegalStateException} con la causa
     *   encadenada, que la espera no ignora;</li>
     *   <li>si retorna, cuenta el clic y devuelve la postcondición evaluada de nuevo.</li>
     * </ol>
     * Las excepciones de la postcondición y del proveedor se propagan sin envolver, para que la espera siga
     * ignorando las que ya ignoraba.
     */
    public boolean sondear(BooleanSupplier postcondicion, Supplier<Optional<Runnable>> pulsacion) {
        if (postcondicion.getAsBoolean()) {
            return true;
        }
        if (intentado) {
            return false;
        }
        Optional<Runnable> accion = pulsacion.get();
        if (accion.isEmpty()) {
            return false;
        }
        intentado = true;
        try {
            accion.get().run();
        } catch (RuntimeException causa) {
            throw new IllegalStateException("El clic nativo en %s lanzó %s; no se cuenta ni se repite (ADR-004, D2)"
                    .formatted(control, causa.getClass().getSimpleName()), causa);
        }
        clicsEfectivos = 1;
        return postcondicion.getAsBoolean();
    }

    /** 0 o 1: pulsaciones que retornaron sin excepción. */
    public int clicsEfectivos() {
        return clicsEfectivos;
    }
}
