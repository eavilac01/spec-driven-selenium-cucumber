package com.demo.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.NoSuchElementException;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.BooleanSupplier;
import java.util.function.Supplier;
import org.junit.jupiter.api.Test;

/** Pruebas unitarias del clic nativo único (ADR-004, D2). Las pulsaciones cuentan sus invocaciones. */
class ClicNativoUnicoTest {

    private static final String CONTROL = "By.id: accion";

    private final AtomicInteger pedidas = new AtomicInteger();
    private final AtomicInteger pulsadas = new AtomicInteger();

    /** Proveedor de una pulsación disponible que retorna; cuenta cuántas veces se pidió y cuántas se pulsó. */
    private Supplier<Optional<Runnable>> disponible() {
        return () -> {
            pedidas.incrementAndGet();
            return Optional.of(pulsadas::incrementAndGet);
        };
    }

    /** Proveedor de un control no disponible (no visible o deshabilitado). */
    private Supplier<Optional<Runnable>> noDisponible() {
        return () -> {
            pedidas.incrementAndGet();
            return Optional.empty();
        };
    }

    /** Proveedor de una pulsación que lanza la excepción dada después de contarse como pulsada. */
    private Supplier<Optional<Runnable>> queLanza(RuntimeException causa) {
        return () -> {
            pedidas.incrementAndGet();
            return Optional.of(() -> {
                pulsadas.incrementAndGet();
                throw causa;
            });
        };
    }

    @Test
    void uc01PostcondicionYaCumplidaNoPideLaPulsacion() {
        ClicNativoUnico clic = new ClicNativoUnico(CONTROL);

        assertTrue(clic.sondear(() -> true, disponible()));

        assertEquals(0, pedidas.get());
        assertEquals(0, pulsadas.get());
        assertEquals(0, clic.clicsEfectivos());
    }

    @Test
    void uc02ControlNoDisponibleNoConsumeElIntento() {
        ClicNativoUnico clic = new ClicNativoUnico(CONTROL);

        assertFalse(clic.sondear(() -> false, noDisponible()));
        assertEquals(1, pedidas.get());
        assertEquals(0, pulsadas.get());
        assertEquals(0, clic.clicsEfectivos());

        assertFalse(clic.sondear(() -> false, disponible()));
        assertEquals(1, pulsadas.get());
        assertEquals(1, clic.clicsEfectivos());
    }

    @Test
    void uc03PulsacionQueRetornaCuentaUnClicYReevaluaLaPostcondicion() {
        AtomicInteger evaluaciones = new AtomicInteger();
        BooleanSupplier cumpleTrasElClic = () -> evaluaciones.incrementAndGet() > 1;
        ClicNativoUnico conEfecto = new ClicNativoUnico(CONTROL);

        assertTrue(conEfecto.sondear(cumpleTrasElClic, disponible()));
        assertEquals(2, evaluaciones.get());
        assertEquals(1, pulsadas.get());
        assertEquals(1, conEfecto.clicsEfectivos());

        ClicNativoUnico sinEfecto = new ClicNativoUnico(CONTROL);

        assertFalse(sinEfecto.sondear(() -> false, disponible()));
        assertEquals(2, pulsadas.get());
        assertEquals(1, sinEfecto.clicsEfectivos());
    }

    @Test
    void uc04TrasUnClicSinEfectoNoVuelveAPedirNiAPulsar() {
        ClicNativoUnico clic = new ClicNativoUnico(CONTROL);
        assertFalse(clic.sondear(() -> false, disponible()));

        for (int sondeo = 0; sondeo < 5; sondeo++) {
            assertFalse(clic.sondear(() -> false, disponible()));
        }

        assertEquals(1, pedidas.get());
        assertEquals(1, pulsadas.get());
        assertEquals(1, clic.clicsEfectivos());
    }

    @Test
    void uc05PulsacionQueLanzaSaleEnvueltaConLaMismaCausaYSinContarse() {
        for (RuntimeException causa : new RuntimeException[] {
                new NoSuchElementException("sin elemento"), new IllegalArgumentException("argumento")}) {
            ClicNativoUnico clic = new ClicNativoUnico(CONTROL);

            IllegalStateException error = assertThrows(IllegalStateException.class,
                    () -> clic.sondear(() -> false, queLanza(causa)));

            assertSame(causa, error.getCause());
            assertEquals("El clic nativo en By.id: accion lanzó " + causa.getClass().getSimpleName()
                    + "; no se cuenta ni se repite (ADR-004, D2)", error.getMessage());
            assertEquals(0, clic.clicsEfectivos());
        }
        assertEquals(2, pulsadas.get());
    }

    @Test
    void uc06RegresionDelP2LaPostcondicionDeClickNuncaSeCumpleTrasUnClicQueLanza() {
        ClicNativoUnico clic = new ClicNativoUnico(CONTROL);
        BooleanSupplier postcondicionDeClick = () -> clic.clicsEfectivos() > 0;
        assertThrows(IllegalStateException.class,
                () -> clic.sondear(postcondicionDeClick, queLanza(new NoSuchElementException("sin elemento"))));

        for (int sondeo = 0; sondeo < 5; sondeo++) {
            assertFalse(clic.sondear(postcondicionDeClick, disponible()));
            assertEquals(0, clic.clicsEfectivos());
        }

        assertEquals(1, pedidas.get());
        assertEquals(1, pulsadas.get());
    }

    @Test
    void uc07ElProveedorQueLanzaSePropagaSinEnvolverYSinMarcarIntento() {
        ClicNativoUnico clic = new ClicNativoUnico(CONTROL);
        NoSuchElementException busqueda = new NoSuchElementException("sin elemento");

        NoSuchElementException error = assertThrows(NoSuchElementException.class,
                () -> clic.sondear(() -> false, () -> {
                    throw busqueda;
                }));

        assertSame(busqueda, error);
        assertEquals(0, clic.clicsEfectivos());
        assertFalse(clic.sondear(() -> false, disponible()));
        assertEquals(1, pulsadas.get());
        assertEquals(1, clic.clicsEfectivos());
    }

    @Test
    void uc08LaPostcondicionQueLanzaAntesDelClicSePropagaSinIntento() {
        ClicNativoUnico clic = new ClicNativoUnico(CONTROL);
        NoSuchElementException ausencia = new NoSuchElementException("ausente");

        NoSuchElementException error = assertThrows(NoSuchElementException.class,
                () -> clic.sondear(() -> {
                    throw ausencia;
                }, disponible()));

        assertSame(ausencia, error);
        assertEquals(0, pedidas.get());
        assertFalse(clic.sondear(() -> false, disponible()));
        assertEquals(1, pulsadas.get());
    }

    @Test
    void uc09LaPostcondicionQueLanzaTrasElClicSePropagaYElClicQuedaContado() {
        ClicNativoUnico clic = new ClicNativoUnico(CONTROL);
        AtomicInteger evaluaciones = new AtomicInteger();
        NoSuchElementException ausencia = new NoSuchElementException("ausente");
        BooleanSupplier lanzaTrasElClic = () -> {
            if (evaluaciones.incrementAndGet() > 1) {
                throw ausencia;
            }
            return false;
        };

        NoSuchElementException error = assertThrows(NoSuchElementException.class,
                () -> clic.sondear(lanzaTrasElClic, disponible()));

        assertSame(ausencia, error);
        assertEquals(1, clic.clicsEfectivos());
        assertFalse(clic.sondear(() -> false, disponible()));
        assertEquals(1, pulsadas.get());
        assertEquals(1, pedidas.get());
    }

    @Test
    void uc10ControlNullSeRechazaConMensaje() {
        NullPointerException error = assertThrows(NullPointerException.class, () -> new ClicNativoUnico(null));

        assertEquals("La descripción del control no puede ser null", error.getMessage());
    }
}
