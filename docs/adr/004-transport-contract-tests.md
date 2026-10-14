# ADR-004 — Pruebas de contrato del transporte con páginas locales y clic nativo único como lógica pura

- **Estado:** Aceptado (aprobado por el coordinador, 2026-10-13). El usuario aprobó los textos de los grupos A y B. El grupo A está aplicado en `d5b18ef`, y el B se aplica con el paso 5. Se propuso el mismo día.
- **Fecha:** 2026-10-13
- **Autor:** `qa-automation-architect`
- **Aprueba:** coordinador (Regla 01, nivel 2). Los textos para reglas y agentes (*Cambios propuestos*) los aprueba y aplica el usuario (P-01, PI-07).
- **Relación con otros ADR:** extiende el ADR-002 (D1, D4, D6 y D7) y activa el disparador de su opción F de la parte 4 (*Clic nativo único, scripts cerrados y preferencias de Chrome*, decisión 1). Aplica el criterio D1(b) del ADR-001 a una clase nueva de `src/main`. No modifica el ADR-002 ni el ADR-003: la enmienda cruzada del ADR-002 es el paso 1 de *Plan de implementación*.
- **Base:** se redactó sobre `4b91990`. Entre `b36879e` (el HEAD que cita el coordinador) y `4b91990` solo cambian `.github/workflows/ci.yml` y `.mvn/wrapper/maven-wrapper.properties` (`git diff --stat b36879e 4b91990`), así que las referencias a `src`, `scripts`, `docs` y `pom.xml` valen para los dos. Al aceptarlo, HEAD es `fe566e3`, que integra la parte 5 del ADR-002 (*Escritura única*: 36 comprobaciones y 432 casos). Entre `4b91990` y `fe566e3`, `src` y `pom.xml` no cambian (`git diff --stat 4b91990 fe566e3 -- src pom.xml` no da salida), así que las líneas citadas de `Navegador` valen también allí. Después, `02cf8fe` cambia `Navegador` y `DriverFactory` (mensajes con una URL, PI-09; ADR-002, D1, parte 6) sin tocar el clic. En `0a51d89` las mismas líneas son: conteo y clic en `:414-415`, postcondición de `click(By)` en `:154`, guarda en `:407`, INFO con la pista en `:192-193` y excepción con la pista en `:384-392`.

**Terminología.** "Capa N" es la del arquitecto (`.claude/agents/qa-automation-architect.md`, *Arquitectura objetivo*), no el "nivel" de la Regla 01. "Prueba de contrato del transporte" es una prueba JUnit que usa solo la API pública de `Navegador` contra páginas HTML locales versionadas, con un navegador real y sin red. "Página local" (*fixture*) es una de esas páginas. Nada de esto es el SUT.

## Contexto

### Los dos pendientes

**1. La pista de D8 en el clic de tramitar no se ha observado en vivo** (`MEMORY.md`, *Próximos pasos*, punto 3).
- `CartPage.iniciarCheckout` exige avanzar con `clickYEsperarUrlContiene` (`CartPage.java:32`, desde `4dc9b38`). Si el clic nativo no surte efecto, `clickHastaCumplir` lanza `TimeoutException` con `PISTA_ENTRADA_NATIVA_SIN_EFECTO` (`Navegador.java:370-378`), y `clickYObservarUrlContiene` registra el INFO de `NO_AVANZO` con la pista (`:178-179`).
- La única causa real conocida de un clic sin efecto es el aviso de contraseñas filtradas de Chrome (ADR-002, D8). Aparece solo si el servicio de Google responde, y en 10 intentos sin la preferencia respondió 429 (según el coordinador). No depende del proyecto, así que no sirve como prueba.
- Hoy nada ejercita esas dos ramas de forma determinista: la E2E contra SauceDemo no puede producir a voluntad un clic sin efecto.

**2. P2 del verificador sobre `click(By)` (`0a3b6fb`).** En `clicNativoUnicoHastaCumplir` el clic se cuenta **antes** de pulsar (`Navegador.java:400`, `clicsEfectivos.incrementAndGet()`; `:401`, `elemento.click()`).
- `WebDriverWait` ignora `NotFoundException` y sus subclases (`NoSuchElementException`, `NoSuchWindowException`, …), según la API de Selenium 4. No se ejecutó aquí (B-01).
- Si `elemento.click()` lanza una de ellas, el contador queda en 1 sin que el clic haya ocurrido, y la espera vuelve a sondear.
- En `click(By)`, la postcondición es `clicsEfectivos.get() > 0` (`:140`): el siguiente sondeo la da por cumplida y el método retorna. **Falla abierto.**
- En los demás métodos, la guarda `if (clicsEfectivos.get() > 0) return false;` (`:393`) impide un segundo clic, así que la espera agota el plazo y falla cerrado, pero con un mensaje engañoso: "clics efectivos: 1; el clic nativo no tuvo efecto", más la pista de D8.

### Por qué hoy no hay prueba posible

| Hecho | Evidencia | Consecuencia |
|---|---|---|
| `Navegador` y `DriverFactory` usan Selenium y viven en `src/test` | ADR-001, D2; CHK-15; `selenium-java` con alcance `test` (`pom.xml`) | PIT no los muta (ADR-002, parte 3, punto 7) |
| Las unitarias solo viven en `config` y `data`, sin Selenium | CHK-16 | No pueden ejercitar `Navegador` |
| R4 rechaza JUnit en `transport`, y `R5-clic` y `R5-clic-max` cuentan cualquier `.click` | `scripts/check-layers.sh`, comandos D7-07, `R5-clic` y `R5-clic-max` | Una prueba en `transport` necesitaría tres excepciones |
| La guarda del clic único no la ve ningún comando ni la suite | ADR-002, D7, parte 4, *Riesgo residual aceptado*, primer punto | Era el disparador de su opción F |
| La opción F (llevar la decisión del clic a `src/main`) se descartó porque "el cableado en `Navegador` seguiría sin prueba" | ADR-002, D7, parte 4, decisión 1, fila F | Este ADR cierra esa objeción con D1 |

### Por qué el camino del P2 no se reproduce con un navegador real

Para demostrar el fallo abierto, `elemento.click()` tiene que lanzar una excepción **ignorada** después de que la espera vio el control visible y habilitado.
- Un elemento que se elimina del DOM entre la búsqueda y el clic da `stale element reference` en los drivers W3C, y `StaleElementReferenceException` no es una `NotFoundException`: la espera no la ignora y el error sale cerrado.
- `no such element` y `no such window` en el comando de clic exigen un elemento de otro contexto de navegación o una ventana cerrada. `Navegador` no expone marcos ni ventanas.
- Un botón que se elimina al pulsarlo (la sugerencia del coordinador) deja que `click()` **retorne**: el evento ya se entregó. Prueba el camino correcto, no el defectuoso.
- Un temporizador o una página que se cierra sola compiten con el sondeo: el resultado depende del tiempo.

Por eso el P2 se demuestra con lógica pura (D2), y el navegador real demuestra el cableado (D1, D4).

## Decisión

### D1. Las pruebas de contrato viven en `com.demo.contract` (capa 5)

- **Qué:** `src/test/java/com/demo/contract/`, con una clase de JUnit 5 (nombre orientativo `NavegadorContractTest`). Solo usa la API pública de `Navegador`, como las páginas: `iniciar`, `abrir`, `click`, `clickYEsperarUrlContiene`, `clickYObservarUrlContiene`, `texto`, `urlContiene` y `cerrar`.
- **Capa 5:** dirige el ciclo de vida del navegador, como `Hooks`, y verifica. La fila 5 del arquitecto ya depende de 1 y 4.
- **Fila nueva del grafo de dependencias** (amplía la tabla de D4 del ADR-002):

| Capa | Paquete | Puede nombrar | Selenium | JUnit / Cucumber |
|---|---|---|---|---|
| 5 | `contract` | `transport`, `utils` (solo `ConfigReader`) | Solo `import org.openqa.selenium.By;`, como `pages` | Solo JUnit |

  Ningún otro paquete nombra `contract`, tampoco el glue de Cucumber (`RunnerTest`). Lo comprueba CHK-17 (D8).
- **No es una prueba unitaria.** Abre un navegador real, así que no entra en CHK-16 ni en PIT (D7). CHK-16 no cambia.
- **SDD:** no requiere spec. Las origina este ADR, como a las unitarias del framework (SDD-02; texto en *Cambios propuestos*).
- **Surefire:** `pom.xml` suma el include `com/demo/contract/**/*Test.java` (devops). Así corren en CHK-08 sin cambiar su comando.
- **Ciclo de vida:** una instancia de `Navegador` por clase (`@TestInstance(PER_CLASS)`, `iniciar` en `@BeforeAll` y `cerrar` en `@AfterAll`, que JUnit ejecuta aunque fallen las pruebas). Cada prueba abre su propia página, así que no dependen del orden. JUnit Platform ejecuta los motores uno tras otro, así que este navegador nunca compite con los 2 hilos de Cucumber (R-5).

### D2. El clic nativo único pasa a `src/main` como lógica pura: `ClicNativoUnico`

Es la opción F de la parte 4 del ADR-002, con su disparador cumplido: el P2 es un defecto real en el contador que leen la guarda y `click(By)`. Su objeción ("el cableado seguiría sin prueba") la cierran las pruebas de contrato (D1 y D4).

**Ubicación:** `src/main/java/com/demo/config/ClicNativoUnico.java`, junto a `BrowserErrorPage`, que ya es lógica pura del transporte en `config`. `transport` ya puede nombrar `config` (D4 del ADR-002), y PIT, Surefire, CHK-15 y CHK-16 ya cubren ese paquete sin cambios. El nombre del paquete queda impreciso, como ya lo era con `BrowserErrorPage`; no se abre un paquete nuevo por eso.

**Contrato** (nombres orientativos; una instancia por acción de clic, sin estado compartido entre hilos):

| Miembro | Contrato |
|---|---|
| Constructor con la descripción del control (`String`) | El `Navegador` pasa `localizador.toString()`. Con `null`, `NullPointerException` con mensaje |
| `boolean sondear(postcondición, pulsación)` | Un sondeo de la espera. `postcondición` es un `BooleanSupplier`; `pulsación` es un proveedor que devuelve la acción de pulsar (`Runnable`) si el control está visible y habilitado, o vacío si no. Orden: **1)** si la postcondición se cumple, devuelve `true` sin pedir la pulsación; **2)** si ya hubo un intento, devuelve `false`; **3)** pide la pulsación: vacía, devuelve `false` sin marcar intento; **4)** marca el intento y **después** pulsa; **5)** si la pulsación lanza una `RuntimeException`, no cuenta el clic y lanza `IllegalStateException` con la causa encadenada; **6)** si retorna, cuenta el clic y devuelve la postcondición evaluada de nuevo |
| `int clicsEfectivos()` | 0 o 1: pulsaciones que **retornaron** sin excepción |

- **Mensaje del punto 5 de `sondear`:** `El clic nativo en <control> lanzó <nombre simple de la causa>; no se cuenta ni se repite (ADR-004, D2)`. No incluye texto del SUT ni el texto escrito (PI-05, PI-09); el mensaje original del driver viaja solo en la causa, como hoy con cualquier excepción de Selenium.
- **Qué no se envuelve:** las excepciones de la postcondición y del proveedor de la pulsación (la búsqueda del control) se propagan **sin envolver**. Así la espera sigue ignorando las `NotFoundException` de una búsqueda o de una postcondición, como hoy.
- **Por qué cierra el P2, en las dos mitades:**
  - Cualquier excepción del clic sale de la espera como `IllegalStateException`, que `WebDriverWait` no ignora: no hay segundo sondeo y no puede haber segundo clic (D1 del ADR-002; `R5-clic-max`).
  - Aunque un llamador la ignorara, el intento ya está marcado y el clic no está contado: no se vuelve a pulsar, y la postcondición de `click(By)` (`clicsEfectivos() > 0`) nunca se cumple. Falla cerrado.
  - La clase está en `src/main`, así que no puede nombrar tipos de Selenium (CHK-15). No puede estrechar el `catch` a una excepción de Selenium: trata todas igual por construcción.

**Cableado en `Navegador`** (engineer; API pública y textos de los mensajes sin cambios):
- `clicNativoUnicoHastaCumplir` recibe un `ClicNativoUnico` y devuelve una condición que llama a `sondear` con la postcondición del método y con una pulsación construida sobre `ExpectedConditions.elementToBeClickable`. El cuerpo de esa pulsación es la **única** línea de clic de `transport`, exactamente `elemento.click();` (`R5-clic` y `R5-clic-max` no cambian).
- `click(By)` usa como postcondición `clicsEfectivos() > 0` del mismo objeto.
- `clickHastaCumplir` y `clickYObservarUrlContiene` leen `clicsEfectivos()` para el mensaje, el INFO y `NO_DISPONIBLE`. Desaparece el `AtomicInteger` de clics de `Navegador`.
- El Javadoc de `clicNativoUnicoHastaCumplir` deja de decir "contando el clic antes de pulsar". Ningún comentario de `transport` nombra `.click` ni el vocabulario de `EVT` (D6 del ADR-002).
- **Cambio de comportamiento visible:** un clic que lanza (por ejemplo `ElementClickInterceptedException`) pasa a llegar como `IllegalStateException` con esa causa. Ninguna página, acción ni hook captura excepciones de Selenium (las páginas solo importan `By`), así que solo cambia el texto del reporte.

**Pruebas unitarias** (`src/test/java/com/demo/config/ClicNativoUnicoTest.java`; las pulsaciones son lambdas que cuentan sus invocaciones, y las excepciones, del JDK):

| ID | Exige |
|---|---|
| UC-01 | Postcondición ya cumplida: `true`, sin pedir la pulsación |
| UC-02 | Control no disponible: `false`, sin pulsar y con 0 clics; en un sondeo posterior con el control disponible, pulsa (no disponible no consume el intento) |
| UC-03 | Pulsación que retorna: una invocación, 1 clic, y devuelve la postcondición reevaluada (un caso con `true` y otro con `false`) |
| UC-04 | Tras UC-03 con postcondición falsa, N sondeos más no piden la pulsación, no pulsan y devuelven `false` |
| UC-05 | Pulsación que lanza (dos tipos distintos, p. ej. `java.util.NoSuchElementException` e `IllegalArgumentException`): `IllegalStateException` con la **misma** causa (`assertSame`), el control y el nombre simple de la causa en el mensaje, y 0 clics |
| UC-06 | **Regresión del P2:** tras UC-05, el llamador ignora la excepción y vuelve a sondear con la postcondición de `click(By)` (`clicsEfectivos() > 0`): no pulsa, devuelve `false` y sigue con 0 clics, en cada sondeo |
| UC-07 | El proveedor de la pulsación lanza: se propaga la misma instancia, sin envolver y sin marcar intento; el sondeo siguiente puede pulsar |
| UC-08 | La postcondición lanza antes del clic: se propaga sin envolver y sin intento |
| UC-09 | La postcondición lanza después del clic: se propaga sin envolver; el clic queda contado (1) y no se repite |
| UC-10 | Constructor con `null`: `NullPointerException` con mensaje (PIT no muta `requireNonNull`: control negativo manual, como en D8 del ADR-002) |

### D3. Páginas locales versionadas, abiertas por `file:`, sin red

- **Dónde:** `src/test/resources/contract/`. Maven las copia a `target/test-classes/contract/`, dentro del repositorio. Las escribe el engineer (Regla 02, *Cambios propuestos*).
- **Cómo se abren:** la prueba obtiene la URL del recurso del classpath por un nombre constante y la convierte en una URL `file:` (`Path.toUri()`). Si el recurso falta, falla cerrado con un mensaje que nombra el archivo. `abrir` no cambia: una página que no carga da su `IllegalStateException` de página de error (ADR-002, D1).
- **Cuatro páginas, estáticas, sin lógica propia más allá de un contador de clics:**

| Página | Control `#accion` | Efecto del clic | Además |
|---|---|---|---|
| `avanza.html` | Botón habilitado | Suma 1 al contador `#clics` y cambia el fragmento de la URL a `paso-siguiente` | — |
| `inerte.html` | Botón habilitado | Solo suma 1 al contador | Simula, para `Navegador`, un clic nativo que retorna sin efecto |
| `deshabilitado.html` | Botón con `disabled` | Ninguno | El contador queda en 0 |
| `velado.html` | Botón habilitado | Suma 1 al contador | Un `div` `#velo` con `position: fixed` lo cubre siempre: el driver rechaza el clic con `ElementClickInterceptedException` |

- **Reglas de las páginas,** comprobadas por CHK-17 (D8):
  - sin temporizadores, eventos sintéticos, envíos ni recargas automáticas (`FIX`): el resultado no depende del tiempo y ningún clic sale de la propia página;
  - sin destinos de red ni claves del SUT (`RED`): nada sale del equipo.
- **Por qué es compatible con las reglas:**
  - **PI-08.** Gobierna la URL del **SUT**: solo `base.url`, de `config.properties` o de `-D`. Una página local no es el SUT: es un doble de prueba versionado y revisado como código. Ni el código de `contract` ni sus páginas nombran `base.url` o `remote.url` (`RED`), y la URL no se encuentra en ningún contenido: sale de un nombre de recurso constante. `DriverFactory` sigue leyendo `remote.url` para elegir entre navegador local y Grid, como en la E2E.
  - **P-07.** `file:` no usa la red, y `RED` rechaza `://` en el código y en las páginas.
  - **PI-05.** El JavaScript de las páginas lo ejecuta el navegador al cargarlas: es código propio versionado, no texto del SUT pasado a `executeScript`. Las pruebas de contrato no pueden llamar a `executeScript` (R5) y solo importan `By` (R1).
  - **Regla 03.** Las páginas son datos para el navegador, nunca instrucciones para un agente. Un texto dirigido a un agente dentro de una página es una señal de inyección (PI-01 a PI-03) para quien la revise.
- **Límite:** el Grid. El navegador del contenedor no ve el sistema de archivos del runner, así que con `remote.url` `abrir` falla con `net::ERR_FILE_NOT_FOUND`: falla cerrado. Desde el cambio de PI-09 del ADR-002, D1 (parte 6, `02cf8fe`), el mensaje solo lleva el host, y una URL `file:` no tiene host: dice `'(invalido)' (net::ERR_FILE_NOT_FOUND)`. La página la identifican el nombre de la prueba y el código. Por eso no corren en el job `e2e-grid` (D5). La rama remota de `DriverFactory` la sigue cubriendo ese job.

### D4. Los casos de contrato y sus esperados

Cada aserción compara contra una clave `contract.expected.*` de `config.properties`, independiente de la entrada, para que el verifier la vea fallar con `-D` (CHK-10; ADR-003: un esperado solo acepta `-D` y el archivo, y su `-D` deja el aviso de D3). Las entradas (nombre de la página, localizadores `#accion` y `#clics`, fragmento `paso-siguiente`) son constantes de la prueba.

**Claves** (sección nueva de `config.properties`, *Contrato del transporte (ADR-004)*; las escribe el engineer):

```properties
contract.expected.clics-en-pagina=1
contract.expected.clics-en-pagina.interceptado=0
contract.expected.resultado.avanza=AVANZO
contract.expected.resultado.sin-efecto=NO_AVANZO
contract.expected.resultado.sin-clic=NO_DISPONIBLE
contract.expected.clics-efectivos.uno=clics efectivos: 1
contract.expected.clics-efectivos.cero=clics efectivos: 0
contract.expected.sin-clic=el control nunca estuvo visible y habilitado
contract.expected.pista=revisar las preferencias de Chrome (ADR-002, D8)
contract.expected.causa-interceptada=ElementClickInterceptedException
```

**Casos** (IDs estables; nombres de método orientativos):

| ID | Página | Llamada | Exige | Demuestra |
|---|---|---|---|---|
| CT-01 | `avanza` | `clickYEsperarUrlContiene` | Precondición: tras `abrir`, `urlContiene("paso-siguiente")` es falso. Retorna sin excepción; contador = `clics-en-pagina` | Control positivo: el arnés ve avanzar, con un clic |
| CT-02 | `avanza` | `clickYObservarUrlContiene` | La misma precondición; resultado = `resultado.avanza`; contador = `clics-en-pagina` | Control positivo de la observación |
| CT-03 | `avanza` | `click(By)` | Retorna; contador = `clics-en-pagina` | `click(By)` pulsa una vez |
| CT-04 | `inerte` | `clickYEsperarUrlContiene` | Lanza; el mensaje contiene `clics-efectivos.uno` y `pista`; contador = `clics-en-pagina` | **Pendiente 1:** la pista sale del transporte ante un clic nativo sin efecto; y no hay segundo clic en todo el plazo (cierra en integración el *Riesgo residual* de la guarda) |
| CT-05 | `inerte` | `clickYObservarUrlContiene` | Resultado = `resultado.sin-efecto`; el INFO capturado contiene `clics-efectivos.uno` y `pista`; contador = `clics-en-pagina` | **Pendiente 1:** el INFO de `NO_AVANZO` lleva la pista |
| CT-06 | `deshabilitado` | `clickYEsperarUrlContiene` | Lanza; el mensaje contiene `clics-efectivos.cero` y `sin-clic`, y **no** contiene `pista` | Sin clic no hay pista (prueba positiva más ausencia) |
| CT-07 | `deshabilitado` | `clickYObservarUrlContiene` | Resultado = `resultado.sin-clic`; el INFO contiene `clics-efectivos.cero` y no contiene `pista` | Lo mismo en la observación |
| CT-08 | `velado` | `click(By)` | Lanza `IllegalStateException`; el nombre simple de su causa es `causa-interceptada` y su mensaje lo contiene; contador = `clics-en-pagina.interceptado` | **P2:** una excepción del clic sale envuelta de la espera, sin contarse ni repetirse. Con el código de `4b91990` la excepción llega sin envolver y la prueba falla |

- **Una página inerte equivale, para `Navegador`, a un clic descartado por Chrome:** en los dos casos `click()` retorna sin excepción y la postcondición no llega. CT-04 y CT-05 prueban que el transporte emite la pista en ese caso. No reproducen el aviso de Chrome, que depende del servicio de Google (R-7). La E2E sin respaldo sigue siendo la última red (ADR-002, D8, *Límite*).
- **Ausencias con prueba positiva:** CT-06 y CT-07 afirman que la pista no está, pero solo después de afirmar un texto que sí debe estar. Si la captura o el mensaje vinieran vacíos, fallarían por la parte positiva. Es la lección de AC-COMPRA-09 (`MEMORY.md`).
- **Captura del INFO (CT-05, CT-07):** durante la llamada, la prueba sustituye `System.err` por un flujo en memoria y lo restaura en un `finally`. `slf4j-simple` escribe en el `System.err` vigente en cada mensaje (R-1). Si dejara de hacerlo, la captura quedaría vacía y la aserción positiva fallaría: falla cerrado.
- **Prohibido en estas pruebas:** `Thread.sleep` (CHK-01), reintentos (CHK-02), `@Disabled` y `Assumptions` (P-05; CHK-20 lo detecta como omitida), y medir tiempos.

### D5. Ejecución: Chrome en CHK-08 y Firefox en `e2e-firefox`; guarda CHK-20

| Dónde | Navegador | Cómo | Cambio |
|---|---|---|---|
| CHK-08 local y job `test` (paso *Run tests (headless Chrome)*) | Chrome headless | Include de Surefire (D1) | Ninguno en el comando |
| Job `e2e-firefox` (paso *Run E2E (headless Firefox)*) | Firefox headless | `-Dtest` pasa de `RunnerTest` a `RunnerTest` más el patrón de `com.demo.contract` (devops elige la sintaxis de Surefire) | El comando del paso y el comentario del job |
| Jenkins, etapa `Test` | Chrome | Es CHK-08 | Ninguno en el comando |
| Job `e2e-grid` | — | No corren: las páginas locales no existen en el contenedor (D3). Sigue con `-Dtest=RunnerTest` | Ninguno |
| Job `quarantine` | — | No corren: solo ejecuta `@quarantine` con `-Dtest=RunnerTest` | Ninguno |
| Local con snap | Firefox | `-Dbrowser=firefox -Dwebdriver.gecko.driver=/snap/bin/geckodriver`. El repositorio está bajo `$HOME`, que el snap puede leer; un temporal de `/tmp` no lo sería (snap tiene su propio `/tmp`) | — |

- **Coste:** unos 45–55 s por navegador. Lo dominan cuatro esperas completas (CT-04 a CT-07) de `explicit.wait.seconds` (10 s), más el arranque del navegador. Las demás pruebas tardan menos de un segundo. El engineer mide el tiempo real de la clase en el reporte de Surefire, en Chrome y en Firefox, y lo registra en el paso 3. No se acorta el plazo solo para estas pruebas: `TIEMPO_MAXIMO_ESPERA` es estático y compartido con la E2E, y una ejecución de Surefire aparte rompería los jobs con `-Dtest` (*Alternativas*).
- **CHK-20 (nueva; devops): las pruebas de contrato corrieron.** Por cada `*Test.java` versionado en `src/test/java/com/demo/contract`, su reporte `TEST-<clase>.xml` de Surefire existe y su `testsuite` tiene `tests` > 0 y `skipped`, `failures` y `errors` en 0.
  - Falla cerrado (1) si no hay ninguna clase versionada, si falta un reporte o un atributo, o si un valor no cumple. Imprime `<ruta>: CHK-20: <motivo>`.
  - Da 2 si no puede evaluar: argumentos de más o fallo de `git ls-files`.
  - **Motivo:** sin ella, un include borrado del `pom.xml`, un `-Dtest` mal escrito en `e2e-firefox` (Surefire no falla si otro patrón sí encuentra pruebas, R-8), un `@Disabled` o una clase renombrada dejan el job en verde sin ejecutar el contrato. Es la misma clase de fallo abierto que la guarda de PIT (`check-mutation-report.sh`) y que la línea `Tests run:` de `RunnerTest` en CHK-19.
  - Corre después de Maven en los jobs `test` y `e2e-firefox` y en la etapa `Test` de Jenkins, aunque Maven falle y sin tapar su rc (como CHK-19). Su autoprueba corre en el job `mutation` y en Jenkins, sin secrets ni navegador.
  - Sin awk, o con awk POSIX y la matriz de CHK-18.
  - **Autoprueba** (repositorio temporal fuera del repo): exit 0 con un reporte válido; exit 1 sin clases versionadas, sin reporte, con `tests="0"`, con `skipped="1"`, con `failures="1"`, con `errors="1"`, sin el atributo `tests` y con dos clases de las que falta un reporte; exit 2 con argumentos de más.

### D6. Controles negativos

**a) Del verifier, sin tocar código** (CHK-10 de contrato, texto para la Regla 04 en *Cambios propuestos*). Cada fila debe fallar con `AssertionFailedError` en las pruebas indicadas. Se usa `-D<clave>=__CONTROL_NEGATIVO__`, y en los contadores otro entero (`9`), porque `getNonNegativeInt` rechaza texto:

| Clave | Deben fallar |
|---|---|
| `contract.expected.clics-en-pagina` (`9`) | CT-01, CT-02, CT-03, CT-04, CT-05 |
| `contract.expected.clics-en-pagina.interceptado` (`9`) | CT-08 |
| `contract.expected.resultado.avanza` | CT-02 |
| `contract.expected.resultado.sin-efecto` | CT-05 |
| `contract.expected.resultado.sin-clic` | CT-07 |
| `contract.expected.clics-efectivos.uno` | CT-04, CT-05 |
| `contract.expected.clics-efectivos.cero` | CT-06, CT-07 |
| `contract.expected.sin-clic` | CT-06 |
| `contract.expected.pista` | CT-04, CT-05 (CT-06 y CT-07 siguen en verde: su aserción sobre la pista es de ausencia; las cubre el mutante MC-3) |
| `contract.expected.causa-interceptada` | CT-08 |

**b) Mutantes manuales del engineer** (cambio local, sin commit; se adjunta el comando, la prueba en rojo y su mensaje). Cada uno debe poner en rojo al menos las pruebas indicadas:

| ID | Mutante | Deben fallar |
|---|---|---|
| MC-1 | **Pista quitada** del mensaje de `clickHastaCumplir` | CT-04 |
| MC-2 | **Pista quitada** del INFO de `NO_AVANZO` | CT-05 |
| MC-3 | Pista también con 0 clics, en el mensaje y en el INFO | CT-06, CT-07 |
| MC-4 | **Arreglo deshecho:** `Navegador.java` de `4b91990` (sin `ClicNativoUnico`) | CT-08 (la causa llega sin envolver) |
| MC-5 | Guarda retirada: en el paso 3, el `if (clicsEfectivos.get() > 0)` de `clicNativoUnicoHastaCumplir`; desde el paso 4, el punto 2 de `sondear` | CT-04 (contador > 1); desde el paso 4, también UC-04 |
| MC-6 | `click(By)` con una postcondición siempre verdadera | CT-03 (contador 0) |
| MC-7 | **El P2 trasladado:** `sondear` cuenta antes de pulsar y no envuelve | UC-05, UC-06 |
| MC-8 | `requireNonNull` quitado del constructor | UC-10 |

**c) PIT** (CHK-11, que el verifier ejecuta por su cuenta): cada mutante de `ClicNativoUnico` muere o se justifica (D7).

### D7. PIT: sí en `ClicNativoUnico`; no en `Navegador` ni en las pruebas de contrato

- **`ClicNativoUnico`** entra sola en el alcance del ADR-001: `targetClasses` = `com.demo.*` sobre `target/classes` y `targetTests` con `com.demo.config.*Test`. No cambia la configuración de PIT ni su umbral.
- **`Navegador`, `DriverFactory` y las pruebas de contrato quedan fuera:**
  - `Navegador` y `DriverFactory` no pueden vivir en `src/main` (CHK-15; `selenium-java` es de alcance `test`, y cambiarlo exige un ADR por P-06), y PIT no muta `target/test-classes`;
  - mutar con las pruebas de contrato abriría un navegador por mutante y esperaría hasta 10 s en cada uno, y PIT clasifica un mutante que agota su tiempo como muerto (`TIMED_OUT`): el puntaje subiría sin que ninguna aserción lo detectara.
- **Guarda:** `excludedTestClasses` suma `com.demo.contract.*` (devops), para que un `-Dpit.targetTests` más amplio nunca las arrastre.
- **En su lugar:** los controles con `-D` del verifier y los mutantes manuales de D6.

### D8. CHK-17: reglas de `contract` y de sus páginas locales

Son comandos de CHK-17 porque reutilizan su ejecutor de dos pasadas con guardas, su autoprueba y sus pasos de CI (D6 del ADR-002). Se imprimen con la etiqueta de la regla de D7 del ADR-002 que amplían.

```bash
CT="$T/contract"
FX=src/test/resources/contract
RED='://|\b(?:base|remote)\.url\b'
FIX='\b(?:setTimeout|setInterval|requestAnimationFrame|requestIdleCallback|queueMicrotask|dispatchEvent|createEvent)\b|\bnew\s+\w*Event\s*\(|\.(?:click|submit|requestSubmit)\b|(?i:http-equiv\s*=\s*[\x22\x27]?refresh)'
# Cambian (D7-01 y D7-07 del ADR-002): contract sale de las búsquedas generales de Selenium y de JUnit
check R1 "Selenium fuera de transport, pages y contract" \
  'org\.openqa' -- src ":!$T/transport" ":!$T/pages" ":!$CT"
check R4 "JUnit fuera de steps, runners, contract y las pruebas unitarias" \
  'org\.junit' -- src ":!$T/steps" ":!$T/runners" ":!$T/config" ":!$T/data" ":!$CT"
# Nuevas (A4-*)
check R1 "en contract solo se permite 'import org.openqa.selenium.By;'" \
  'org\.openqa(?!\.selenium\.By;$)' -- "$CT"
check R4 "destino de red o URL del SUT en contract o en sus páginas locales" \
  "$RED" -- "$CT" "$FX"
check R5 "temporizador, evento sintético o navegación automática en una página local de contract" \
  "$FIX" -- "$FX"
check R6 "contract nombra un paquete fuera de su fila de D4" \
  'com\.demo\.(pages|actions|steps|hooks|runners|config|data)\b' -- "$CT"
check R6 "contract nombra utils distinto de ConfigReader" \
  'com\.demo\.utils\.(?!ConfigReader\b)' -- "$CT"
check R6 "un paquete distinto de contract nombra contract" \
  'com\.demo\.contract\b' -- src ":!$CT"
# Paso 5 (solo cuando contract exista en HEAD): presencia del directorio (D6 del ADR-002)
for dir in "$T/transport" "$T/pages" "$T/actions" "$T/steps" "$CT"; do …
```

| ID (autoprueba) | Regla | Ámbito | Motivo impreso |
|---|---|---|---|
| `D7-01` (cambia) | R1 | `src` menos `transport`, `pages` y `contract` | Selenium fuera de transport, pages y contract |
| `D7-07` (cambia) | R4 | `src` menos `steps`, `runners`, `config`, `data` y `contract` | JUnit fuera de steps, runners, contract y las pruebas unitarias |
| `A4-R1` | R1 | `contract` | en contract solo se permite 'import org.openqa.selenium.By;' |
| `A4-red` | R4 | `contract` y sus páginas | destino de red o URL del SUT en contract o en sus páginas locales |
| `A4-fix` | R5 | páginas de `contract` | temporizador, evento sintético o navegación automática en una página local de contract |
| `A4-R6` | R6 | `contract` | contract nombra un paquete fuera de su fila de D4 |
| `A4-R6u` | R6 | `contract` | contract nombra utils distinto de ConfigReader |
| `A4-R6in` | R6 | `src` menos `contract` | un paquete distinto de contract nombra contract |
| `A4-D6` (paso 5) | D6 | `contract` | directorio de capa sin archivos versionados |

Suma **6 comprobaciones** (las `A4-*` de `git grep`) a las 36 de `fe566e3` (parte 5 del ADR-002): **42**. `A4-D6` amplía la de directorios (`D7-20`) y no suma ninguna. Los IDs de autoprueba de este ADR llevan el prefijo `A4-` para no chocar con los `ok-41` y `ok-42` de esa parte 5. En el script, los comandos van agrupados por regla, en el orden del bloque de D7 del ADR-002 (parte 6), que es su transcripción normativa.

- **`RED`:** `://` cubre `http`, `https`, `ws` y cualquier otro esquema con autoridad; la prueba construye sus URL `file:` con `Path.toUri()` y nunca escribe un esquema. El `\b` inicial deja pasar `database.url`.
- **`FIX`:** `\.(?:click|submit|requestSubmit)\b` ve también `HTMLElement.prototype.click.call(…)`, y no ve el atributo `onclick` (no lleva `.` delante). `(?i:…)` ve `HTTP-EQUIV=Refresh` sin comillas.
- **`A4-R6in`** ve también el glue de Cucumber (`RunnerTest` está en `src`): las pruebas de contrato nunca pasan a ser glue.
- **Las demás reglas ya cubren `contract` sin cambios:** Cucumber (D7-08), `findElement(s)` y `executeScript` (D7-10) y secretos (D7-19) recorren `src` con exclusiones que no incluyen `contract`. `.expected` (D7-09) no lo recorre, a propósito: las pruebas de contrato leen claves `contract.expected.*`.
- **Falsos positivos, que fallan cerrado:** un comentario de `contract` con un esquema (`file://`) o con `base.url`; una página local que necesite un temporizador. Se reabre por enmienda; la regla no se relaja.

**Árbol base de la autoprueba** (paso 2). Suma dos archivos, para que `valido` dé 0 con las reglas nuevas y 1 si se quita una exclusión:

```text
// base: src/test/java/com/demo/contract/NavegadorContractTest.java
package com.demo.contract;

import org.openqa.selenium.By;
import org.junit.jupiter.api.Test;
import com.demo.transport.Navegador;
import com.demo.utils.ConfigReader;

class NavegadorContractTest {
    private static final By ACCION = By.id("accion");
    private final Navegador navegador = new Navegador();
    @Test
    void pulsaUnaVez() {
        navegador.click(ACCION);
    }
}
// base: src/test/resources/contract/inerte.html
<!DOCTYPE html>
<button id="accion" onclick="contar()">Accion</button>
<p id="clics">0</p>
<script>let clics = 0; function contar() { document.getElementById('clics').textContent = String(++clics); }</script>
```

**Casos.** Cada línea va en la línea 2 del archivo indicado, con `violation` o `allowed`, en sus dos modos. Los casos vigentes no cambian, salvo el motivo esperado de `D7-01`, `D7-01b`, `D7-01c` y `D7-07`, que pasa al nuevo texto:

```text
// A4-R1 (contract/Bad.java)
import org.openqa.selenium.WebDriver;
// A4-R1-b (contract/Bad.java)
import org.openqa.selenium.By; import java.util.List;
// A4-R1-c (contract/Bad.java)
        org.openqa.selenium.TimeoutException error = null;
// A4-R1-d (contract/Bad.java)
import static org.openqa.selenium.By.id;
// A4-red (contract/Bad.java)
        navegador.abrir("https://ejemplo.invalid/");
// A4-red-b (contract/Bad.java)
        navegador.abrir(ConfigReader.getRequired("base.url"));
// A4-red-c (contract/Bad.java)
        String grid = ConfigReader.getOptional("remote.url");
// A4-red-d (resources/contract/bad.html)
<img src="http://ejemplo.invalid/x.png" alt="">
// A4-red-e (resources/contract/bad.html)
<script>new WebSocket("ws://127.0.0.1:9");</script>
// A4-fix (resources/contract/bad.html)
<script>setTimeout(contar, 1000);</script>
// A4-fix-b
<script>setInterval(contar, 500);</script>
// A4-fix-c
<script>requestAnimationFrame(contar);</script>
// A4-fix-d
<script>boton.dispatchEvent(evento);</script>
// A4-fix-e
<script>const evento = new Event('click');</script>
// A4-fix-f
<body onload="document.getElementById('accion').click()">
// A4-fix-g
<script>document.forms[0].submit();</script>
// A4-fix-h
<meta http-equiv="refresh" content="1">
// A4-fix-i
<META HTTP-EQUIV=Refresh CONTENT=1>
// A4-fix-j
<script>requestIdleCallback(contar);</script>
// A4-fix-k
<script>queueMicrotask(contar);</script>
// A4-fix-l
<script>const evento = document.createEvent('MouseEvents');</script>
// A4-fix-m
<script>formulario.requestSubmit();</script>
// A4-fix-n
<script>HTMLElement.prototype.click.call(boton);</script>
// A4-R6-<paquete> (contract/Bad.java), uno por paquete: pages actions steps hooks runners config data
import com.demo.pages.X;
// A4-R6u (contract/Bad.java)
import com.demo.utils.TestContext;
// A4-R6u-b (contract/Bad.java)
import com.demo.utils.ConfigReaderX;
// A4-R6in (transport/Bad.java)
import com.demo.contract.X;
// A4-R6in-b (pages/BadPage.java)
import com.demo.contract.X;
// A4-R6in-c (runners/Bad.java)
@ConfigurationParameter(key = GLUE_PROPERTY_NAME, value = "com.demo.steps,com.demo.contract")
// A4-R6in-d (src/main/java/com/demo/config/Bad.java)
// Nombra com.demo.contract en un comentario (D6).
// A4-ok-1 (resources/contract/ok.html): onclick no es una llamada a click
<button id="accion" onclick="contar()">Accion</button>
// A4-ok-2 (resources/contract/ok.html): el \b final de FIX
<script>const nombre = 'setTimeoutX';</script>
// A4-ok-3 (resources/contract/ok.html): cambiar el fragmento no es navegación automática
<script>function avanzar() { location.hash = 'paso-siguiente'; }</script>
// A4-ok-4 (contract/Otro.java): las claves .expected se permiten en contract
        private static final String PISTA = "contract.expected.pista";
// A4-ok-5 (contract/Otro.java): el \b inicial de RED
        String clave = "contract.database.url";
// A4-ok-6 (steps/Otro.java): el \b de A4-R6in
import com.demo.contractual.X;
```

- Violaciones: 4 de `A4-R1`, 5 de `A4-red`, 14 de `A4-fix`, 7 de `A4-R6`, 2 de `A4-R6u` y 4 de `A4-R6in`: 36 casos, 72 ejecuciones. Permitidos: 6, 12 ejecuciones. El paso 2 suma **84** casos a los 432 de `fe566e3`: **516**, previstos. `A4-D6` suma uno en el paso 5 (`contract` en el lazo de `D7-20`): **517**. Si el ayudante de devops cuenta distinto, se informa el número real y no cambia el criterio.
- En `A4-red-d`, `A4-red-e` y `A4-fix*`, la línea 1 que escribe `violation` (`package com.demo.prueba;`) no afecta: ninguna regla la ve en una página.

**Mutantes** (devops los ejecuta todos; los de expresión se comprobaron aquí, ver *Control positivo*):

| Mutante | Lo mata |
|---|---|
| N1. `D7-01` sin `":!$CT"` | `valido` (import de `By` del árbol base) |
| N2. `D7-07` sin `":!$CT"` | `valido` (import de JUnit del árbol base) |
| N3. Sin `A4-R1` | `A4-R1` a `-d` |
| N4. `A4-R1` sin el `$` | `A4-R1-b` |
| N5. `A4-R1` con `(?!\.selenium\.By)` (sin `;$`) | `A4-R1-d` y `A4-R1-b` |
| N6. Sin `A4-red` | `A4-red` a `-e` |
| N7. `RED` sin `://` | `A4-red`, `-d` y `-e` |
| N8. `RED` sin `base` o sin `remote` | `A4-red-b` o `A4-red-c` |
| N9. `RED` sin el `\b` inicial | `A4-ok-5` |
| N10. `A4-red` sin `"$FX"` | `A4-red-d` y `-e` |
| N11. Sin `A4-fix` | `A4-fix` a `-n` |
| N12. `FIX` sin una de sus alternativas | su caso (`setTimeout` → `A4-fix`, …, `requestSubmit` → `A4-fix-m`) |
| N13. `FIX` con `\w+` en lugar de `\w*` | `A4-fix-e` |
| N14. `FIX` sin el `\b` final del primer grupo | `A4-ok-2` |
| N15. `FIX` sin `(?i:…)` | `A4-fix-i` |
| N16. `FIX` con `\s*\(` en lugar del `\b` tras `click` | `A4-fix-n` |
| N17. Sin `A4-R6`, o sin uno de sus paquetes | su caso `A4-R6-<paquete>` |
| N18. `A4-R6u` sin la búsqueda negativa | `valido` (import de `ConfigReader` del árbol base) |
| N19. Sin `A4-R6in` | `A4-R6in` a `-d` |
| N20. `A4-R6in` sin `":!$CT"` | `valido` (`package com.demo.contract;`) |
| N21. `A4-R6in` sobre `"$T"` en lugar de `src` | `A4-R6in-d` |
| N22. `A4-R6in` sin el `\b` | `A4-ok-6` |
| N23. `D7-09` con `"$CT"` entre sus rutas | `A4-ok-4` |
| N24 (paso 5). El lazo de directorios sin `"$CT"` | `A4-D6` |

**Control positivo** (arquitecto, 2026-10-13, B-01). Cada expresión y cada mutante de expresión se ejecutó con `git grep --untracked -nP` sobre este archivo (ruta `docs/adr`, nunca la raíz), con un filtro de líneas de código, y se leyó el número de línea contra los dos bloques de arriba:
- `A4-R1` encuentra los 4 casos `A4-R1*` y no el `import org.openqa.selenium.By;` del árbol base. `RED` encuentra los 5 `A4-red*`, y ninguna línea del árbol base, ni `A4-ok-4` ni `A4-ok-5`. `FIX` encuentra los 14 `A4-fix*`, y no las líneas de la página base, ni `A4-ok-1`, `A4-ok-2`, `A4-ok-3`, `A4-red-d` ni `A4-red-e`. `A4-R6u` encuentra `A4-R6u` y `-b`. `A4-R6in` encuentra los 4 `A4-R6in*` y el `package com.demo.contract;` del árbol base (que el script excluye por ruta: es lo que mata N20), y no `A4-ok-6`.
- **Mutantes de expresión:** N4 pierde `A4-R1-b`; N5 pierde `A4-R1-b` y `-d`; N7 pierde `A4-red`, `-d` y `-e`; N8 pierde `A4-red-b` (sin `base`) o `-c` (sin `remote`); N9 suma `A4-ok-5`; N12, probado sin `dispatchEvent`, pierde `A4-fix-d`; N13 pierde `A4-fix-e`; N14 suma `A4-ok-2`; N15 pierde `A4-fix-i`; N16 pierde `A4-fix-n`; N22 suma `A4-ok-6`.
- **Sobre `4b91990`** (`git grep -nP … HEAD`): `D7-01` y `D7-07` con la exclusión nueva y `A4-R6in` dan rc=1 sin salida; `RED` sobre las rutas de `contract`, que aún no existen, da rc=1 sin stderr (directorios sin `/` final; ADR-002, D7, *Conteo y presencia*). Por eso el paso 2 deja CHK-17 en 0.
- **Límite de PCRE:** `RED` y `FIX` recorren con `git grep -lP` los archivos versionados de `src`, `scripts`, `docs` y `.github` en `4b91990` sin texto en stderr.
- Los mutantes de cableado (N1–N3, N6, N10, N11, N17–N21, N23, N24) los ejecuta devops: B-01 no permite correr el script.

## Alternativas consideradas

**Dónde viven las pruebas del transporte (D1):**

| Alternativa | Motivo del descarte |
|---|---|
| En `src/test/java/com/demo/transport`, mismo paquete que `Navegador` | Necesita tres excepciones: R4 (JUnit en `transport`), `R5-clic` y `R5-clic-max` (`navegador.click(` coincide con `CLIC`). Además invita a probar miembros de paquete en lugar del contrato público. Sería relajar reglas para que el cambio pase |
| En `src/test/java/com/demo/config` o `data` | CHK-16 prohíbe Selenium y `com.demo.transport` ahí, y PIT abriría un navegador por mutante |
| Como feature de Cucumber | Las features describen el SUT (SDD-07) y exigen spec aprobada (CHK-12); CHK-04 prohíbe "clic" y "botón". Una página local no es el SUT |
| Módulo Maven aparte, otro *source set* (`build-helper`) o Failsafe | Plugin o estructura nuevos (P-06), y un segundo módulo activa el disparador de ArchUnit (ADR-002, D6) |
| Un `WebDriver` falso (Mockito o `java.lang.reflect.Proxy`) | Mockito es una dependencia nueva (P-06; el ADR-001 ya lo descartó). Un `Proxy` tendría que vivir donde se permite Selenium con JUnit, y `Navegador` necesitaría un constructor para recibir el driver: API nueva solo para pruebas. Además verifica secuencias de llamadas, no el navegador (ADR-002, *Alternativas*) |
| Un paquete propio sin `By`, a través de una página de prueba en `pages` | Mete en `pages` una página que no es del SUT, y esa capa la consumen las acciones |

**El P2 (D2):**

| Alternativa | Motivo del descarte |
|---|---|
| Contar después de `click()`, sin envolver | Con una excepción ignorada, el contador queda en 0 y la espera vuelve a pulsar si el control sigue clicable: un segundo clic, contra D1, aunque CHK-17 solo vea una línea |
| Envolver solo las excepciones que la espera ignora | Depende de la lista de `WebDriverWait`: si alguien agrega `ignoring(StaleElementReferenceException)`, el hueco vuelve. Y no se puede probar sin Selenium |
| El mismo arreglo, pero en `Navegador` y sin clase nueva | El camino defectuoso no se reproduce con un navegador real (*Contexto*): el arreglo quedaría protegido solo por la revisión. Es la opción F de la parte 4 con su disparador cumplido y su objeción cerrada por D1 |
| Una espera que no ignore `NotFoundException` para los clics | Las postcondiciones (`textToBePresentInElementLocated`, `visibilityOfElementLocated`) dependen de ignorar `NoSuchElementException`: una ausencia transitoria pasaría a ser un fallo inmediato |
| Repetir el clic una vez si lanza | Contradice D1 (un clic nativo por acción) y CHK-02 |
| Demostrarlo con una página cuyo botón se elimina al pulsarlo | `click()` retorna porque el evento ya se entregó: ejercita el camino correcto, no el defectuoso (*Contexto*) |

**Páginas locales (D3):**

| Alternativa | Motivo del descarte |
|---|---|
| URL `data:` con el HTML | La URL contiene el código de la página: `urlContiene("paso-siguiente")` daría verdadero si el texto aparece en el script, así que una postcondición de URL probaría el texto de la página y no la navegación (verde falso por construcción). Firefox restringe la navegación de nivel superior a `data:`, y el contenido iría codificado (en base64 sería una señal de la Regla 03). A cambio funcionaría en el Grid, que aquí no se necesita |
| Servidor HTTP local (`com.sun.net.httpserver`) | Es red en *loopback*, fuera de lo que admite P-07, con gestión de puertos y más código, y el Grid tampoco lo vería |
| HTML en bloques de texto de Java, escrito en un temporal (`@TempDir`) | Firefox de snap no ve el `/tmp` del sistema, y el HTML queda escondido en cadenas. Su única ventaja (no tocar la Regla 02) no compensa |
| `about:blank` más DOM inyectado con `executeScript` | R5 lo prohíbe fuera de `transport`, la lista cerrada `JS_LISTA` no lo admite y amplía la superficie de PI-05 |

**Ejecución (D5):**

| Alternativa | Motivo del descarte |
|---|---|
| Una ejecución de Surefire aparte, con un plazo corto | `-Dtest=RunnerTest` (jobs `e2e-firefox`, `e2e-grid` y `quarantine`) se aplica a cada ejecución, y la que no encuentra pruebas falla, salvo con `-Dsurefire.failIfNoSpecifiedTests=false`, que el CI evita a propósito (comentario del job `e2e-firefox`) |
| Acortar el plazo solo para estas pruebas | `TIEMPO_MAXIMO_ESPERA` es estático y compartido; cambiarlo en ejecución es estado global mutable, y un constructor con plazo sería API solo para pruebas |
| Ejecutar las pruebas de contrato en paralelo (JUnit) | Ahorra unos 20 s a cambio de un navegador por prueba y de configurar el paralelismo de Jupiter junto al de Cucumber. Se reabre si el coste supera 2 min (R-6) |
| Correrlas también en el Grid | Las páginas locales no existen en el contenedor (D3) |
| Sin CHK-20, confiando en el include y en la revisión | Un include o un `-Dtest` roto deja el contrato sin ejecutar con el job en verde |

## Consecuencias

- **Positivas:**
  - El pendiente 1 queda observado en Chrome y en Firefox, de forma determinista y sin red: la pista de D8 en el mensaje (CT-04) y en el INFO de `NO_AVANZO` (CT-05), y su ausencia sin clic (CT-06, CT-07).
  - El P2 queda corregido y demostrado: por mutación y pruebas unitarias (UC-05, UC-06) y, en un navegador real, por CT-08.
  - El *Riesgo residual* de la guarda del ADR-002 (parte 4) se cierra dos veces: PIT sobre `sondear` y CT-04, que cuenta los clics en la página.
  - `click(By)` deja de ser un caso aparte: misma lógica y mismo fallo que los demás clics.
- **Costes:**
  - Un paquete de prueba nuevo, 4 páginas locales, 10 claves, una clase de `src/main` y unas 10 pruebas unitarias y 8 de contrato.
  - Unos 45–55 s por navegador en CHK-08, en el job `test` y en `e2e-firefox`.
  - CHK-17: 6 comprobaciones nuevas (42) y 2 cambiadas, y 85 casos más en la autoprueba (517). Una CHK nueva (CHK-20) con script, autoprueba y pasos de CI.
  - Textos de reglas y agentes que solo puede aplicar el usuario, y el comando del Grid de `README.md` (pasa a `-Dtest=RunnerTest`).
- **Sin cambios:** specs, features, páginas, acciones, steps, hooks, la API pública de `Navegador` (salvo el tipo de excepción de un clic que lanza, D2), los textos de sus mensajes, el umbral y la configuración de PIT (salvo `excludedTestClasses`), CHK-15 y CHK-16.

## Cambios propuestos a reglas, agentes y documentación

Los aplica el usuario (P-01, PI-07). **Grupo A** antes del paso 3: el engineer escribe las páginas y el verifier hace el control negativo de las pruebas nuevas. **Grupo B** con el paso 5: CHK-20 y la presencia de `contract` ya existen. Hasta entonces, la definición normativa de las reglas nuevas es D8 de este ADR, transcrita en D7 del ADR-002 por la enmienda del paso 1.

**Estado (2026-10-13):** el grupo A está aplicado en `d5b18ef`. La parte 5 del ADR-002 (`fe566e3`) cambia dos de estas filas: R5 del arquitecto y CHK-17 de la Regla 04.
- La fila CHK-17 del grupo B ya combina las dos.
- La fila R5 aplicada en `d5b18ef` no lleva la escritura única. Su texto combinado está en el ADR-002, *Enmiendas*, parte 6, *Reglas y agentes*.

**Grupo A**

- `.claude/rules/02-agent-permissions.md`, fila de `qa-automation-engineer` de la matriz:

  ```markdown
  | `qa-automation-engineer` | `src/test/java/`, `src/main/java/` (lógica pura, ADR-001), `src/test/resources/config.properties`, `src/test/resources/contract/` (páginas locales de las pruebas de contrato del transporte, ADR-004), `.env.example` | `docs/` | `./mvnw` y `git grep`/`git status`/`git diff` |
  ```

- `.claude/rules/01-spec-driven-development.md`, fila SDD-02:

  ```markdown
  | SDD-02 | Sin feature no hay step; sin step no hay acción ni página nueva. No se escribe código especulativo. Las pruebas del framework (unitarias, y de contrato del transporte contra páginas locales, ADR-004) no requieren spec: las origina un ADR, y un ADR puede originarse en una CHK. |
  ```

- `.claude/agents/qa-automation-architect.md`, fila 5 de *Arquitectura objetivo*:

  ```markdown
  | 5 | Orquestación, reporte y contrato del transporte (pruebas JUnit de `Navegador` contra páginas locales, ADR-004) | `com.demo.runners`, `com.demo.hooks`, `com.demo.contract` | 1, 4 (`contract`: solo `transport` y `ConfigReader`) |
  ```

- El mismo archivo, filas R1, R4, R5 y R6:

  ```markdown
  | R1 | Selenium fuera de `transport`; en `pages` y `contract`, todo lo que no sea `import org.openqa.selenium.By;` (excepción permanente; `contract`, ADR-004); en `transport`, tipos de Selenium importados o calificados en firmas expuestas (`By`, solo como parámetro), heredar o implementar un tipo de Selenium e imports de Selenium con comodín; `By` en firmas expuestas de páginas; interfaces, anotaciones o records expuestos en `transport` o `pages`. "Expuesta" = pública o protegida, con anotaciones y modificadores en cualquier orden (ADR-002, D7, *Firmas expuestas* y *Selenium en el transporte y herencia*) |
  | R4 | JUnit fuera de `steps`, `runners`, `contract` y las unitarias; Cucumber fuera de `steps`, `hooks` y `runners`; claves `*.expected*` en `transport`, `pages` o `actions`; destinos de red o `base.url`/`remote.url` en `contract` o en sus páginas locales (ADR-004) |
  | R5 | `findElement(s)`, `executeScript` o `executeAsyncScript` fuera de `transport`; en `transport`, `executeScript` fuera de la lista cerrada de scripts, `executeAsyncScript`, un clic distinto de `elemento.click();` o más de uno, y eventos sintéticos u otras vías de entrada (teclado, envío de formularios, `Actions`, CDP y BiDi) (ADR-002, D7, *Clic nativo único, scripts cerrados y preferencias de Chrome*); clases de `transport`, `pages`, `actions` o `utils` que extienden otra; temporizadores, eventos sintéticos, envíos o recargas automáticas en las páginas locales de `contract` (ADR-004) |
  | R6 | Nombrar un paquete fuera de su fila del grafo de dependencias (ADR-002, D4; `contract`, ADR-004, D1), o nombrar `contract` desde otro paquete; secretos fuera de `utils` y `steps`; `ResultadoClic` en un miembro expuesto (público o protegido) de una página (ADR-002, D1) |
  ```

- `.claude/rules/04-quality-checks.md`, fila CHK-10:

  ```markdown
  | CHK-10 | Control negativo | **Falla** con `AssertionFailedError` en el `Then` o, en las pruebas de contrato del transporte (ADR-004), en la prueba indicada | verifier |
  ```

- El mismo archivo, en el bloque de comandos, después de CHK-10:

  ```bash
  # CHK-10, pruebas de contrato del transporte (ADR-004, D6): la clave sale del esperado que verifica la prueba; en los contadores, otro entero
  ./mvnw -B -ntp test -Dheadless=true -Dtest='NavegadorContractTest' -D<contract.expected.clave>=__CONTROL_NEGATIVO__
  ```

- `.claude/agents/qa-test-verifier.md`, punto 7 del *Procedimiento*:

  ```markdown
  7. **Control negativo** (CHK-10) por cada escenario nuevo y por cada prueba de contrato del transporte nueva o tocada (ADR-004, D6, con su clave `contract.expected.*`): debe fallar en el `Then` o en la prueba. Si pasa, o si el esperado está fijo en el código y no puede corromperse → **RECHAZO**.
  ```

**Grupo B**

- `.claude/rules/04-quality-checks.md`, fila CHK-17 (sustituye a la actual; incluye la escritura única de la parte 5 del ADR-002):

  ```markdown
  | CHK-17 | Capas (ADR-002): R1–R6 de D7, incluidas páginas como parámetro en acciones y `ResultadoClic` en miembros expuestos de páginas; las firmas expuestas incluyen anotaciones, cualquier orden de modificadores y `protected`, y en `transport`, `pages` y `actions` no hay interfaces, anotaciones ni records expuestos (D7, *Firmas expuestas*); en `transport`, ningún tipo de Selenium importado o calificado en firmas expuestas ni en la herencia, `By` solo como parámetro y sin comodines de Selenium, y `transport`, `actions` y `utils` no extienden clases (D7, *Selenium en el transporte y herencia*); en `transport`, `executeScript` solo con la lista cerrada de scripts, un único clic nativo (`elemento.click();`), una única escritura nativa (`elemento.sendKeys(texto);`) y ningún evento sintético ni otra vía de entrada, y `DriverFactory` aplica las preferencias de Chrome de `BrowserSettings` (D7, *Clic nativo único, scripts cerrados y preferencias de Chrome* y *Escritura única*); `contract` (ADR-004, D8) solo importa `By` de Selenium y usa JUnit, nombra solo `transport` y `ConfigReader` y nadie la nombra; ni su código ni sus páginas locales llevan destinos de red, `base.url` ni `remote.url`, y sus páginas no tienen temporizadores, eventos sintéticos, envíos ni recargas automáticas; falla cerrado (directorios de capa, incluido `contract`, `git grep` con rc ≥ 2 o con stderr, awk de la unión con rc ≠ 0, regla de presencia sin coincidencias o sin su archivo) | Exit 0 en el script y en su autoprueba | engineer, verifier, devops |
  ```

- El mismo archivo, fila nueva tras CHK-19:

  ```markdown
  | CHK-20 | Pruebas de contrato del transporte ejecutadas (ADR-004, D5): por cada `*Test.java` versionado en `src/test/java/com/demo/contract`, su reporte de Surefire existe con `tests` > 0 y `skipped`, `failures` y `errors` en 0; falla cerrado si no hay ninguno versionado o falta un reporte o un atributo | Exit 0 en el control y en su autoprueba; con exit 1 imprime `ruta: CHK-20: motivo` | devops |
  ```

- El mismo archivo, al final del bloque de comandos:

  ```bash
  # CHK-20 (ADR-004, D5): autoprueba y control sobre los reportes de una ejecución que incluye las pruebas de contrato
  bash scripts/tests/check-contract-ran-test.sh
  bash scripts/check-contract-ran.sh target/surefire-reports
  ```

- `.claude/agents/qa-automation-engineer.md`, puntos 7 y 8 del *Procedimiento*:

  ```markdown
  7. **Pruebas unitarias** para la lógica propia (`ConfigReader`, `SecretReader`, fábricas, `ClicNativoUnico`), con valores concretos y fronteras. Son la base de CHK-11. Las **pruebas de contrato del transporte** (`com.demo.contract`, ADR-004) usan solo la API pública de `Navegador`, páginas locales estáticas de `src/test/resources/contract/` y esperados `contract.expected.*`.
  8. Autoverificación: CHK-01, CHK-03, CHK-07, CHK-08, CHK-09 de cada escenario nuevo y CHK-17 (`bash scripts/check-layers.sh`). Si tocas `transport`, `ClicNativoUnico` o `src/test/resources/contract/`: las pruebas de contrato en Chrome y en Firefox (`-Dbrowser=firefox`) y CHK-20 sobre los reportes de CHK-08.
  ```

- `.claude/agents/devops-engineer.md`, fila CHK-11 de la tabla de configuración: `excludedTestClasses` = `com.demo.runners.*`, `com.demo.contract.*` (ADR-004, D7). Puntos 3 y 6 del gate:

  ```markdown
  3. CHK-05, CHK-06, CHK-01, CHK-02 → sin salida; CHK-17 → `bash scripts/check-layers.sh` y `bash scripts/tests/check-layers-test.sh` en 0; CHK-18 → el control estático, sus dos autopruebas y la matriz con `--require mawk --require gawk --require gawk-posix` en 0 (si falta gawk en local, RECHAZADO hasta que el usuario lo instale); CHK-19 → `bash scripts/tests/check-no-expected-override-test.sh` en 0; CHK-20 → `bash scripts/tests/check-contract-ran-test.sh` en 0. Los workflows (`.github/**`) se editan solo con `Edit`/`Write`: el hook bloquea cualquier escritura por `Bash`.
  6. CHK-08 **dos veces** → ambas `BUILD SUCCESS` con el mismo `Tests run`. Si difieren, es inestabilidad: RECHAZADO. Cada ejecución con `| tee` y `pipefail`, y CHK-19 sobre su log → `bash scripts/check-no-expected-override.sh <log>` en 0, y CHK-20 sobre sus reportes → `bash scripts/check-contract-ran.sh target/surefire-reports` en 0.
  ```

- **Sin dueño en la matriz** (el usuario designa quién lo edita, como en el ADR-002): `README.md` (estructura con `contract/` y `src/test/resources/contract/`, CHK-20, el comando del Grid local con `-Dtest=RunnerTest` porque las páginas locales no existen en el contenedor, y el tiempo añadido) y `AGENTS.md` (estructura y comandos). `MEMORY.md` lo actualiza el coordinador al cerrar.
- La línea *Estado actual* de la Regla 04 suma CHK-20 cuando esté en CI (texto final según el commit de devops).

## Plan de implementación

Cada paso deja la suite en verde. Cada paso del engineer pasa por el verifier y por el gate antes del siguiente (`CLAUDE.md`, *Coordinación*).

| Paso | Dueño | Qué | Verde si | Estado |
|---|---|---|---|---|
| 0 | Coordinador y usuario | El coordinador aprueba este ADR; el usuario aplica el grupo A antes del paso 3 | — | Hecho (aprobado el 2026-10-13; grupo A en `d5b18ef`) |
| 1 | `qa-automation-architect` | Enmienda del ADR-002: fila de `contract` en D4 y, en D7, el bloque de D8 de este ADR con referencia (D6 del ADR-002 exige enmendar D7 en el mismo cambio que el script) | El coordinador la aprueba | Redactada el 2026-10-13 sobre `fe566e3` (ADR-002, *Enmiendas*, parte 6); se integra en el commit del paso 2 |
| 2 | `devops-engineer` | En **un commit** con la enmienda del paso 1: CHK-17 sin `A4-D6` (D8), la autoprueba con el árbol base y los casos, y en `pom.xml` el include de Surefire y `excludedTestClasses` | `bash scripts/check-layers.sh` da 0 sobre HEAD (aún no hay `contract`); autoprueba en 0 con 516 casos (432 + 84, D8) en la matriz de CHK-18; N1–N23 mueren; CHK-08 ×2 con el mismo `Tests run` que antes (el include no encuentra nada); CHK-13 | Pendiente |
| 3 | `qa-automation-engineer` | `com.demo.contract` con CT-01 a CT-07, las cuatro páginas y las 10 claves. **Cierra el pendiente 1** | CHK-01, 03, 07 y 17; CHK-08 ×2 (`Tests run` + 7); cada CT sola (`-Dtest=…#método`); las 7 en Firefox local; tiempo de la clase en los dos navegadores; MC-1, MC-2, MC-3, MC-5 (sobre la guarda de `clicNativoUnicoHastaCumplir`) y MC-6 en rojo; las filas de D6 a) de CT-01 a CT-07 en rojo | Pendiente |
| 4 | `qa-automation-engineer` | `ClicNativoUnico` y sus pruebas (UC-01 a UC-10), el cableado de `Navegador` y CT-08. **Cierra el P2.** Gate CRÍTICO (`src/main/java/com/demo/config/` y `transport`) | CT-08 en rojo con el `Navegador` anterior y en verde después; CHK-01, 03, 07, 15, 16 y 17; CHK-08 ×2; CHK-11 ≥ 80 % con la guarda en 0 y `ClicNativoUnico` sin sobrevivientes sin justificar; D6 del ADR-001 sigue en `BUILD FAILURE`; MC-4, MC-5 (sobre `sondear`), MC-7 y MC-8 en rojo; CHK-09 y CHK-10 de `@AC-LOGIN-01` (`click(By)`) y de `@AC-COMPRA-03` (tramitar) | Pendiente |
| 5 | `devops-engineer` | `A4-D6` y su caso (517), y en el bloque de D7 del ADR-002 la línea de directorios con `"$CT"`, sin el comentario provisional; CHK-20 con su autoprueba; jobs `test` y `e2e-firefox` (CHK-20 y el `-Dtest` de Firefox), `mutation` (autoprueba de CHK-20) y Jenkins (`Test` y la autoprueba) | CHK-17 y su autoprueba en 0; N24 muere; CHK-20 en 0 sobre un CHK-08 real y en 1 con el include quitado (control negativo local, sin commit); autoprueba de CHK-20 en 0; CHK-13; `e2e-firefox` en verde con el contrato en su reporte (según el usuario) | Pendiente |
| 6 | Usuario | Grupo B; `README.md` y `AGENTS.md` (quien designe) | — | Pendiente |
| 7 | `qa-test-verifier` | *Criterio de verificación* completo | APROBADO | Pendiente |

## Criterio de verificación

```bash
# Capas y su autoprueba (pasos 2 a 5)
bash scripts/check-layers.sh
bash scripts/run-with-each-awk.sh --require mawk --require gawk --require gawk-posix -- bash scripts/tests/check-layers-test.sh
# Pureza de src/main y aislamiento de las unitarias (paso 4)
bash scripts/check-unit-purity.sh
# CHK-08 dos veces, con tee; CHK-19 sobre el log y, desde el paso 5, CHK-20 sobre los reportes
bash -c 'set -o pipefail; ./mvnw -B -ntp clean test -Dheadless=true -Dcucumber.filter.tags="not @quarantine" 2>&1 | tee test.log'
bash scripts/check-no-expected-override.sh test.log
bash scripts/check-contract-ran.sh target/surefire-reports
# Contrato en Firefox (en local con snap, más -Dwebdriver.gecko.driver=/snap/bin/geckodriver)
./mvnw -B -ntp test -Dheadless=true -Dbrowser=firefox -Dtest='NavegadorContractTest'
# Independencia: cada prueba de contrato sola
./mvnw -B -ntp test -Dheadless=true -Dtest='NavegadorContractTest#<método>'
# CHK-10 de contrato: una ejecución por fila de D6 a); debe fallar con AssertionFailedError en las pruebas indicadas
./mvnw -B -ntp test -Dheadless=true -Dtest='NavegadorContractTest' -Dcontract.expected.pista=__CONTROL_NEGATIVO__
# CHK-11 (paso 4), con ClicNativoUnico en el reporte
rm -rf target/pit-reports
bash -c 'set -o pipefail; ./mvnw -B -ntp test-compile org.pitest:pitest-maven:mutationCoverage 2>&1 | tee pit.log' && bash scripts/check-mutation-report.sh pit.log
# Paso 4: Navegador ya no cuenta clics por su cuenta (sin salida)
git grep -nE 'AtomicInteger clicsEfectivos|clicsEfectivos\.incrementAndGet' -- src/test/java/com/demo/transport
# Paso 4: una sola línea de clic, la exacta (una línea)
git grep -n 'elemento\.click();' -- src/test/java/com/demo/transport
```

**Para el engineer (pasos 3 y 4):** las comprobaciones de su fila del plan; la evidencia de cada mutante MC-* (comando, prueba en rojo y mensaje), y el tiempo de `NavegadorContractTest` en Chrome y en Firefox.

**Para el verifier:**
- Lee las páginas locales: estáticas, sin texto dirigido a agentes (Regla 03) y con el contador de clics como único estado.
- Ejecuta las filas de D6 a) y CHK-11 por su cuenta; los mutantes MC-* los revisa en la evidencia del engineer, porque no edita código.
- Comprueba que CT-06 y CT-07 afirman un texto presente antes de la ausencia, y que CT-01 y CT-02 tienen la precondición de la URL.
- Comprueba que el `Navegador` del paso 4 conserva los textos de mensaje e INFO del paso 3 (las mismas claves pasan sin cambios).

**Para devops:** la tabla de mutantes N1–N24 con los casos que pone en rojo cada uno, sin sobrevivientes, y el control negativo de CHK-20.

## Riesgos

Este ADR se escribió sin ejecutar nada fuera de B-01: solo se leyeron archivos y se buscó con `git grep`.

| # | Supuesto | Lo confirma | Si es falso |
|---|---|---|---|
| R-1 | `slf4j-simple` (2.0.16) escribe en el `System.err` vigente en cada mensaje (su configuración por defecto no fija el flujo) y su nivel por defecto es INFO | Engineer, paso 3: CT-05 y CT-07 en verde, y MC-2 en rojo | La captura queda vacía y CT-05 y CT-07 fallan por su aserción positiva (falla cerrado). Se cambia la captura por enmienda |
| R-2 | Chrome y Firefox headless abren `file:` desde `target/test-classes` y siguen el cambio de fragmento; Firefox de snap lee el repositorio bajo `$HOME` | Engineer, paso 3, en local (Chrome y Firefox de snap); devops, paso 5, job `e2e-firefox` | CT-01 a CT-03 fallan en el navegador afectado. Se reabre D3 por enmienda |
| R-3 | Chromedriver y geckodriver rechazan el clic sobre un control tapado con `element click intercepted`, que Selenium Java traduce a `ElementClickInterceptedException` | Engineer, pasos 4 y 5, en los dos navegadores | CT-08 falla cerrado con otra causa. Se corrige el esperado `contract.expected.causa-interceptada` o la página `velado`, por enmienda |
| R-4 | `WebDriverWait` ignora `NotFoundException` y nunca `IllegalStateException` | API de Selenium 4. CT-08 lo confirma en integración: la causa llega envuelta, al instante y sin clic | Si la espera ignorara `IllegalStateException`, UC-06 sigue garantizando el fallo cerrado de `click(By)` |
| R-5 | JUnit Platform ejecuta los motores uno tras otro, así que el navegador del contrato no coincide con los 2 de Cucumber | Engineer y devops: CHK-08 ×2 estable | Tres navegadores a la vez en CI; se observa la estabilidad y, si hace falta, se reabre D5 |
| R-6 | El coste es de unos 45–55 s por navegador | Engineer, paso 3 (tiempo en el reporte de Surefire) | Si supera 2 min por navegador, se reabre el paralelismo de JUnit (*Alternativas*) |
| R-7 | Una página inerte equivale, para `Navegador`, al clic que Chrome descarta con su aviso | Por construcción: en los dos casos `click()` retorna y la postcondición no llega | Ninguna prueba del proyecto puede reproducir el aviso sin el servicio de Google. Sigue como límite aceptado (ADR-002, D8, *Límite*) |
| R-8 | Con dos patrones en `-Dtest`, Surefire no falla si uno no encuentra nada | Documentación de Surefire (`failIfNoSpecifiedTests` mira el total) | Si fallara, CHK-20 sobraría en `e2e-firefox` pero seguiría cubriendo el job `test` |

## Enmiendas

Ninguna.
