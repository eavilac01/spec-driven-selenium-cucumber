package com.demo.contract;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.ByteArrayOutputStream;
import java.io.PrintStream;
import java.net.URISyntaxException;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.function.Supplier;

import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestInstance;
import org.openqa.selenium.By;

import com.demo.transport.Navegador;
import com.demo.utils.ConfigReader;

/**
 * Pruebas de contrato del transporte (ADR-004, D1 y D4): solo la API pública de {@link Navegador}, con un navegador
 * real, contra páginas locales estáticas de {@code src/test/resources/contract/} y sin red. Cada aserción compara
 * contra una clave {@code contract.expected.*}, independiente de la entrada, para que el control negativo con
 * {@code -D} la vea fallar (CHK-10).
 */
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class NavegadorContractTest {

    private static final By ACCION = By.id("accion");
    private static final By CLICS = By.id("clics");
    private static final String FRAGMENTO = "paso-siguiente";
    private static final String DIRECTORIO_PAGINAS = "/contract/";

    private static final String PAGINA_AVANZA = "avanza.html";
    private static final String PAGINA_INERTE = "inerte.html";
    private static final String PAGINA_DESHABILITADO = "deshabilitado.html";
    private static final String PAGINA_VELADO = "velado.html";

    private final Navegador navegador = new Navegador();

    @BeforeAll
    void iniciarNavegador() {
        navegador.iniciar();
    }

    @AfterAll
    void cerrarNavegador() {
        navegador.cerrar();
    }

    // --- Controles positivos ---

    @Test
    void ct01ClickYEsperarUrlContieneAvanzaConUnClic() {
        abrir(PAGINA_AVANZA);
        assertFalse(navegador.urlContiene(FRAGMENTO), "La página debe abrirse sin el fragmento de destino");

        navegador.clickYEsperarUrlContiene(ACCION, FRAGMENTO);

        assertEquals(esperadoEntero("contract.expected.clics-en-pagina"), clicsEnPagina());
    }

    @Test
    void ct02ClickYObservarUrlContieneObservaQueAvanza() {
        abrir(PAGINA_AVANZA);
        assertFalse(navegador.urlContiene(FRAGMENTO), "La página debe abrirse sin el fragmento de destino");

        Navegador.ResultadoClic resultado = navegador.clickYObservarUrlContiene(ACCION, FRAGMENTO);

        assertEquals(esperado("contract.expected.resultado.avanza"), resultado.name());
        assertEquals(esperadoEntero("contract.expected.clics-en-pagina"), clicsEnPagina());
    }

    @Test
    void ct03ClickPulsaUnaVez() {
        abrir(PAGINA_AVANZA);

        navegador.click(ACCION);

        assertEquals(esperadoEntero("contract.expected.clics-en-pagina"), clicsEnPagina());
    }

    // --- Clic nativo sin efecto: la pista de D8 (pendiente 1) ---

    @Test
    void ct04ClicSinEfectoFallaConLaPistaYSinSegundoClic() {
        abrir(PAGINA_INERTE);

        RuntimeException error = assertThrows(RuntimeException.class,
                () -> navegador.clickYEsperarUrlContiene(ACCION, FRAGMENTO));

        String mensaje = error.getMessage();
        assertTrue(mensaje.contains(esperado("contract.expected.clics-efectivos.uno")), mensaje);
        assertTrue(mensaje.contains(esperado("contract.expected.pista")), mensaje);
        assertEquals(esperadoEntero("contract.expected.clics-en-pagina"), clicsEnPagina());
    }

    @Test
    void ct05ClicSinEfectoObservadoRegistraLaPista() {
        abrir(PAGINA_INERTE);

        Capturado<Navegador.ResultadoClic> capturado =
                capturarErrorEstandar(() -> navegador.clickYObservarUrlContiene(ACCION, FRAGMENTO));

        assertEquals(esperado("contract.expected.resultado.sin-efecto"), capturado.resultado().name());
        assertTrue(capturado.salida().contains(esperado("contract.expected.clics-efectivos.uno")),
                capturado.salida());
        assertTrue(capturado.salida().contains(esperado("contract.expected.pista")), capturado.salida());
        assertEquals(esperadoEntero("contract.expected.clics-en-pagina"), clicsEnPagina());
    }

    // --- Sin clic no hay pista (prueba positiva y después la ausencia) ---

    @Test
    void ct06ControlDeshabilitadoFallaSinClicYSinPista() {
        abrir(PAGINA_DESHABILITADO);

        RuntimeException error = assertThrows(RuntimeException.class,
                () -> navegador.clickYEsperarUrlContiene(ACCION, FRAGMENTO));

        String mensaje = error.getMessage();
        assertTrue(mensaje.contains(esperado("contract.expected.clics-efectivos.cero")), mensaje);
        assertTrue(mensaje.contains(esperado("contract.expected.sin-clic")), mensaje);
        assertFalse(mensaje.contains(esperado("contract.expected.pista")), mensaje);
    }

    @Test
    void ct07ControlDeshabilitadoObservadoNoRegistraLaPista() {
        abrir(PAGINA_DESHABILITADO);

        Capturado<Navegador.ResultadoClic> capturado =
                capturarErrorEstandar(() -> navegador.clickYObservarUrlContiene(ACCION, FRAGMENTO));

        assertEquals(esperado("contract.expected.resultado.sin-clic"), capturado.resultado().name());
        assertTrue(capturado.salida().contains(esperado("contract.expected.clics-efectivos.cero")),
                capturado.salida());
        assertFalse(capturado.salida().contains(esperado("contract.expected.pista")), capturado.salida());
    }

    // --- Un clic que lanza sale envuelto, sin contarse ni repetirse (P2, ADR-004, D2) ---

    @Test
    void ct08ClicQueLanzaSaleEnvueltoSinContarseNiRepetirse() {
        abrir(PAGINA_VELADO);

        IllegalStateException error = assertThrows(IllegalStateException.class, () -> navegador.click(ACCION));

        String causaEsperada = esperado("contract.expected.causa-interceptada");
        assertNotNull(error.getCause(), error.getMessage());
        assertEquals(causaEsperada, error.getCause().getClass().getSimpleName());
        assertTrue(error.getMessage().contains(causaEsperada), error.getMessage());
        assertEquals(esperadoEntero("contract.expected.clics-en-pagina.interceptado"), clicsEnPagina());
    }

    // --- Utilidades ---

    /** Abre una página local por su nombre de recurso; si falta, falla cerrado nombrando el archivo. */
    private void abrir(String pagina) {
        URL recurso = NavegadorContractTest.class.getResource(DIRECTORIO_PAGINAS + pagina);
        if (recurso == null) {
            throw new IllegalStateException("No se encontró la página local '%s' en el classpath".formatted(pagina));
        }
        try {
            navegador.abrir(Path.of(recurso.toURI()).toUri().toString());
        } catch (URISyntaxException exception) {
            throw new IllegalStateException("La página local '%s' no tiene una ruta válida".formatted(pagina),
                    exception);
        }
    }

    private int clicsEnPagina() {
        return Integer.parseInt(navegador.texto(CLICS).trim());
    }

    private static String esperado(String clave) {
        return ConfigReader.getRequired(clave);
    }

    private static int esperadoEntero(String clave) {
        return ConfigReader.getNonNegativeInt(clave);
    }

    /**
     * Ejecuta la acción con el error estándar sustituido por un flujo en memoria y lo restaura siempre: slf4j-simple
     * escribe sus INFO en el {@code System.err} vigente (ADR-004, D4 y R-1). Si dejara de hacerlo, la captura
     * quedaría vacía y la aserción positiva fallaría.
     */
    private static <T> Capturado<T> capturarErrorEstandar(Supplier<T> accion) {
        PrintStream original = System.err;
        ByteArrayOutputStream buffer = new ByteArrayOutputStream();
        PrintStream captura = new PrintStream(buffer, true, StandardCharsets.UTF_8);
        System.setErr(captura);
        try {
            T resultado = accion.get();
            return new Capturado<>(resultado, buffer.toString(StandardCharsets.UTF_8));
        } finally {
            System.setErr(original);
            captura.close();
        }
    }

    private record Capturado<T>(T resultado, String salida) {
    }
}
