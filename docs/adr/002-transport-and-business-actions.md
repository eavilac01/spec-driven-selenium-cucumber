# ADR-002 — Capa de transporte, acciones de negocio y comprobación de capas (CHK-17)

- **Estado:** Aceptado (ADR y cambios a reglas y agentes aprobados por el usuario, 2026-10-09)
- **Fecha:** 2026-10-09
- **Autor:** `qa-automation-architect`
- **Aprueba:** coordinador (Regla 01, nivel 2). Los cambios a reglas, agentes y `AGENTS.md` los aprueba y aplica el usuario (P-01, PI-07).
- **Hereda del ADR-001:** la ubicación final de las fachadas de `com.demo.utils` (D5), la reevaluación de `DriverFactory` frente a una configuración de navegador pura (D8) y ArchUnit (D6).

## Contexto

**Terminología.** Este ADR usa las *capas* de `.claude/agents/qa-automation-architect.md:28-34`: 1 transporte, 2 páginas, 3 acciones y steps, 4 datos y ambientes, 5 orquestación. La Regla 01 numera *niveles* de artefactos SDD (`01-spec-driven-development.md:12-13`), donde el nivel 4 agrupa acciones, steps, `config` y `data`, y el nivel 5 páginas y transporte. Son clasificaciones distintas: aquí "capa N" es siempre la del arquitecto.

**Escala.** Hay 5 escenarios E2E, 4 páginas, 2 clases de steps y unas 650 líneas entre `pages`, `steps`, `hooks` y `utils`. Quedan 15 AC sin cubrir a la espera de las Q-* (AC-LOGIN-04…09 y AC-COMPRA-05…13), que reutilizan casi por completo los flujos actuales.

| Hecho | Evidencia | Consecuencia |
|---|---|---|
| `BasePage` ya concentra la sincronización | Esperas `BasePage.java:43-70`, `:127-156`; clic con postcondición y respaldo JS `:72-94`; escritura estable `:96-125`; único `findElements` del repo `:129` | Es un transporte de hecho, y R5 se cumple hoy |
| …pero entrega el `WebDriver` a cada página | `protected final WebDriver driver` `:33`; constructores con `WebDriver` en `LoginPage.java:15`, `InventoryPage.java:17`, `CartPage.java:19` y `CheckoutPage.java:17` | Cualquier página puede llamar a `driver.findElement` y saltarse la espera, así que R5 depende de la revisión. Es la deuda de `.claude/agents/README.md:52` |
| `WebElement` sale de la clase base | `BasePage.java:43`, `:141` lo devuelven; `CartPage.java:7`, `:35` usa `WebElement::getText` | Las páginas manipulan elementos |
| `executeScript` (superficie de PI-05) | `BasePage.java:91`, `:119`, `:151` | Hoy está en un solo archivo, pero ninguna regla lo mantiene así |
| Selenium en 8 archivos de 3 paquetes | `pages` (5), `utils/DriverFactory.java:8-13`, `utils/TestContext.java:5`, `hooks/Hooks.java:3-4` | R1 (`qa-automation-architect.md:48`) solo exceptúa `pages`; `utils` y `hooks` la incumplen hoy |
| Dos dueños del mismo `WebDriver` | `ThreadLocal` en `DriverFactory.java:17`, `:25-67`; copia en `TestContext.java:9`, `:12-21`, asignada en `Hooks.java:26-27` | PicoContainer ya crea un grafo por escenario (`README.md:150-152`) |
| `PageManager` crea páginas de forma perezosa | `PageManager.java:18-48` | Existe porque el driver se asigna en `@Before`, después de construir los steps |
| Los steps hablan con las páginas | `CompraSteps.java:6`, `:21`, `:30-35`, `:43`, `:50`, `:57`, `:63-66`, `:72-77`, `:84`; `LoginSteps.java:6`, `:16`, `:24`, `:30`, `:36-38`, `:45`, `:52`, `:56` | Los steps conocen el orden de páginas de cada flujo |
| Flujo duplicado | Autenticación en `CompraSteps.java:30-36` y en `LoginSteps.java:24`, `:29-30`, `:44-46` | Un cambio en el inicio de sesión toca dos clases de steps |
| CHK-03 es textual y estrecha | `04-quality-checks.md:32` busca `import org.openqa.selenium` | No detecta `import static org.openqa…` ni nombres calificados |
| La inyección transitiva ya funciona | `TestContext` y `PageManager` no son glue (`RunnerTest.java:15`), y Pico los construye para `Hooks.java:20`, `LoginSteps.java:18`, `CompraSteps.java:23` y `PageManager.java:18` | Acciones, páginas y transporte se inyectan igual, sin tocar el glue |
| La configuración del navegador no se ejercita en CI | CI solo corre Chrome local headless (paso *Run tests (headless Chrome)* del job `test`, `ci.yml:48` en `90687f4`; `config.properties:3`, `:5`). *(Estado al 2026-10-09; R-6 lo cerró con los jobs `e2e-firefox` y `e2e-grid`.)* No se ejercitan Firefox (`DriverFactory.java:38`, `:85-97`), Grid (`:80-81`, `:94-95`, `:103-110`) ni el tamaño de ventana (`:72-77`, `:88-91`) | Un defecto en esas ramas pasa inadvertido para la suite (criterio D1(b) del ADR-001) |
| Hoy no hay ciclos | `steps` → `pages`, `utils`, `data`; `pages` → `utils`; `hooks` → `utils`; `utils` → `config`, `data` (`git grep -n "^import com\.demo\."`) | R6 se cumple, pero nada impide romperla |

## Decisión

### D1. Transporte mínimo: `com.demo.transport.Navegador`, clase concreta sin interfaz

**La capa de transporte hace falta, pero mínima.** A esta escala se gana lo siguiente:
- Selenium queda en un paquete, y las páginas solo conservan `By`.
- Ninguna página tiene `WebDriver`, así que R5 pasa a ser estructural.
- `executeScript` y la captura de pantalla quedan en un archivo.
- `Hooks` y `TestContext` quedan sin Selenium.
- Desaparece el doble dueño del driver.

**No son objetivos:** cambiar a Playwright sin tocar las páginas ni probar páginas sin navegador (ver *Alternativas*).

- **Qué es `Navegador`.** Vive en `src/test/java/com/demo/transport/` y es `public final`, con un constructor público sin argumentos y sin E/S. Es un componente de PicoContainer: una instancia por escenario, compartida por `Hooks` y las páginas. Es el **único dueño** del `WebDriver` y del `WebDriverWait`.
- **Su API pública es la interfaz del transporte.** Recibe solo `By` y tipos de Java, y nunca devuelve tipos de Selenium:

| Grupo | Métodos (nombres orientativos) | Origen |
|---|---|---|
| Ciclo de vida (solo `hooks`) | `iniciar()`, `cerrar()` (idempotente), `capturarPantalla(): byte[]` | `DriverFactory.java:25-67`, `Hooks.java:33` |
| Navegación | `abrir(String url)`, `esperarUrlContiene(String)` | `BasePage.java:145-147`, `:154-156` |
| Interacción con postcondición | `click(By)`, `clickYEsperarTexto(By, String)`, `clickYEsperarUrlContiene(By, String)`, `escribir(By, String)`, `desplazarA(By)` | `BasePage.java:47-66`, `:149-152` |
| Lectura | `esperarVisible(By)` (sin retorno), `texto(By): String`, `textos(By): List<String>`, `esVisible(By): boolean`, `esperarInvisible(By)` | `BasePage.java:43-45`, `:68-70`, `:127-143` |
| Navegación, lectura inmediata *(enmienda 2026-10-13)* | `urlContiene(String): boolean`, sin espera | Nuevo en `146df90` |
| Interacción con postcondición *(enmienda 2026-10-13)* | `clickYEsperarVisible(By, By)`, `clickYEsperarVisibleOUrlContiene(By, By, String)` y `clickYEsperarInvisible(By)`: usan el mismo clic con respaldo (`clickHastaCumplir`) que `clickYEsperarTexto` y `clickYEsperarUrlContiene`, con otra postcondición. `clickYEsperarInvisible` exige antes que el control esté visible, para que un localizador que no coincide no dé por cumplida la ausencia | Nuevos en `146df90`. La visibilidad previa, en `0de6962` |
| Interacción observada *(enmienda 2026-10-13)* | `clickYObservarUrlContiene(By, String): ResultadoClic`, con el `enum` anidado `ResultadoClic { AVANZO, NO_AVANZO, NO_DISPONIBLE }`. No exige la postcondición: `AVANZO` = la URL se alcanzó; `NO_AVANZO` = no se alcanzó tras al menos un clic efectivo; `NO_DISPONIBLE` = el control no estuvo visible y habilitado en el plazo, y no hubo clic. Quien lo llama decide si `NO_DISPONIBLE` es un resultado válido, y antes debe probar que el resto de la página cargó | Nuevo en `146df90`, donde la falta de clics lanzaba `IllegalStateException`. `NO_DISPONIBLE` sustituye a esa excepción en `0de6962` |
| Lectura *(enmienda 2026-10-13)* | `apareceEnTiempoMaximo(By): boolean`: espera, hasta el plazo, a que el elemento sea visible. `existeEnTiempoMaximo(By): boolean`: espera, hasta el plazo, a que el elemento esté presente en el DOM, visible o no. Ninguna de las dos falla si el elemento no llega | `apareceEnTiempoMaximo`: nuevo en `146df90`. `existeEnTiempoMaximo`: `0de6962` |
| Lectura estable *(enmienda 2026-10-13)* | `contarEstable(By): int`: devuelve el conteo cuando se repite en 2 sondeos consecutivos. `esVisibleEstable(By): boolean`: devuelve `true` en cuanto el elemento es visible, y `false` solo tras 2 sondeos consecutivos sin verlo. Las dos están acotadas por el plazo, sirven para afirmar ausencias y conteos, y exigen que el llamador haya comprobado antes que la página cargó | Árbol del 2026-10-13. `contarEstable` sustituye a `contar(By): int`, la lectura inmediata de `146df90` |

Las filas marcadas registran la API pública que la tabla original no recogía; las cuatro primeras no se reescriben. Reflejan el `Navegador` de `0de6962` (2026-10-13). Se registró del árbol de trabajo antes del commit, y después se comprobó que coincide (*Enmiendas*, 2026-10-13). Por eso se citan por método y no por línea. Todas cumplen este D1: reciben solo `By` y tipos de Java, no devuelven tipos de Selenium y fallan antes de `iniciar()`.

- **Tope de clics** (`0de6962`). `clickHastaCumplir` y `clickYObservarUrlContiene` pulsan como mucho `MAXIMO_CLICS_POR_ACCION = 3` veces: 1 clic nativo y, como máximo, 2 de respaldo JavaScript. *(Enmienda 2026-10-13, parte 3: se retira el respaldo JavaScript y queda un solo clic nativo por acción. Lo aplica el engineer; hasta su commit, rige lo que describe este punto. Ver *Enmiendas*, *Preferencias de Chrome y respaldo JavaScript*.)*
  - Con el tope agotado no pulsan más; solo esperan la postcondición dentro del plazo.
  - Si el plazo se agota, `clickHastaCumplir` lanza `TimeoutException` con el localizador, los clics efectivos y el plazo, y nunca con el texto escrito.
  - Antes, el respaldo JavaScript se repetía sin límite dentro del plazo. Un control que alterna su estado (agregar y quitar) podía revertirse con un clic de más.
  - **No es un reintento de la prueba (CHK-02):** es la misma acción, que antes no tenía tope (`BasePage.java:72-94`, movido en el paso 1).
  - El algoritmo de clic deja de ser el que el paso 1 movió "sin cambios". Esa condición regía el diff de movimiento del paso 1, no la evolución posterior, y PI-05 y PI-09 se siguen cumpliendo.
- **Contrato de `abrir(String url)`** (desde `8d7ce8b`, registrado el 2026-10-13):
  - Abre la URL y **falla al instante** con `IllegalStateException` si el navegador muestra su propia página de error de red. Lo comprueba en tres puntos:
    1. el driver lanza una `WebDriverException` cuyo mensaje describe un fallo de navegación (`net::ERR_…`, `about:neterror` o `chrome-error://`);
    2. el documento cargado es la página `neterror` de Chrome, que detecta el script constante `SCRIPT_LEER_CODIGO_PAGINA_ERROR` (PI-05);
    3. la URL actual empieza por `chrome-error://` o `about:neterror`.
  - Cualquier otra `WebDriverException` de la navegación se propaga sin cambios. Si el script no puede leer el documento, lo registra en DEBUG y decide la comprobación de la URL.
  - **Mensaje** (`BrowserErrorPage.describe`): `El navegador mostró una página de error de red al abrir '<url>' (<código>)`.
    - `<url>` es la que recibió `abrir`, que las páginas componen desde la configuración (`LoginPage.abrir`, `InventoryPage.solicitarDirectamente`).
    - `<código>` sale solo de un patrón `net::ERR_[A-Z0-9_]+`. Si no hay uno válido, es `código no disponible`.
    - Nunca incluye texto de la página ni del driver (PI-05). Se registra en ERROR.
  - Desde `0de6962`, el caso 1 registra además un DEBUG con SLF4J que solo lleva el nombre de la clase de la excepción y el código validado. No lleva el texto del driver ni la causa (PI-05, PI-09).
  - Desde `0de6962`, el código del mensaje del driver solo se extrae si está completo. Un código seguido de otro carácter de palabra (por ejemplo `net::ERR_ABCdef`) se descarta en lugar de truncarse, y el mensaje dice `código no disponible`. Su detección como fallo de navegación no cambia.
  - No reintenta (CHK-02).
  - **Dónde vive la lógica.** Clasificar el mensaje y la URL, validar el código y componer el mensaje es lógica pura. Vive en `src/main/java/com/demo/config/BrowserErrorPage.java`, con pruebas unitarias y PIT. Cumple el criterio D1 del ADR-001, porque un defecto en sus guardas pasaría inadvertido para la suite. La arista `transport` → `config` ya la permite D4.
  - El mismo commit agrega `--disable-component-update` a los argumentos de Chrome en `BrowserSettings` (D8).
- **`ResultadoClic`** es un tipo de Java del transporte, no de Selenium, así que cumple R1. Solo lo usan las páginas, dentro de su código: `CartPage.iniciarCheckout`, su método privado `pulsarTramitar` y `CartPage.intentarIniciarCheckout`.
  - Desde `0de6962`, `intentarIniciarCheckout` solo acepta "no se puede tramitar" (`NO_DISPONIBLE`) con prueba positiva: el carrito cargó y el botón de tramitar está presente en el DOM (`existeEnTiempoMaximo`) pero deshabilitado u oculto.
  - Si el botón no existe, falla cerrado con `IllegalStateException`, porque un botón eliminado no se distingue de un localizador roto.
  - El estado lo observa después `permaneceEnCarrito`.
  - **Restricción (enmienda 2026-10-13):** ningún método público de una página recibe ni devuelve `ResultadoClic`. Si una página lo expusiera, una acción podría recibirlo con `var` sin nombrar `com.demo.transport`, y R6 no lo vería: es el punto ciego que D6 cierra en el origen.
  - Se cumple, en `afb6693` y en `0de6962`: `git grep -nP '^\s*public\b.*\bResultadoClic\b' -- src/test/java/com/demo/pages` no da salida (rc=1). **La comprueba CHK-17 (R6)** desde el commit de la enmienda *R6: `ResultadoClic` fuera de los miembros públicos de las páginas* (D7). Hasta entonces era un P2 (*Enmiendas*, 2026-10-13, parte 1).

- **Algoritmos de sincronización.** Los de `BasePage.java:72-125` (clic y escritura con sus respaldos) se **mueven sin cambios**, y el diff se revisa como movimiento (*Criterio de verificación*).
- **Lo que no puede cambiar al moverlos:**
  - El primer argumento de `executeScript` es siempre una constante del transporte (PI-05).
  - Los logs y mensajes nunca incluyen el texto escrito, que puede ser una contraseña (PI-09). Hoy `:89` y `:117` solo registran el localizador.
- Cualquier método llamado antes de `iniciar()` falla con `IllegalStateException` y un mensaje claro, como hoy `TestContext.java:13-15`.
- **`DriverFactory` pasa a `com.demo.transport`.** Queda **sin estado** y con visibilidad de paquete (`static WebDriver crear()`). Se elimina el `ThreadLocal`, y la creación de Chrome, Firefox y `RemoteWebDriver` no cambia.
- **Ciclo de vida en `Hooks`:**
  - `@Before` llama a `navegador.iniciar()`.
  - `@AfterStep` llama a `navegador.capturarPantalla()` si el escenario falló.
  - `@After` llama a `navegador.cerrar()`, seguro con `null` como hoy `DriverFactory.java:58-67`.
- **`TestContext`** pierde el driver y conserva solo el estado de los steps (`:10`, `:23-35`).
- **Sin interfaz Java,** por tres motivos:
  - Hay una sola implementación.
  - Pico instancia clases concretas de forma transitiva, pero una interfaz exigiría un proveedor.
  - Extraerla después es un refactor local, porque las páginas solo dependen de la API pública.

  **Disparador:** adoptar un segundo motor de navegador o necesitar pruebas unitarias de páginas.

### D2. Páginas: composición sobre `Navegador`, con `By` como única excepción de Selenium

- Cada página recibe `Navegador` por constructor y no extiende ninguna clase. `BasePage` se **retira**.
- **Única dependencia de Selenium:** `import org.openqa.selenium.By;`, para las constantes `private static final By`.
  - Es una excepción **permanente por decisión**, no transitoria: `By` es un valor inmutable, y un tipo propio duplicaría el vocabulario de localizadores sin ganancia.
  - Solo se revisa con el disparador de D1.
  - Ningún método público de una página recibe ni devuelve `By`.
- **Lo que pueden leer:** `ConfigReader`, para rutas y textos de sincronización (`LoginPage.java:20`, `InventoryPage.java:22`, `:29`, `:37`).
  - Nunca leen claves `*.expected*`: un esperado usado en una espera convertiría el rojo de CHK-10 en un timeout fuera del `Then`.
  - Nunca leen secretos.
- **`literalXPath` se queda en la página** (`InventoryPage.java:40-48`). No va a `src/main` porque su defecto produce un selector inválido, es decir, un fallo visible, y no cumple el criterio D1(b) del ADR-001. *(Enmienda 2026-10-13: hoy es `pages/XPathLiteral`, compartida por dos páginas. Se queda en `pages`, sin las ramas que ningún dato ejercita; ver *Enmiendas*.)*

### D3. Acciones de negocio: `com.demo.actions`

- **Contenido.** El vocabulario del dominio y los flujos que cruzan páginas, solo con los métodos que usan los steps actuales (SDD-02). Nombres orientativos, en paralelo a los steps:
  - `LoginActions`: abrir el inicio de sesión, iniciar sesión con `Credentials`, título del catálogo, rechazo visible y mensaje de rechazo.
  - `CompraActions`: agregar productos, cantidad en el carrito, revisar el carrito (abrirlo y listarlo), tramitar la compra (`CartPage` → `CheckoutPage`, hoy en `CompraSteps.java:72-77`) y mensaje de confirmación.
- **Inyección.** Son clases concretas con un único constructor público que recibe las páginas. PicoContainer las crea por escenario sin agregarlas al glue, y `RunnerTest.java:15` no cambia. Las páginas también se inyectan, así que **`PageManager` se retira**: Pico ya da una instancia por escenario, y una página nueva no requiere registro.
- **Contrato:**
  - Reciben los datos como parámetros: `Credentials`, listas de productos y datos de envío. Elegir los datos y los esperados es intención de la prueba, así que queda en los steps.
  - Devuelven valores observados: `String`, `int`, `List<String>` o `boolean`.
  - No tienen aserciones, no usan `ConfigReader` ni secretos y no exponen tipos de página en sus firmas públicas.
- **R3 se activa.** Los steps no nombran `com.demo.pages` ni `com.demo.transport`: usan acciones, la capa 4 (`utils`, `data`), JUnit y Cucumber. Las aserciones siguen solo en los steps.
- **No cambian:** los textos de los steps, las features ni las claves de `config.properties`.

### D4. Grafo de dependencias permitido

Cada paquete solo puede nombrar los paquetes `com.demo.*` de su fila. El grafo es acíclico por construcción, así que R6 se verifica por filas y no hace falta buscar ciclos.

| Capa | Paquete | Puede nombrar | Selenium | JUnit / Cucumber |
|---|---|---|---|---|
| 1 | `transport` | `utils` (solo `ConfigReader`), `config` | Sí | No |
| 2 | `pages` | `transport`, `utils` (solo `ConfigReader`) | Solo `By` | No |
| 3 | `actions` | `pages`, `data` | No | No |
| 3 | `steps` | `actions`, `utils`, `data` | No | Sí |
| 4 | `utils` (fachadas de E/S y estado del escenario) | `config`, `data` | No | No |
| 4 | `config`, `data` (`src/main`) | Entre sí | No (lo impone Maven; CHK-15) | No |
| 5 | `hooks` | `transport`, `utils` | No | Solo Cucumber |
| 5 | `runners` | Ninguno (el glue se declara como texto, `RunnerTest.java:15`) | No | Sí |

Notas:
- `SecretReader` y `CredentialsProvider` solo se nombran en `utils` y `steps`. Las unitarias quedan fuera de esta regla porque CHK-16 ya les prohíbe `com.demo.utils` (D6).
- Las pruebas unitarias de `config` y `data` siguen bajo CHK-16.
- **Cambios en la columna *Depende de* de `qa-automation-architect.md:28-34`:**
  - capa 1: Selenium **y 4**;
  - capa 2: 1 **y 4** (solo configuración no sensible);
  - capa 3: `actions` → 2 y 4 (`data`); `steps` → `actions` y 4.

### D5. `com.demo.utils` se queda donde está, como capa 4

Cierra el pendiente heredado del ADR-001. `ConfigReader`, `SecretReader`, `CredentialsProvider` y `TestContext` son los adaptadores de E/S y el estado del escenario de la capa 4.
- **No se mueven a `src/test/java/com/demo/config` ni a `.../data`:** CHK-16 exige que esos directorios contengan solo `*Test.java`, sin `System.getenv`.
- **No se renombra el paquete:** costaría más de 30 cambios de import sin ninguna ganancia verificable.
- `DriverFactory` sale de `utils` (D1), y desde ese momento `utils` no tiene Selenium.

### D6. Mecanismo: CHK-17 con `git grep` (`scripts/check-layers.sh`), sin ArchUnit

- **Por qué no ArchUnit.** ArchUnit ve el bytecode, y con él la inferencia con `var`, los nombres calificados y los ciclos. Aun así, a esta escala no compensa:
  - es una dependencia nueva (P-06);
  - exige compilar;
  - el arquitecto no puede ejecutarlo, porque B-01 no permite `./mvnw`.

  `git grep` ya es el patrón de CHK-03, CHK-15 y CHK-16: corre en segundos, sin compilar, y lo puede ejecutar cualquier agente.
- **Puntos ciegos del texto y cómo se cierran:**
  - Nombres calificados e `import static`: se busca `org\.openqa` y `com\.demo\.X`, no `import …`.
  - Inferencia con `var`: se cierra en el origen. Ni el transporte ni las páginas exponen tipos de Selenium (salvo `By` como parámetro del transporte), y las acciones no exponen páginas.
  - **Riesgo residual aceptado:** firmas partidas en varias líneas, reflexión y código dentro de cadenas.
- **Convenciones del script.** Son las de `scripts/check-unit-purity.sh`:
  - `set -euo pipefail` y `LC_ALL=C`;
  - imprime `archivo:línea: R<n>: motivo`;
  - falla cerrado: si `git grep` termina con más de 1 o escribe en stderr, o ante un error de uso, termina con 2 (D7, *Nota de ejecución*).
- **Además, el script:**
  - Busca en dos pasadas (D7, *Nota de ejecución*). Con `--untracked`, para que el engineer vea una violación antes del commit, porque `git grep` ignora lo no versionado. Y sin él, porque `--untracked` omite los archivos versionados que coinciden con `.gitignore`.
  - **Falla si falta un directorio de capa versionado** (`transport`, `pages`, `actions`, `steps`). Si no, un directorio renombrado pasaría sin salida, y la comprobación fallaría abierta.
  - Excluye `runners` de R6, porque declara el glue como texto.
  - Cuenta los comentarios como texto: un comentario que nombra otra capa incumple la regla y no se trata como falso positivo.
  - **Única excepción:** la regla de secretos excluye las pruebas unitarias de `config` y `data`.
    - Sus Javadoc nombran `SecretReader` y `CredentialsProvider` precisamente para declarar que no los usan (`SecretResolverTest.java:15`, `CredentialsTest.java:10`).
    - El uso real ya lo rechaza CHK-16, porque exigiría importar `com.demo.utils`.
    - Es un falso positivo hallado al probar los comandos, y se corrige aquí, no en el script.
- **Implementación normativa.** `scripts/check-layers.sh` es la implementación normativa de CHK-17, y D7 transcribe sus comandos.
  - Si D7 y el script difieren, CHK-17 es lo que ejecuta el script, y la diferencia se corrige con una enmienda de este ADR.
  - Cambiar una expresión del script exige enmendar D7 en el mismo cambio. Nunca se relaja una regla para que un cambio pase.
- **Autoprueba versionada** (`scripts/tests/check-layers-test.sh`). Crea un repositorio temporal (`mktemp -d`) con un árbol mínimo válido y exige:
  - exit 0 sobre ese árbol y sobre las casi-violaciones permitidas (por ejemplo, un constructor de acciones con páginas);
  - exit 1 con al menos una violación por cada comando de D7, tanto versionada como sin versionar, y con una versionada que coincide con `.gitignore`;
  - exit 1 con cada directorio de capa ausente;
  - exit 2 con cada error de evaluación de la *Nota de ejecución* de D7.

  Así, una expresión regular rota no deja pasar todo en silencio. En `f7f7a13` tiene 81 casos (80 como root, donde el del archivo ilegible no aplica); 162 desde `a66e8ce`; 184 desde el commit de la enmienda sobre `ResultadoClic` (según devops); 280 desde `df87ada` (enmienda *Firmas expuestas*), con `ok` en 4 implementaciones de awk: mawk, gawk, `gawk --posix` y busybox (según devops). La enmienda *Selenium en el transporte y herencia* prevé 340 (D7); el total real lo informa devops al implementarla.
- **Dónde corren el script y la autoprueba:**
  - GitHub Actions: job `mutation`, pasos *Capas, autoprueba (CHK-17)* y *Capas (CHK-17)*, en paralelo a la suite y sin secrets (`ci.yml:66-84` en `f7f7a13`);
  - Jenkins: etapa `Capas (CHK-17)`, antes de la suite y fuera de `withCredentials` (`Jenkinsfile:22-29` en `f7f7a13`);
  - el gate local de devops;
  - la autoverificación del engineer.
- **Disparador para reconsiderar ArchUnit:** una evasión real que el texto no detecte, un segundo módulo Maven o más de unos 10 paquetes. Las reglas equivalentes quedan escritas en D7.

### D7. Reglas R1–R7 en su forma final

| Regla | Rechaza | Equivalente ArchUnit (esbozo de referencia; no se implementa) |
|---|---|---|
| R1 | Selenium fuera de `transport`; en `pages`, todo lo que no sea `import org.openqa.selenium.By;`; tipos de Selenium (salvo `By`) en firmas públicas del transporte; `By` en firmas públicas de páginas; interfaces, anotaciones o records expuestos en `transport` o `pages`. "Pública" incluye `protected` (*Firmas expuestas*, enmienda 2026-10-13). En `transport` (*Selenium en el transporte y herencia*, enmienda 2026-10-13, parte 2): cualquier tipo de Selenium importado o calificado en una firma expuesta, incluido el `throws`; `By`, solo como parámetro; heredar o implementar un tipo de Selenium; imports de Selenium con comodín | `noClasses().that().resideOutsideOfPackages("..transport..", "..pages..").should().dependOnClassesThat().resideInAPackage("org.openqa..")`; para `..pages..`, lo mismo con `.and(not(equivalentTo(By.class)))`. Firmas: métodos, campos y constructores con `PUBLIC` o `PROTECTED`. Tipos: `noClasses().that().resideInAnyPackage("..transport..", "..pages..").and(modifier(PUBLIC).or(modifier(PROTECTED))).should().beInterfaces().orShould().beRecords()` (una anotación es una interfaz). Transporte: miembros públicos o protegidos sin tipos de `org.openqa..` en el retorno, los parámetros (salvo `By`), el campo o el `throws`, y `noClasses().that().resideInAPackage("..transport..").should().beAssignableTo(resideInAPackage("org.openqa.."))` |
| R2 | Selenium en `steps` o `actions` (incluida en R1; CHK-03 es su subconjunto rápido) | `noClasses().that().resideInAnyPackage("..steps..", "..actions..").should().dependOnClassesThat().resideInAPackage("org.openqa..")` |
| R3 | `steps` que nombran `pages` o `transport`; acciones con páginas en sus firmas públicas, como tipo de retorno o como parámetro (los constructores sí las reciben, D3); interfaces, anotaciones o records expuestos en `actions`. "Pública" incluye `protected` (*Firmas expuestas*) | `noClasses().that().resideInAPackage("..steps..").should().dependOnClassesThat().resideInAnyPackage("..pages..", "..transport..")`. Tipos: lo mismo que en R1, para `..actions..` |
| R4 | JUnit fuera de `steps`, `runners` y las unitarias; Cucumber fuera de `steps`, `hooks` y `runners`; claves `*.expected*` en `transport`, `pages` o `actions` | `noClasses().that().resideInAnyPackage("..transport..", "..pages..", "..actions..").should().dependOnClassesThat().resideInAnyPackage("org.junit..", "io.cucumber..")` |
| R5 | `findElement(s)`, `executeScript` o `executeAsyncScript` fuera de `transport`; páginas que extienden una clase; clases de `transport`, `actions` o `utils` que extienden otra (*Selenium en el transporte y herencia*, enmienda 2026-10-13, parte 2) | `noClasses().that().resideOutsideOfPackage("..transport..").should().callMethodWhere(target(owner(assignableTo(SearchContext.class).or(assignableTo(JavascriptExecutor.class)))))`. Herencia: `classes().that().resideInAnyPackage("..transport..", "..pages..", "..actions..", "..utils..")` con una condición propia: `getRawSuperclass()` es `Object` (o `Enum` y `Record` en esos tipos) |
| R6 | Nombrar un paquete fuera de su fila de D4; secretos fuera de `utils` y `steps` (las unitarias, por CHK-16); `ResultadoClic` en un miembro público de una página (restricción de D1, enmienda del 2026-10-13). "Público" incluye `protected` (*Firmas expuestas*) | `layeredArchitecture().consideringOnlyDependenciesInLayers()` con las filas de D4 (`whereLayer(…).mayOnlyBeAccessedByLayers(…)`) y `slices().matching("com.demo.(*)..").should().beFreeOfCycles()`. Para `ResultadoClic`: métodos y campos públicos o protegidos de `..pages..` sin `Navegador.ResultadoClic` como tipo de retorno, de parámetro o de campo |
| R7 | Vocabulario de interfaz en las features | No aplica (Gherkin): CHK-04, sin cambios |

Comandos de CHK-17, transcritos de `scripts/check-layers.sh` (la implementación normativa, D6). Cada uno pasa **sin salida** y usa `-P`, como CHK-01.

Enmienda 2026-10-13 (*Firmas expuestas*): el bloque ya incluye `MOD`, `EXP` y `TIPO`, las cinco comprobaciones de firmas reescritas con `EXP` y las dos nuevas de tipos. Se integra en el mismo commit que el script y su autoprueba (D6). Hasta ese commit, CHK-17 es lo que ejecuta el script. *(Integrada en `df87ada`.)*

Enmienda 2026-10-13, parte 2 (*Selenium en el transporte y herencia*): el bloque ya incluye `IMP`, `HER`, `R1-wild`, `R1-by`, las dos uniones por imports (`R1-imp` y `R1-her`) y `R5-ext`. `union_imports` no es un comando de git: es la función del script que define *Unión por imports*. Se integra en el mismo commit que el script y su autoprueba (D6); hasta ese commit, CHK-17 es lo que ejecuta el script (24 comprobaciones en `df87ada`).

```bash
T=src/test/java/com/demo
# Declaración expuesta (Firmas expuestas): espacios, anotaciones y modificadores antes de public o protected
MOD='(?:@[\w.]+(?:\(.*\))?|non-sealed|[a-z]+)\s+'
EXP='^\s*(?:'"$MOD"')*(?:public|protected)\b'
TIPO="$EXP"'.*\b(?:interface|record)\s+\w'
# R1: Selenium solo en transport; en pages, solo el import de By
git grep --untracked -nP 'org\.openqa' -- src ":!$T/transport" ":!$T/pages"
git grep --untracked -nP 'org\.openqa(?!\.selenium\.By;$)' -- "$T/pages"
# R1: firmas públicas (expuestas)
git grep --untracked -nP "$EXP"'.*\b(Web[A-Z]\w*|SearchContext|JavascriptExecutor|TakesScreenshot|Capabilities|\w+Options)\b' -- "$T/transport"
git grep --untracked -nP "$EXP"'.*\bBy\b' -- "$T/pages"
#   … sin interfaces, anotaciones ni records expuestos (sus miembros son públicos sin escribir public)
git grep --untracked -nP "$TIPO" -- "$T/transport" "$T/pages"
# R1 en transport (Selenium en el transporte y herencia): import de Selenium y línea de herencia
IMP='\bimport\s+(?:static\s+)?org\.openqa\.'
HER='\b(?:extends|implements)\b'
#   … sin comodines de Selenium (los nombres de la unión salen de los imports)
git grep --untracked -nP '\bimport\s+(?:static\s+)?org\.openqa\.[\w.\s]*\*' -- "$T/transport"
#   … By solo como parámetro (después del primer paréntesis)
git grep --untracked -nP "$EXP"'[^(]*\bBy\b' -- "$T/transport"
#   … unión por imports: candidata con el token openqa o con un nombre importado de org.openqa en su archivo (salvo By)
union_imports "$EXP" -- "$T/transport"
union_imports "$HER" -- "$T/transport"
# R3: steps sin páginas ni transporte; acciones sin páginas en sus firmas públicas (expuestas)
git grep --untracked -nP 'com\.demo\.(pages|transport)\b' -- "$T/steps"
#   … página como tipo de retorno
git grep --untracked -nP "$EXP"'[^(]*\b\w+Page\b[^(]*\(' -- "$T/actions"
#   … página como parámetro (constructores exceptuados)
git grep --untracked -nP "$EXP"'(?!\s+\w+\s*\()[^(]*\(.*\b[A-Z]\w*Page\b' -- "$T/actions"
#   … sin interfaces, anotaciones ni records expuestos
git grep --untracked -nP "$TIPO" -- "$T/actions"
# R4: JUnit, Cucumber y esperados en su sitio
git grep --untracked -nP 'org\.junit' -- src ":!$T/steps" ":!$T/runners" ":!$T/config" ":!$T/data"
git grep --untracked -nP 'io\.cucumber' -- src ":!$T/steps" ":!$T/hooks" ":!$T/runners"
git grep --untracked -nP '\.expected' -- "$T/transport" "$T/pages" "$T/actions"
# R5: localización y scripts solo en transport; páginas por composición
git grep --untracked -nP '\bfindElements?\s*\(|\bexecute(Async)?Script\b' -- src ":!$T/transport"
git grep --untracked -nP '\bextends\b' -- "$T/pages"
#   … transport, actions y utils tampoco heredan (Selenium en el transporte y herencia)
git grep --untracked -nP '\bextends\b' -- "$T/transport" "$T/actions" "$T/utils"
# R6: una línea por fila de D4 (runners excluido; src/main lo garantiza Maven)
git grep --untracked -nP 'com\.demo\.(pages|actions|steps|hooks|runners|data)\b' -- "$T/transport"
git grep --untracked -nP 'com\.demo\.utils\.(?!ConfigReader\b)' -- "$T/transport" "$T/pages"
git grep --untracked -nP 'com\.demo\.(actions|steps|hooks|runners|config|data)\b' -- "$T/pages"
# R6 (restricción de D1, enmienda 2026-10-13): ResultadoClic no sale de pages
git grep --untracked -nP "$EXP"'.*\bResultadoClic\b' -- "$T/pages"
git grep --untracked -nP 'com\.demo\.(transport|utils|steps|hooks|runners|config)\b' -- "$T/actions"
git grep --untracked -nP 'com\.demo\.(hooks|runners|config)\b' -- "$T/steps"
git grep --untracked -nP 'com\.demo\.(transport|pages|actions|steps|hooks|runners)\b' -- "$T/utils"
git grep --untracked -nP 'com\.demo\.(pages|actions|steps|runners|config|data)\b' -- "$T/hooks"
git grep --untracked -nP '\b(SecretReader|CredentialsProvider)\b' -- src ":!$T/utils" ":!$T/steps" ":!$T/config" ":!$T/data"
# Directorios de capa presentes (cada uno debe listar al menos un archivo)
git ls-files "$T/transport" "$T/pages" "$T/actions" "$T/steps"
```

**R3 en acciones.** La expresión del tipo de retorno se detiene en el primer `(`, así que no ve `public void usar(LoginPage pagina) {` (P2 del verifier). La de parámetros busca un tipo `*Page` después del `(` de un método público:
- `(?!\s+\w+\s*\()` excluye los constructores, que sí reciben páginas (D3). Un constructor es el único miembro con un solo identificador entre `public` y `(`; un método lleva además el tipo de retorno.
- `[A-Z]` exige un nombre de tipo, para no confundirlo con un nombre de variable.
- Busca hasta el final de la línea, así que una anotación con argumentos no oculta el parámetro. A cambio, una línea con cuerpo que crea una página da un falso positivo, que falla cerrado.
- Las firmas partidas en varias líneas siguen siendo riesgo residual aceptado (D6, R-5).
- Desde la enmienda *Firmas expuestas*, `^\s*public\b` es `EXP` en las dos expresiones: admite anotaciones y modificadores delante, y `protected`. Los constructores siguen exceptuados.

**`ResultadoClic` en páginas** (R6, restricción de D1, enmienda del 2026-10-13). La expresión `^\s*public\b.*\bResultadoClic\b` busca el tipo en cualquier miembro público de una página:
- Cubre el tipo de retorno, los parámetros y los campos públicos, con el nombre calificado (`Navegador.ResultadoClic`) o importado.
- `\b` exige la palabra completa, así que `esResultadoClic` y `ResultadoClicados` pasan.
- El uso interno, los métodos privados y los comentarios no empiezan por `public`, así que también pasan.
- Los constructores de las páginas reciben `Navegador`, no `ResultadoClic`, así que no hace falta exceptuarlos.
- Las firmas partidas en varias líneas siguen siendo riesgo residual aceptado (D6, R-5).
- Desde la enmienda *Firmas expuestas*, la expresión es `EXP.*\bResultadoClic\b`, y `R1-tipos` impide que una interfaz, una anotación o un record expuestos de `pages` lo saquen.

**Firmas expuestas** (R1, R3 y R6; enmienda 2026-10-13). Precisa qué es una firma o un miembro "público" en las cinco comprobaciones de firmas, y cierra los huecos de la expresión anterior.

*Huecos de `^\s*public\b`* (P2 registrado por el coordinador el 2026-10-13). La expresión exigía `public` al principio de la línea, tras espacios, y no veía:
- una anotación en la misma línea: `@Override public ResultadoClic x()`;
- otro orden de modificadores: `static public`, `final public`;
- `protected`;
- los miembros de una interfaz o de una anotación (`@interface`), que son públicos sin escribir `public`, ni los componentes de un `record`, que son accesores públicos.

El hueco era el mismo en R1 (`By` y tipos de Selenium) y en R3 (páginas en acciones). Además, la autoprueba no tenía ningún caso con `public` en la columna 0, así que sobrevivía el mutante `^\s*public` → `^\s+public`.

*Definición.* En R1, R3 y R6, una firma o un miembro **público** es una **declaración expuesta**: una línea que, después de espacios, anotaciones y modificadores, lleva `public` o `protected`. `MOD` es un elemento del prefijo, `EXP` la declaración expuesta y `TIPO` un tipo expuesto con miembros públicos implícitos:

```text
MOD  = (?:@[\w.]+(?:\(.*\))?|non-sealed|[a-z]+)\s+
EXP  = ^\s*(?:MOD)*(?:public|protected)\b
TIPO = EXP.*\b(?:interface|record)\s+\w
```

- `@[\w.]+(?:\(.*\))?` es una anotación, simple o calificada (`@java.lang.Deprecated`), con o sin argumentos. `.*` admite paréntesis anidados.
- `non-sealed|[a-z]+` es un modificador. Se acepta cualquier palabra en minúsculas, no una lista: en Java válido, delante de `public` en la misma línea solo puede haber modificadores (`static`, `final`, `abstract`, `synchronized`, `native`, `strictfp`, `transient`, `volatile`, `default`, `sealed`). Una lista fallaría abierto ante un modificador nuevo.
- El `\s+` de `MOD` exige un espacio tras cada elemento, así que `nonpublic` no es `non` seguido de `public`.
- El `\b` final de `EXP` deja fuera `publicar(…)` y `protectedMode(…)`.
- Una línea que empieza por `//`, `*`, `/*`, una cadena o un nombre en mayúscula (`Navegador.ResultadoClic r = …`) no puede coincidir con `EXP`. Por eso pasan los comentarios, las cadenas, las variables locales y los miembros `private` o de paquete, también con anotaciones.
- Con cero elementos de `MOD` y la alternativa `public`, `EXP` es la expresión anterior. Así, cada comprobación encuentra todo lo que encontraba antes, y los casos negativos vigentes de la autoprueba siguen fallando con la misma línea.

*Decisión 1: `protected` cuenta como expuesto.*

| Opción | Veredicto | Motivo |
|---|---|---|
| A. `public` o `protected` en las cinco comprobaciones | **Elegida** | `protected` da acceso al paquete y a las subclases de cualquier paquete. R5 impide que una página extienda una clase, pero no que una clase de `actions` o de `steps` extienda una página, y ninguna regla exige `final`. Hoy las 5 páginas públicas, `Navegador` y las 2 acciones son `final`, pero nada lo comprueba, y en `transport` y `actions` no hay un R5 equivalente. Tampoco hay ningún `protected` en `src` (`git grep -n -w protected -- src`, rc=1): no cuesta nada y falla cerrado |
| B. `protected` no cuenta, porque R5 prohíbe que las páginas extiendan | Descartada | R5 mira el `extends` de la página, no el de quien la extiende |
| C. Prohibir `protected` en `transport`, `pages` y `actions` | Descartada | Es más fuerte de lo necesario: un miembro `protected` con tipos de Java no expone nada. Suma una comprobación sin cerrar ningún hueco que A deje abierto |
| D. Exigir `final` en las clases de `pages` y tratar `protected` como de paquete | Descartada | Reconocer por texto una declaración de clase (con `sealed`, `abstract`, anotaciones o anidada) es frágil, y no cubre `transport` ni `actions` |

*Decisión 2: en `transport`, `pages` y `actions` no se declaran interfaces, anotaciones (`@interface`) ni records expuestos.*
- Los miembros de una interfaz y de una anotación son públicos sin escribir `public`, y ninguna expresión por línea los ve: `public interface Pulsable {`, seguido de `ResultadoClic pulsar();` en otra línea, pasaría.
- Los componentes de un `record` son accesores públicos, y su cabecera se parte a menudo en varias líneas.
- Los tipos expuestos de esas capas quedan en `class` y `enum`. Hoy son los únicos: 10 clases y el `enum ResultadoClic` (`git grep -nP '\b(class|interface|record|enum)\s+\w'` sobre las tres capas). Los contratos de D1 y D3 ya enumeran los tipos que cruzan esas capas.
- Los tipos privados o de paquete sí se permiten, porque otro paquete no los alcanza.
- En `TIPO`, el `\b` reconoce también `@interface`, y el `\s+\w` exige el nombre del tipo: un método `record()` o `recordar()` y un campo `record = …` pasan.

| Opción | Veredicto | Motivo |
|---|---|---|
| A. Prohibir interfaces, anotaciones y records expuestos en las tres capas | **Elegida** | Cierra el hueco por construcción, con una sola expresión y sin falsos positivos hoy |
| B. Seguir los miembros dentro del cuerpo de una interfaz | Imposible con `git grep` | Busca por línea, así que no sabe dentro de qué tipo está una línea. Lo haría ArchUnit (disparador de D6) |
| C. Prohibir solo las interfaces y aceptar records con la cabecera en una línea | Descartada | Exige otra comprobación (cabecera expuesta sin cerrar) para un tipo que hoy nadie usa. Si una spec necesita un valor compuesto, se reabre por enmienda |
| D. Tratarlo como el riesgo residual de las firmas partidas (R-5) | Descartada | R-5 acepta un formato poco común. Una interfaz no es un formato: todos sus miembros evaden la regla |

*Comprobaciones.* Las cinco existentes conservan su ID y su motivo impreso: "pública" se lee con la definición de arriba. Con las dos nuevas son 24 comprobaciones (*Nota de ejecución*).

| ID (autoprueba) | Regla | Ámbito | Expresión | Motivo impreso |
|---|---|---|---|---|
| `D7-03` | R1 | `transport` | `EXP` seguida de `.*\b(…)\b`, con los tipos de Selenium de siempre | tipo de Selenium en una firma pública del transporte |
| `D7-04` | R1 | `pages` | `EXP.*\bBy\b` | By en una firma pública de una página |
| `R1-tipos` (nueva) | R1 | `transport` y `pages` | `TIPO` | interfaz, anotación o record expuesto en transport o pages |
| `D7-06` | R3 | `actions` | `EXP[^(]*\b\w+Page\b[^(]*\(` | página en el tipo de retorno de un método público de actions |
| `R3-param` | R3 | `actions` | `EXP(?!\s+\w+\s*\()[^(]*\(.*\b[A-Z]\w*Page\b` | página como parámetro de un método público de actions |
| `R3-tipos` (nueva) | R3 | `actions` | `TIPO` | interfaz, anotación o record expuesto en actions |
| `D1-rc` | R6 | `pages` | `EXP.*\bResultadoClic\b` | ResultadoClic en un miembro público de una página |

- `R1-tipos` también protege R6: una interfaz expuesta en `pages` podría sacar `ResultadoClic`.
- En `R3-param`, un constructor sigue exceptuado con anotación o con `protected`: en `@Inject public OtraActions(LoginPage p)` hay un solo identificador entre el modificador de acceso y `(`.

*Implementación (`devops-engineer`).* `scripts/check-layers.sh` define `MOD`, `EXP` y `TIPO` una sola vez, como el bloque de comandos, y las siete comprobaciones las usan. El prefijo no se copia en cada línea, así que un mutante del prefijo se mata una vez para todas. Los casos `-anot`, `-mod` y `-prot` de cada comprobación demuestran que cada una usa `EXP`.

*Casos de autoprueba.* Cada línea es la línea 2 del archivo indicado, tal cual y con su sangría:
- las de "Deben fallar" van con `violation`: exit 1 y la línea `archivo:2: R<n>: motivo` exacta de su comprobación;
- las de "Deben pasar" van con `allowed`: exit 0;
- todas, en sus dos modos (versionada y sin versionar).

Son 32 casos negativos y 16 permitidos, es decir, 96 ejecuciones más: 280 en total. Los casos vigentes no cambian.

```java
// ===== Deben fallar (violation) =====
// D7-03-col0 · R1 · transport/Bad.java · columna 0
public WebElement buscar(By locator) {
// D7-03-anot · R1 · transport/Bad.java · anotación en la misma línea
    @Override public WebElement buscar(By locator) {
// D7-03-mod · R1 · transport/Bad.java · modificador antes de public
    static public WebDriver crear() {
// D7-03-prot · R1 · transport/Bad.java · protected
    protected WebDriver driver() {
// D7-04-col0 · R1 · pages/BadPage.java
public void pulsar(By locator) {
// D7-04-anot · R1 · pages/BadPage.java
    @Deprecated public void pulsar(By locator) {
// D7-04-mod · R1 · pages/BadPage.java
    final public void pulsar(By locator) {
// D7-04-prot · R1 · pages/BadPage.java · campo protegido
    protected static final By TITULO = By.className("title");
// R1-tipos · R1 · pages/BadPage.java · interfaz en la columna 0
public interface Pulsable {
// R1-tipos-b · R1 · pages/BadPage.java · anotación (@interface)
    public @interface Marca {
// R1-tipos-c · R1 · pages/BadPage.java · record con un modificador antes de public
    static public record Estado(boolean visible) {}
// R1-tipos-d · R1 · pages/BadPage.java · interfaz protegida
    protected interface Pulsable {
// R1-tipos-e · R1 · transport/Bad.java · interfaz anotada
    @FunctionalInterface public interface Condicion {
// D7-06-col0 · R3 · actions/Bad.java
public LoginPage pagina() {
// D7-06-anot · R3 · actions/Bad.java
    @Deprecated public LoginPage pagina() {
// D7-06-mod · R3 · actions/Bad.java
    synchronized public LoginPage pagina() {
// D7-06-prot · R3 · actions/Bad.java
    protected LoginPage pagina() {
// R3-param-col0 · R3 · actions/Bad.java
public void usar(LoginPage pagina) {
// R3-param-anot · R3 · actions/Bad.java
    @Override public void usar(LoginPage pagina) {
// R3-param-mod · R3 · actions/Bad.java
    final public void usar(LoginPage pagina) {
// R3-param-prot · R3 · actions/Bad.java
    protected void usar(LoginPage pagina) {
// R3-tipos · R3 · actions/Bad.java · interfaz en la columna 0
public interface Flujo {
// R3-tipos-b · R3 · actions/Bad.java · record
    public record Resumen(String total, int cantidad) {}
// R3-tipos-c · R3 · actions/Bad.java · interfaz anotada y protegida
    @Deprecated protected interface Paso {
// D1-rc-col0 · R6 · pages/BadPage.java
public Navegador.ResultadoClic pulsar() {
// D1-rc-anot · R6 · pages/BadPage.java
    @Override public ResultadoClic x() {
// D1-rc-mod · R6 · pages/BadPage.java
    static public Navegador.ResultadoClic pulsar() {
// D1-rc-prot · R6 · pages/BadPage.java
    protected Navegador.ResultadoClic pulsar() {
// EXP-args · R6 · pages/BadPage.java · anotación con argumentos
    @Deprecated(since = "1") public Navegador.ResultadoClic pulsar() {
// EXP-calif · R6 · pages/BadPage.java · anotación calificada
    @java.lang.Deprecated public Navegador.ResultadoClic pulsar() {
// EXP-dos · R6 · pages/BadPage.java · dos elementos antes de public
    @Deprecated final public Navegador.ResultadoClic pulsar() {
// EXP-ns · R6 · pages/BadPage.java · non-sealed en la columna 0
non-sealed public class BadPage implements Supplier<Navegador.ResultadoClic> {

// ===== Deben pasar (allowed) =====
// ok-12 · pages/OtraPage.java · anotación y private
    @SuppressWarnings("unused") private Navegador.ResultadoClic pulsar() {
// ok-13 · pages/OtraPage.java · miembro de paquete con modificador
    static Navegador.ResultadoClic pulsar() {
// ok-14 · pages/OtraPage.java · variable local con final
        final Navegador.ResultadoClic resultado = pulsar();
// ok-15 · pages/OtraPage.java · identificador que termina en public
        boolean nonpublic = resultado == Navegador.ResultadoClic.AVANZO;
// ok-16 · pages/OtraPage.java · identificador que empieza por protected
        protectedMode(Navegador.ResultadoClic.AVANZO);
// ok-17 · pages/OtraPage.java · comentario de línea
    // @Override public Navegador.ResultadoClic pulsar() {
// ok-18 · pages/OtraPage.java · Javadoc
     * static public Navegador.ResultadoClic pulsar() no es API de la página
// ok-19 · pages/OtraPage.java · cadena
        String plantilla = "@Override public Navegador.ResultadoClic x()";
// ok-20 · actions/OtraActions.java · constructor anotado con páginas (D3)
    @Inject public OtraActions(LoginPage loginPage) {
// ok-21 · actions/OtraActions.java · constructor protegido con páginas
    protected OtraActions(LoginPage loginPage) {
// ok-22 · actions/OtraActions.java · método privado anotado con una página
    @SuppressWarnings("unused") private void usar(LoginPage pagina) {
// ok-23 · transport/Otro.java · interfaz privada
    private interface Condicion { boolean cumple(); }
// ok-24 · pages/OtraPage.java · record de paquete
    record Fila(String nombre, int cantidad) {}
// ok-25 · pages/OtraPage.java · método que empieza por record
    public void recordar() {
// ok-26 · pages/OtraPage.java · campo llamado record
    public String record = "";
// ok-27 · pages/OtraPage.java · tipo que termina en record
    public void guardar(Autorecord registro) {
```

*Mutantes que deben morir.* Es el sabotaje de devops, como el de `bb7f145`. Cada mutante debe hacer fallar al menos los casos indicados:

| Mutante | Casos que lo matan |
|---|---|
| E1. `^\s*` → `^\s+` | Los `-col0`, `R1-tipos`, `R3-tipos` y `EXP-ns` |
| E2. `^\s*` → `^` | Cualquier caso con sangría |
| E3. Sin `(?:MOD)*` | Los `-anot` y los `-mod` |
| E4. `(?:MOD)*` → `(?:MOD)?` | `EXP-dos` |
| E5. Sin la alternativa de anotación | Los `-anot` |
| E6. Sin `(?:\(.*\))?` | `EXP-args` |
| E7. `[\w.]` → `\w` | `EXP-calif` |
| E8. Sin `non-sealed` | `EXP-ns` |
| E9. Sin `[a-z]+` | Los `-mod` |
| E10. El `\s+` de `MOD` → `\s*` | `ok-15` |
| E11. Sin `protected` | Los `-prot`, `R1-tipos-d` y `R3-tipos-c` |
| E12. El modificador de acceso, opcional (`?`) | `ok-12`, `ok-13` y `ok-14` |
| E13. Sin el `\b` final de `EXP` | `ok-9` (`publicar`) y `ok-16` |
| E14. Una de las siete comprobaciones conserva `^\s*public\b` | Sus casos `-anot`, `-mod` y `-prot`. En `R1-tipos`, `-c`, `-d` y `-e`; en `R3-tipos`, `-c` |
| T1. Sin `interface` | `R1-tipos`, `R1-tipos-b`, `-d` y `-e`, `R3-tipos` y `R3-tipos-c` |
| T2. Sin `record` | `R1-tipos-c` y `R3-tipos-b` |
| T3. Sin el `\b` de `TIPO` | `ok-27` |
| T4. El `\s+` de `TIPO` → `\s*` | `ok-25` |
| T5. Sin `\s+\w` | `ok-25` |
| T6. Sin el `\w` final | `ok-26` |
| T7. `R1-tipos` sin `transport` o sin `pages` | `R1-tipos-e` o `R1-tipos` |

Cambiar la avidez de un `.*` (`.*` ↔ `.*?`) es equivalente: que una línea coincida no depende de la avidez.

*Riesgo residual aceptado (D6, R-5):*
- firmas, cabeceras y anotaciones partidas en varias líneas;
- texto que no sea espacio, anotación ni modificador antes del modificador de acceso: `} public …`, `/* … */ public …`;
- una anotación con un espacio antes del paréntesis (`@A (x) public …`) o pegada al modificador (`@A(x)public …`);
- el cuerpo de una constante de `enum` en la misma línea (`AVANZO { public By x() { … } }`).

*Falsos positivos, que fallan cerrado:*
- líneas de un bloque de texto (`"""`) o de un comentario sin `//` ni `*` que parezcan declaraciones;
- una interfaz o un record expuestos anidados en una clase de paquete: otro paquete no los ve, pero se rechazan;
- una línea expuesta con una cadena o un cuerpo que contenga `interface X` o `record X`.

*Comprobación sobre el árbol* (2026-10-13, HEAD `34f8528` y árbol limpio; solo `git grep`, B-01): ver la enmienda *Firmas expuestas*.

**Selenium en el transporte y herencia** (R1 y R5; enmienda 2026-10-13, parte 2). Cierra los dos P2 que dejó *Firmas expuestas* en *Fuera de alcance*.

*Huecos.*
1. `D7-03` busca en las firmas expuestas del transporte una **lista cerrada** de tipos. No ve `RemoteWebDriver`, `ChromeDriver`, `FirefoxDriver`, `Alert`, `Cookie`, `Dimension` ni ningún tipo que se agregue a Selenium.
2. Solo `pages` tiene una comprobación de `extends` (`D7-11`). Una clase que hereda de otra expone toda la API pública de la superclase, y quien la usa la alcanza sin nombrarla. Ninguna comprobación de firmas lo ve, porque la línea no tiene `(`:

| Quien hereda | De | La alcanzan sin nombrarla | Regla que se evade |
|---|---|---|---|
| `transport` | Selenium (`extends ChromeDriver`, `implements WebDriver`) | `pages` y `hooks` | R1 |
| `transport` | `config` | `pages` y `hooks` | R6 (filas de `pages` y `hooks`) |
| `actions` | una página | `steps` | R3 |
| `utils` | `config` o `data` | `pages`, `steps` y `hooks` | R6 |
| `steps`, `hooks`, `runners` | — | Nadie: ninguna fila de D4 permite nombrarlos | — |

Además, al implementar una interfaz de Selenium la clase recibe sus métodos `default` y sus tipos anidados, que se usan por nombre simple sin import (dentro de una clase que implementa `WebDriver`, `Options` es `WebDriver.Options`). Ninguna expresión que solo lea el archivo los ve.

*Decisión 1: en `transport`, los nombres de Selenium se derivan de los imports de cada archivo.*

En una línea expuesta de `transport` está prohibido cualquier tipo de Selenium, salvo `By` como parámetro. "Tipo de Selenium" es un token que sea `openqa` o el nombre simple de un import de `org.openqa` del mismo archivo.

**Es completa para declaraciones de una línea.** En un archivo de `transport`, el nombre simple de un tipo de Selenium solo puede estar en alcance de tres formas, y las tres quedan cubiertas:
- **Un import simple o `static`:** su nombre entra en la lista del archivo.
- **Un import con comodín:** `R1-wild` lo rechaza.
- **Un tipo heredado de un supertipo de Selenium:** `R1-her` y `R5-ext` rechazan la herencia.

El paquete `com.demo.transport` no contiene tipos de Selenium. Un nombre calificado contiene el token `openqa`, y un tipo anidado que se escribe con su externo (`WebDriver.Timeouts`) contiene el nombre importado.

| Opción | Veredicto | Motivo |
|---|---|---|
| A. Lista derivada de los imports **de cada archivo** (a), sin comodines de Selenium en `transport`, más el token `openqa` para los nombres calificados (c) | **Elegida** | Es abierta: un tipo nuevo de Selenium entra en la lista al importarlo. Compara tokens, así que no arma una expresión regular con texto leído del repositorio, y no depende del orden ni de la longitud de la lista |
| B. Lista abierta por patrón: la unión de los nombres importados de `org.openqa` en toda la capa (b) | Descartada | Es el mismo mecanismo en dos pasos que A, pero menos preciso: un tipo propio que comparte el nombre simple con uno de Selenium importado en otro archivo da un falso positivo. Si se construye como alternancia de PCRE, además arma una expresión con texto del repositorio (contra el espíritu de PI-04), que hay que validar |
| C. Solo prohibir los nombres calificados `org.openqa` en las firmas (c) | Descartada como regla única | No ve los nombres simples importados, que son el caso normal. Queda dentro de A como el token `openqa` |
| D. Ampliar la lista cerrada de `D7-03` | Descartada | Sigue siendo cerrada: falla abierto ante el siguiente tipo, y la API pública de Selenium crece con cada versión |
| E. Lista blanca de tipos permitidos (`By`, `java.*` y los propios) | Descartada | Por texto no se sabe qué nombre es de `java.*` sin el mismo cruce con los imports, y `java.lang` no se importa. Una lista cerrada de nombres permitidos obliga a enmendar el ADR por cada tipo de Java nuevo (`Duration`, `Optional`) |
| F. ArchUnit | Descartada | D6: es una dependencia nueva (P-06), exige compilar y el arquitecto no puede ejecutarla. Ninguna evasión real activa su disparador |

- **Comodines.** Hoy no hay ninguno en todo `src` (*Enmiendas*, comprobación sobre `df87ada`). Se prohíben solo los de `org.openqa` y solo en `transport`: fuera de `transport`, `D7-01` y `D7-02` ya los rechazan, y los comodines de Java no ocultan nombres de Selenium.
- **`By`** queda fuera de la lista derivada, porque es la excepción de D2. Su control es `R1-by`: en una línea expuesta de `transport`, `By` solo puede aparecer después del primer `(`. Así tiene comando la frase de D6 "salvo `By` como parámetro del transporte": hasta ahora `public By x()` y `public static final By X` pasaban.
- **`throws`** forma parte de la firma. Una excepción de Selenium declarada en un miembro expuesto obliga a quien lo llama a capturar un tipo que no puede importar, así que también se rechaza.
- **Imports `static`.** Su último segmento entra en la lista, sea un tipo anidado, un método o una constante.
- **Nombres calificados** en las firmas y la herencia de `transport`: se rechazan todos, también `org.openqa.selenium.By` como parámetro. En las firmas del transporte, Selenium se nombra por import.
- **`D7-03` se conserva**, con sus casos y su motivo. En código que compila, la unión lo cubre. Se mantiene como una red independiente del awk: si la unión fallara, `D7-03` seguiría viendo los tipos habituales.

*Decisión 2: composición en `transport`, `pages`, `actions` y `utils`, y ninguna herencia de Selenium en `transport`.*

| Opción | Veredicto | Motivo |
|---|---|---|
| A. Prohibir `extends` en `transport`, `actions` y `utils`, como ya se hace en `pages` (`R5-ext`), y además heredar o implementar un tipo de Selenium en `transport`, con la unión por imports (`R1-her`) | **Elegida** | Cierra las cuatro filas de riesgo de la tabla con una expresión que ya existe (`D7-11`) y con el mismo mecanismo que la Decisión 1. Es el estilo de D1–D3: `Navegador`, las páginas y las acciones componen. Hoy no hay ningún `extends` ni `implements` en `src` |
| B. Prohibir solo la herencia de tipos de Selenium | Descartada | No cierra `actions` → páginas, `utils` → `config` o `data`, ni `transport` → `config` |
| C. Prohibir solo `implements` de interfaces de Selenium | Descartada | No ve `extends ChromeDriver` ni ninguna de las filas que no son de Selenium |
| D. Prohibir `extends` e `implements` en todas las capas que se consumen | Descartada | Una interfaz de Java (`AutoCloseable`, `Supplier<String>`) no expone nada que no esté escrito en el archivo, donde ya lo ven las comprobaciones de firmas (los métodos `default` de Java solo usan tipos de Java). Sumaría falsos positivos sin cerrar ningún hueco |
| E. Exigir `final` en las clases | Descartada | `final` impide que otra clase herede de esta, pero no que esta herede de otra. Además, reconocer por texto una declaración de clase es frágil (*Firmas expuestas*, Decisión 1, opción D) |
| F. Incluir `steps`, `hooks` y `runners` | Descartada | Ninguna fila de D4 permite nombrarlos, así que lo que hereden no llega a otra capa. Cucumber, además, rechaza heredar de una clase que define steps o hooks |

- **`implements` de interfaces de Java** sigue permitido en todas las capas. Solo se rechaza el de Selenium en `transport`.
- **`R1-her` también mira `extends`**, aunque `R5-ext` ya lo rechaza en `transport`. Así el motivo impreso es el preciso, y Selenium sigue protegido si algún día `R5-ext` admite excepciones propias.
- **Coste.** En `transport`, `actions` y `utils` tampoco caben una excepción propia (`extends RuntimeException`) ni los límites genéricos (`<T extends …>`, `? extends`). Hoy no hay ninguno. Si una spec los necesita, se reabre por enmienda (por ejemplo, para exceptuar `extends RuntimeException`), nunca se relaja la regla.
- **`src/main`** queda fuera de CHK-17, porque D4 deja `config` y `data` a Maven y a CHK-15. Una clase de `data` que extendiera una de `config` expondría `config` a `actions` y a `steps`. Hoy no hay ningún `extends` en `src`, así que se acepta como riesgo residual. **Disparador:** el primer `extends` en `src/main`.

*Expresiones.* `IMP` y `HER` se definen una sola vez, como `MOD`, `EXP` y `TIPO`:

```text
IMP = \bimport\s+(?:static\s+)?org\.openqa\.
HER = \b(?:extends|implements)\b
```

Con estas cinco son 29 comprobaciones (*Nota de ejecución*):

| ID (autoprueba) | Regla | Ámbito | Expresión | Motivo impreso |
|---|---|---|---|---|
| `R1-wild` (nueva) | R1 | `transport` | `\bimport\s+(?:static\s+)?org\.openqa\.[\w.\s]*\*` | import con comodín de Selenium en transport |
| `R1-by` (nueva) | R1 | `transport` | `EXP[^(]*\bBy\b` | By fuera de los parámetros de una firma pública del transporte |
| `R1-imp` (nueva) | R1 | `transport` | Unión por imports, con `EXP` como candidatas | tipo de Selenium importado o calificado en una firma pública del transporte |
| `R1-her` (nueva) | R1 | `transport` | Unión por imports, con `HER` como candidatas | transport hereda o implementa un tipo de Selenium |
| `R5-ext` (nueva) | R5 | `transport`, `actions` y `utils` | `\bextends\b` | una clase de transport, actions o utils extiende otra |

- En `R1-wild`, `[\w.\s]*` admite espacios entre los segmentos (`org.openqa.selenium. *`), y se detiene en `;`, así que `import org.openqa.selenium.By; /* … */` no coincide.
- En `R1-by`, `[^(]*` cubre el tipo de retorno, el tipo de un campo y la cláusula de herencia de una clase expuesta (`public final class X extends By`). `EXP` consume una anotación con argumentos, así que su `(` no corta la búsqueda antes de tiempo.
- `HER` no exige `class` en la misma línea, así que una cláusula `extends` o `implements` en su propia línea también se ve.

*Unión por imports* (`R1-imp` y `R1-her`). `union_imports <candidatas> -- <rutas>` imprime `archivo:línea: R1: motivo` por cada línea candidata que contenga el token `openqa` o un nombre importado de `org.openqa` en su mismo archivo:
1. **Dos `git grep` con guardas.** Uno con `IMP` y otro con las candidatas, sobre las mismas rutas. Los dos usan el ejecutor de dos pasadas de `check`, con las mismas guardas (rc ≥ 2 o stderr → 2). El ejecutor se factoriza, no se copia, igual que `EXP`.
2. **Entrada del awk.** Cada línea llega como un registro `tipo<TAB>archivo<TAB>línea<TAB>contenido`: `I` para las líneas de `IMP` y `L` para las candidatas. La forma de etiquetarlos es libre, sin extensiones de GNU, pero los registros llegan por una tubería o por un temporal, **nunca por sustitución de procesos** (`<(…)`), porque su código de salida se pierde.
3. **Errores.** Si awk termina con un código distinto de 0, el script escribe `check-layers: ERROR: awk terminó con <rc> (<regla>: <motivo>)` en stderr y sale con 2. Si hay salida, se ordena y se depura como en `check`, y el estado pasa a 1.
4. **Nombres.** En cada segmento de una línea `I` (separado por `;`) que contenga `import [static] org.openqa.<ruta>`, el nombre es el último identificador de `<ruta>`. `By` no entra, y un comodín no da nombre (lo rechaza `R1-wild`).
5. **Violación.** Una línea `L` incumple si alguno de sus tokens (secuencias máximas de `[A-Za-z0-9_]`) es `openqa` o un nombre de su archivo. La comparación es por token completo, no por subcadena.
6. **Orden.** Se evalúa en `END`, así que el resultado no depende del orden de los registros.

Programa de referencia. Usa solo awk POSIX (CHK-18): `match` con dos argumentos, `split` con un separador de cadena y ningún nombre exclusivo de gawk. devops puede reorganizarlo, pero si cambia la semántica de los puntos 3 a 6, este ADR se corrige antes del commit (D6).

```awk
# union_imports: une los imports de org.openqa (I) con las líneas candidatas (L).
# Entrada: tipo<TAB>archivo<TAB>línea<TAB>contenido (el contenido puede tener tabuladores).
# Variables: -v r=<regla> -v m=<motivo>. Salida: "archivo:línea: <regla>: <motivo>".
BEGIN { FS = "\t" }
NF == 0 { next }
{
  c = $4
  for (i = 5; i <= NF; i++) c = c "\t" $i
}
$1 == "I" {
  n = split(c, seg, ";")
  for (j = 1; j <= n; j++) {
    if (match(seg[j], /import[ \t]+(static[ \t]+)?org\.openqa\.[A-Za-z0-9_.]+/)) {
      t = substr(seg[j], RSTART, RLENGTH)
      sub(/.*\./, "", t)
      if (t != "" && t != "By") sel[$2 SUBSEP t] = 1
    }
  }
  next
}
$1 == "L" { k++; fa[k] = $2; li[k] = $3; co[k] = c; next }
{ malo = 1 }
END {
  if (malo) exit 3
  for (x = 1; x <= k; x++) {
    n = split(co[x], tok, "[^A-Za-z0-9_]+")
    for (j = 1; j <= n; j++) {
      if (tok[j] == "openqa" || ((fa[x] SUBSEP tok[j]) in sel)) {
        print fa[x] ":" li[x] ": " r ": " m
        break
      }
    }
  }
}
```

*Casos de autoprueba.* Cada archivo empieza con `package com.demo.prueba;` en la línea 1:
- **Casos de una línea:** la línea va en la 2, con `violation` o `allowed`, como en *Firmas expuestas*.
- **Casos de dos líneas:** el import va en la 2 y la declaración en la 3, con un ayudante nuevo. La línea esperada es `archivo:3: R<n>: motivo`.
- **`ok-29`:** son dos archivos en el mismo caso.
- Todos se ejecutan en sus dos modos (versionado y sin versionar).

Son 22 casos negativos y 7 permitidos, es decir, 58 ejecuciones, más 2 casos de error: 340 en total. Los casos vigentes no cambian.

```java
// ===== Deben fallar (violation) =====
// R1-imp · R1 · transport/Bad.java · línea 3 · subpaquete, fuera de la lista cerrada de D7-03
import org.openqa.selenium.remote.RemoteWebDriver;
    public RemoteWebDriver remoto() {
// R1-imp-b · R1 · transport/Bad.java · línea 3 · parámetro
import org.openqa.selenium.Alert;
    public void aceptar(Alert alerta) {
// R1-imp-c · R1 · transport/Bad.java · línea 3 · import static de un tipo anidado
import static org.openqa.selenium.WebDriver.Timeouts;
    public Timeouts tiempos() {
// R1-imp-d · R1 · transport/Bad.java · línea 3 · argumento de tipo
import org.openqa.selenium.Cookie;
    public java.util.Set<Cookie> cookies() {
// R1-imp-e · R1 · transport/Bad.java · línea 3 · anotación y protected (EXP)
import org.openqa.selenium.Dimension;
    @Deprecated protected Dimension tamano() {
// R1-imp-f · R1 · transport/Bad.java · línea 3 · tres imports en una línea: Selenium ni va primero ni es el único
import java.util.List; import org.openqa.selenium.Alert; import org.openqa.selenium.Point;
    public Point posicion() {
// R1-imp-g · R1 · transport/Bad.java · línea 2 · nombre calificado, sin import
    public org.openqa.selenium.Alert alerta() {
// R1-imp-h · R1 · transport/Bad.java · línea 3 · throws
import org.openqa.selenium.NoSuchElementException;
    public void pulsar(By localizador) throws NoSuchElementException {
// R1-her · R1 · transport/Bad.java · línea 3 · extends de paquete
import org.openqa.selenium.chrome.ChromeDriver;
final class Bad extends ChromeDriver {
// R1-her-b · R1 · transport/Bad.java · línea 3 · implements expuesto
import org.openqa.selenium.WebDriver;
public final class Bad implements WebDriver {
// R1-her-c · R1 · transport/Bad.java · línea 3 · Selenium como argumento de tipo de una interfaz de Java
import org.openqa.selenium.WebDriver;
final class Proveedor implements java.util.function.Supplier<WebDriver> {
// R1-her-d · R1 · transport/Bad.java · línea 2 · nombre calificado, sin import
final class Bad extends org.openqa.selenium.remote.RemoteWebDriver {
// R1-her-e · R1 · transport/Bad.java · línea 3 · cláusula en su propia línea
import org.openqa.selenium.JavascriptExecutor;
        implements JavascriptExecutor {
// R1-wild · R1 · transport/Bad.java · línea 2
import org.openqa.selenium.*;
// R1-wild-b · R1 · transport/Bad.java · línea 2 · static
import static org.openqa.selenium.support.ui.ExpectedConditions.*;
// R1-by · R1 · transport/Bad.java · línea 2 · retorno
    public By localizador() {
// R1-by-b · R1 · transport/Bad.java · línea 2 · campo
    public static final By TITULO = By.className("title");
// R1-by-c · R1 · transport/Bad.java · línea 2 · herencia de una clase expuesta
public final class Bad extends By {
// R1-by-d · R1 · transport/Bad.java · línea 2 · argumento de tipo, protected
    protected java.util.List<By> localizadores() {
// R5-ext · R5 · actions/Bad.java · línea 2
public final class Bad extends CartPage {
// R5-ext-b · R5 · utils/Bad.java · línea 2
public final class Bad extends ConfigResolver {
// R5-ext-c · R5 · transport/Bad.java · línea 2 · también una excepción propia
final class Bad extends RuntimeException {

// ===== Deben pasar (allowed) =====
// ok-28 · transport/Otro.java · líneas 2 y 3 · token completo, no subcadena
import org.openqa.selenium.WebDriver;
    public String nombreWebDriver(By localizador) {
// ok-29 · transport/A.java (líneas 2 y 3) y transport/B.java (línea 2) · nombres por archivo: B tiene su propio Alert
import org.openqa.selenium.Alert;
    private Alert alerta;
    public Alert alerta() {
// ok-30 · transport/Otro.java · líneas 2 y 3 · interfaz de Java
import org.openqa.selenium.WebDriver;
public final class Cierre implements AutoCloseable {
// ok-31 · actions/OtraActions.java · implements de una interfaz de Java en actions
public final class OtraActions implements java.util.function.Supplier<String> {
// ok-32 · utils/Otro.java · identificadores que contienen extends
        boolean noextends = extendsMenu;
// ok-33 · transport/Otro.java · comodín de Java
import java.util.*;
// ok-34 · transport/Otro.java · líneas 2 y 3 · identificadores que contienen implements y extends, con un nombre importado
import org.openqa.selenium.WebDriver;
        WebDriver noimplements = extendsX;
```

*Casos de error* (exit 2, con su mensaje):
- `error-awk`: un awk falso en el `PATH` que sale con 3 (con un shim, como el de `git`). Debe dar 2 y la línea `re:^check-layers: ERROR: awk terminó con 3 `.
- `error-her`: el shim de `git` sale con 2, sin escribir en stderr, solo cuando sus argumentos contienen `implements`, que solo aparece en `HER`. Debe dar 2 y `check-layers: ERROR: git grep terminó con 2 (R1: transport hereda o implementa un tipo de Selenium)`. Demuestra que la unión pasa por el ejecutor con guardas, y no solo los `check` anteriores.

*Mutantes que deben morir* (sabotaje de devops). Los de awk solo los puede ejecutar devops; los de `git grep` se comprobaron sobre este ADR (*Enmiendas*).

| Mutante | Casos que lo matan |
|---|---|
| U1. Sin `R1-imp` | `R1-imp` a `-h` |
| U2. Candidatas de `R1-imp` con `^\s*public\b` en lugar de `EXP` | `R1-imp-e` |
| U3. `IMP` anclado al principio de la línea (`^\s*import`) | `R1-imp-f` |
| U4. Solo el primer import de cada línea (sin recorrer los segmentos) | `R1-imp-f` |
| U5. Sin `(?:static\s+)?` en `IMP` o en el awk | `R1-imp-c` |
| U6. Sin el token `openqa` | `R1-imp-g` y `R1-her-d` |
| U7. El nombre es el primer segmento tras `org.openqa.` y no el último | Todos los casos de `R1-imp` y `R1-her` con import |
| U8. Comparación por subcadena en lugar de token completo | `ok-28` |
| U9. Nombres de toda la capa, sin el archivo en la clave | `ok-29` |
| U10. `By` entra en la lista | `valido` (`public void click(By locator)` del árbol base) |
| U11. Toda línea es candidata | `valido` (`private WebDriver driver;` y los propios imports) |
| U12. Sin `R1-her` | `R1-her` a `-e` |
| U13. `HER` sin `extends` | `R1-her` y `R1-her-d` |
| U14. `HER` sin `implements` | `R1-her-b`, `-c` y `-e` |
| U15. Sin el `\b` inicial o sin el final de `HER` | `ok-34` |
| U16. `R1-her` sin unión: toda línea de herencia es violación | `ok-30` |
| U17. No se comprueba el código de salida de awk | `error-awk` |
| U18. La unión no usa el ejecutor con guardas | `error-her` |
| W1. Sin `R1-wild` | `R1-wild` y `-b` |
| W2. `R1-wild` sin `(?:static\s+)?` | `R1-wild-b` |
| W3. `R1-wild` sin `org\.openqa\.` (cualquier comodín) | `ok-33` |
| B1. Sin `R1-by` | `R1-by` a `-d` |
| B2. En `R1-by`, `[^(]*` pasa a `.*` | `valido` y `ok-28` |
| B3. `R1-by` con `^\s*public\b` en lugar de `EXP` | `R1-by-d` |
| X1. Sin `R5-ext` | `R5-ext` a `-c` |
| X2. `R5-ext` sin `transport`, sin `actions` o sin `utils` | `R5-ext-c`, `R5-ext` o `R5-ext-b` |
| X3. `R5-ext` busca también `implements` | `ok-30` y `ok-31` |
| X4. Sin el `\b` inicial o sin el final de `R5-ext` | `ok-32` |

Cambiar la avidez de un cuantificador es equivalente, igual que en *Firmas expuestas*.

*Riesgo residual aceptado (D6, R-5):*
- firmas expuestas partidas en varias líneas: solo se ve la línea con el modificador de acceso;
- un tipo de Selenium que llegue por otra biblioteca, fuera de `org.openqa` (P-06 exige un ADR antes de agregarla);
- herencia en `src/main` (ver la Decisión 2).

*Falsos positivos, que fallan cerrado:*
- una línea expuesta de `transport` con un cuerpo que use un nombre de Selenium o un método importado con `static`;
- `org.openqa.selenium.By` calificado como parámetro: se importa;
- un import de `org.openqa` dentro de un comentario o de una cadena, que agrega su nombre a la lista;
- un comentario o una cadena con `extends` en `transport`, `actions` o `utils` (D6: los comentarios cuentan como texto);
- límites genéricos y excepciones propias en esas tres capas (ver la Decisión 2).

**Nota de ejecución** (`scripts/check-layers.sh:11-39`, `:103-128`; eran `:10-38` y `:93-118` antes de la enmienda sobre `ResultadoClic`):
- **Dos pasadas por comando.** Cada `git grep` corre con `--untracked` (lo no versionado, respetando `.gitignore`) y sin él (los archivos del índice), y los resultados se unen sin duplicados. Motivo: con git 2.53, `--untracked` recorre el árbol de trabajo sin leer el índice y omite los archivos versionados que coinciden con `.gitignore`.
- **stderr es error.** Con un archivo ilegible, `git grep` imprime "failed to stat" y aun así termina con 0 o 1. Por eso cualquier texto en su stderr da 2.
- **Códigos de salida:**
  - 0: sin violaciones;
  - 1: violaciones, una por línea, como `archivo:línea: R<n>: motivo`. Un directorio de capa sin archivos versionados se imprime como `directorio:0: D6: motivo`: es una violación de la estructura, no un error de la herramienta;
  - 2: no se pudo evaluar (falla cerrado). Ocurre con argumentos de más, una raíz que no es un directorio o no es la raíz de un repositorio, `git grep` con rc ≥ 2 o con texto en stderr, o un error de `git ls-files`.
- **22 comprobaciones** (21 antes de la enmienda sobre `ResultadoClic`):
  - los 19 `git grep` originales de D7 (`D7-01`…`D7-19` en la autoprueba);
  - el de R3 para parámetros (`R3-param`);
  - el de `ResultadoClic` en páginas (`D1-rc`);
  - el `git ls-files` de directorios (`D7-20`).
- **24 comprobaciones** desde la enmienda *Firmas expuestas*: las 22 anteriores, `R1-tipos` y `R3-tipos`. Desde esa enmienda, el script se cita por nombre (su cabecera y la función `check`), no por línea.
- **29 comprobaciones** desde la enmienda *Selenium en el transporte y herencia*: las 24 anteriores, `R1-wild`, `R1-by`, `R1-imp`, `R1-her` y `R5-ext`.
  - `R1-imp` y `R1-her` unen dos `git grep` con awk (*Unión por imports*).
  - Si awk termina con un código distinto de 0, CHK-17 da 2 y el mensaje nombra awk, la regla y el motivo.
- **Límite de PCRE.** Si una expresión agota el límite de backtracking de PCRE, `git grep` escribe `match limit exceeded` en stderr, y CHK-17 da 2: falla cerrado, nunca abierto. Las siete expresiones de *Firmas expuestas* recorren todos los archivos versionados sin agotarlo (enmienda *Firmas expuestas*), y las cinco nuevas de *Selenium en el transporte y herencia* también (su enmienda).

### D8. Configuración pura del navegador en `src/main` (paso independiente)

Cierra el otro pendiente heredado del ADR-001.
- **Qué pasa a `src/main/java/com/demo/config`.** La lógica pura de `DriverFactory`, con el nombre orientativo `BrowserSettings` y sus valores como parámetros (ADR-001, D2):
  - normalización y validación del navegador (`DriverFactory.java:30-41`);
  - URL remota (`:99-110`);
  - argumentos por navegador y modo (`:71-77`, `:88-91`).
- **Qué queda en `DriverFactory`:** solo traduce `BrowserSettings` a `ChromeOptions` o `FirefoxOptions` y crea el driver.
- **Motivo:** CI nunca ejecuta Firefox, el Grid ni el tamaño de ventana (*Contexto*).
- **Coste:** una clase y sus pruebas unitarias, dentro del alcance que ya tienen:
  - PIT: `targetClasses` `com.demo.*` y `targetTests` con `com.demo.config.*Test` (`pom.xml:29`, `:210-213`);
  - Surefire (`pom.xml:188`);
  - CHK-15 y CHK-16.

  No cambia el POM ni las pruebas existentes del ADR-001.
- **Restricción:** el ancho y el alto se leen solo en modo headless, como hoy (`:72-77`).
- **Ajustes de Chrome contra interferencias del propio navegador** *(enmienda 2026-10-13, parte 3)*. `BrowserSettings` también decide, como lógica pura, qué ajustes recibe Chrome, y `DriverFactory` solo los traduce:
  - **`--disable-component-update`**, en los argumentos de Chrome (`8d7ce8b`, registrado en D1 con el contrato de `abrir`).
  - **`chromePreferences()`** (`3bab4b2`): para Chrome devuelve `profile.password_manager_leak_detection=false`; para Firefox, un mapa vacío; es inmutable. `DriverFactory` la aplica con `ChromeOptions.setExperimentalOption("prefs", …)`.
    - **Motivo:** tras el inicio de sesión, la comprobación de contraseñas filtradas de Chrome abre un aviso que en headless no se ve y que, mientras está abierto, descarta los clics y las teclas nativos dirigidos a la página. Era la causa de los clics que terminaban en el respaldo JavaScript de D1 (`MEMORY.md` la tenía como "sin aislar").
    - **Evidencia** (engineer; no se ejecutó aquí, B-01). Según el coordinador, los clics con respaldo pasaron de 36 de 153 a 0 de 156 en Chrome local, con carga y sin ella, y en el Grid. Según el mensaje de `3bab4b2`: un A/B intercalado dio 0 de 6 clics con respaldo con la preferencia, frente a 3 de 6 sin ella; CHK-08 ×2 con `Tests run: 189, Failures: 0, Errors: 0, Skipped: 1`; PIT 132/132.
    - **Pruebas:** tres pruebas unitarias nuevas en `BrowserSettingsTest` (`chromeDisablesPasswordLeakDetectionInEveryMode`, `firefoxHasNoChromePreferences` y `chromePreferencesAreImmutable`), dentro de PIT (CHK-11).
    - **Límite:** las pruebas unitarias fijan el nombre y el valor de la preferencia, pero no pueden probar que Chrome la respete. Chrome ignora en silencio una preferencia que no reconoce. Si una versión futura la renombra, solo lo detecta la E2E, y solo si nada tapa el síntoma: por eso se retira el respaldo JavaScript del clic (*Enmiendas*, *Preferencias de Chrome y respaldo JavaScript*).

## Alternativas consideradas

| Alternativa | Motivo del descarte |
|---|---|
| No hacer nada y vigilar la estructura actual con `git grep` | R1 necesitaría excepciones en 3 paquetes; las páginas seguirían con `WebDriver`, R5 dependería de la revisión y R3 no existiría. Con 4 páginas, el coste de D1 es bajo |
| Interfaz de transporte con implementación Selenium y tipo `Locator` propio, preparada para Playwright | Es especulativo (SDD-02). Una interfaz derivada de Selenium arrastra su modelo de sincronización y los respaldos de Chrome y React (`BasePage.java:72-125`), así que no aislaría un cambio de motor. Además duplica el vocabulario de localizadores, y Pico necesitaría un proveedor |
| Probar las páginas sin navegador, con un transporte falso | Casi no tienen lógica (`InventoryPage.java:33`, `:40-48`), y un falso verifica secuencias de llamadas, no comportamiento. Es el mismo motivo por el que el ADR-001 descartó Mockito |
| Mover `BasePage` a `transport` y mantener la herencia | Las páginas heredarían el acceso al driver, y R5 seguiría dependiendo de la revisión |
| Conservar `PageManager` junto a las acciones | Repite lo que Pico ya hace y suma un punto de registro por página |
| Acciones que leen la configuración y eligen los datos | Acopla las acciones a los datos de prueba y no sirve para los AC con datos parciales (AC-COMPRA-10…12). Leer un esperado rompería CHK-10 |
| Patrón Screenplay (actores, tareas, preguntas) | Desproporcionado para 5 escenarios y 2 flujos |
| ArchUnit | Ver D6. Queda un disparador para reconsiderarlo, con las reglas equivalentes escritas en D7 |
| Renombrar `utils` o mover las fachadas a `config` y `data` de pruebas | Ver D5 |
| Conservar el `ThreadLocal` | Deja dos dueños para un mismo recurso, cuando el contenedor por escenario ya aísla |

## Consecuencias

- **Positivas:**
  - Selenium pasa de 8 archivos en 3 paquetes a `transport` más un `import` de `By` por página.
  - R5 y la superficie de PI-05 quedan estructurales.
  - Los steps describen intención, y la autenticación duplicada y los flujos entre páginas quedan en `actions`. Un cambio de flujo de la interfaz se absorbe en `actions` o `pages`.
  - R1–R6 se verifican en segundos, sin dependencias nuevas; el arquitecto también puede ejecutarlas (B-01).
  - Se cierran la deuda de las páginas con `WebDriver` y los tres pendientes del ADR-001.
- **Costes:**
  - Hay una indirección más para 5 escenarios. Se compensa con los 15 AC pendientes, que reutilizan los mismos flujos.
  - En clases, el saldo es +3 (`Navegador` y 2 de acciones) y −2 (`BasePage` y `PageManager`).
  - Existe riesgo de regresión en la sincronización (R-2).
  - Un control textual tiene puntos ciegos (D6).
  - Hay que actualizar 12 archivos de reglas, agentes y documentación (*Cambios propuestos*). Diez solo los puede aplicar el usuario.
- **Sin cambios:**
  - features, textos de los steps y claves de configuración;
  - POM;
  - pruebas unitarias y configuración de PIT del ADR-001.

## Cambios propuestos a reglas y agentes (aplicados)

Todos están aplicados al cierre; no queda ninguno pendiente. Las líneas de la columna *Archivo* son las del 2026-10-09. *Estado* cita el commit que aplicó cada cambio, o "pendiente de commit" si al escribir el cierre solo estaba en el árbol de trabajo.

| Archivo | Cambio | Cuándo | Estado |
|---|---|---|---|
| `.claude/rules/04-quality-checks.md` (tabla tras `:22`, comandos tras `:60`, *Estado actual* `:69`) | CHK-17 "Capas (ADR-002): R1–R6": `bash scripts/check-layers.sh` y `bash scripts/tests/check-layers-test.sh`. Pasa con exit 0; la ejecutan engineer, verifier y devops | Antes del paso 3 | Aplicado (`709c81d`) |
| `.claude/rules/04-quality-checks.md:9`, `:32` | CHK-03 busca `org\.openqa` (`git grep -nE`) en lugar de `import org.openqa.selenium`, para detectar `import static` y los nombres calificados | Con el paso 0 | Aplicado (`4159952`) |
| `.claude/rules/04-quality-checks.md:57` y `scripts/check-unit-purity.sh:41` (devops) | CHK-16 agrega `transport` y `actions` a la lista de paquetes `com.demo.*` prohibidos: las unitarias tampoco pueden nombrar las capas nuevas | Antes del paso 3 | Aplicado (script en `f7f7a13`; regla en `709c81d`) |
| `.claude/rules/01-spec-driven-development.md:12-13` | Agregar `com.demo.utils` (fachadas de E/S y estado del escenario) al nivel 4, y una nota: "las dependencias entre paquetes las fija el ADR-002 (CHK-17); los niveles SDD no son las capas del arquitecto" | Con el paso 0 | Aplicado (`4159952`) |
| `.claude/rules/02-agent-permissions.md:11` | El verifier también ejecuta `scripts/check-layers.sh` y su autoprueba, que solo escribe en un directorio temporal fuera del repo | Antes del paso 4 | Aplicado (`709c81d`) |
| `.claude/agents/qa-automation-architect.md:3`, `:22`, `:38-39`, `:57`, `:62`, `:67`, `:69` | Cambiar "reglas ArchUnit" por "CHK-17 (`git grep`), con ArchUnit solo como equivalente documentado (ADR-002, D6)" | Con el paso 0 | Aplicado (`4159952`) |
| `.claude/agents/qa-automation-architect.md:28-34` | Columna *Depende de* según D4; `utils` en la capa 4 | Con el paso 0 | Aplicado (`4159952`) |
| `.claude/agents/qa-automation-architect.md:48-54`, `:56` | R1–R7 en su forma de D7, con la excepción de `By` permanente; retirar "el siguiente pendiente es el ADR-002" | Al cerrar el paso 4 | Aplicado (`257baaa`) |
| `.claude/agents/qa-automation-engineer.md:22`, `:34`, `:39` | Quitar ArchUnit; "toda interacción pasa por `Navegador`"; CHK-17 en la autoverificación | `:22` con el paso 0; el resto al cerrar el paso 3 | Aplicado (`4159952`, `475651f` y `709c81d`) |
| `.claude/agents/qa-test-verifier.md:33` | CHK-17 junto a CHK-01/02/03 (rechazo automático) | Al cerrar el paso 3 | Aplicado (`709c81d`) |
| `.claude/agents/devops-engineer.md:45`, `:46` | Rutas CRÍTICAS: agregar `src/test/java/com/demo/transport/` (escribe credenciales y ejecuta scripts) y `scripts/check-layers.sh`; CHK-17 en el paso 3 del gate | Al cerrar el paso 3 | Aplicado (`709c81d`) |
| `.claude/agents/README.md:5`, `:16`, `:34`, `:52` | Cambiar "ArchUnit" por "CHK-17"; "CHK-01…17"; deuda de `WebDriver` cerrada | Al cerrar el paso 4 | Aplicado (`:16` en `709c81d`; `:5`, `:34` y `:52` en `257baaa`) |
| `AGENTS.md:22`, `:26`, `:30-32`, `:43`, `:45` | "CHK-01…17"; ADR-002; estructura con `transport/` y `actions/`, sin `BasePage` ni `PageManager`; "los steps solo usan acciones; las páginas solo interactúan a través de `Navegador`" | Al cerrar el paso 2 | Aplicado (`475651f` y `709c81d`) |
| `CLAUDE.md:19` | "CHK-01…17" | Antes del paso 3 | Aplicado (`709c81d`) |
| `README.md:37-81`, `:83-142`, `:146-162`, `:170`, `:394`, `:406`, `:437` | Diagrama, estructura, decisiones (`ThreadLocal`, `PageManager`, esperas en `Navegador`) y lista de revisión. No tiene dueño en la matriz (igual que en el ADR-001): el usuario designa quién lo edita | Al cerrar el paso 2 | Aplicado (`475651f` y `709c81d`) |

## Plan de implementación

Cada paso deja la suite en verde. Cada paso del engineer pasa por el verifier y el gate antes del siguiente (`CLAUDE.md`, *Coordinación*).

| Paso | Dueño | Qué | Verde si | Estado |
|---|---|---|---|---|
| 0 | Usuario, vía coordinador | Aprueba el ADR y los cambios a reglas y agentes | — | Hecho (`4159952`) |
| 1 | `qa-automation-engineer` | Transporte (D1, D2): `Navegador`; `DriverFactory` en `transport`, sin `ThreadLocal`; páginas por composición; se retira `BasePage`; `Hooks` y `TestContext` sin Selenium. `PageManager` recibe `Navegador`, y **los steps no cambian** | CHK-01, 03 y 07; CHK-08 ×2 con el mismo `Tests run` que antes del paso; CHK-09 y CHK-10 de regresión en los 7 AC; comandos R1, R4, R5 y R6 de D7 para `transport`, `pages`, `hooks` y `utils`; diff de movimiento. Gate CRÍTICO (`DriverFactory`) | Hecho (`0aa3a02`) |
| 2 | `qa-automation-engineer` | Acciones (D3): `LoginActions` y `CompraActions`; steps solo con acciones; se retira `PageManager` | Lo mismo que el paso 1, más R3 y las filas de R6 de `actions` y `steps`; sin cambios en `src/test/resources` | Hecho (`475651f`) |
| 3 | `devops-engineer` | CHK-17 (D6): script y autoprueba; GitHub Actions y Jenkins antes de la suite; gate. Puede prepararse en paralelo a los pasos 1 y 2, pero se conecta al CI cuando HEAD pasa | El script da 0 sobre HEAD; la autoprueba da 0 con todos sus casos negativos en 1; CHK-13 | Hecho (`f7f7a13`) |
| 4 | `qa-test-verifier` | Criterio de verificación completo | APROBADO | Hecho (APROBADO sobre `f7f7a13`; sus P1 de la autoprueba, cerrados en `bb7f145`) |
| 5 | `qa-automation-engineer` | `BrowserSettings` (D8) con pruebas unitarias; `DriverFactory` solo traduce | CHK-07, 08, 15, 16 y 17; CHK-11 ≥ 80 % con la guarda en 0; D6 del ADR-001 sigue en `BUILD FAILURE`; APROBADO del verifier; gate CRÍTICO (`src/main/java/com/demo/config/`) | Hecho (`32f5b36`) |

## Criterio de verificación

```bash
# CHK-17 y su autoprueba (desde el paso 3; antes, los comandos de D7, cada uno sin salida)
bash scripts/check-layers.sh
bash scripts/tests/check-layers-test.sh
# CHK-08 dos veces, con el mismo Tests run que antes del paso 1
./mvnw -B -ntp clean test -Dheadless=true -Dcucumber.filter.tags="not @quarantine"
# Paso 1: la sincronización se movió sin cambios (los bloques de BasePage.java:72-125 aparecen como movidos)
git diff -M --color-moved=zebra --color-moved-ws=allow-indentation-change <base>..HEAD -- src/test/java/com/demo
# Pasos 1 y 2: sin cambios en features ni en configuración (sin salida)
git diff --stat <base>..HEAD -- src/test/resources
```

**CHK-10 de regresión** en cada paso de engineer. Se usa `-D<clave>=__CONTROL_NEGATIVO__`, salvo en los contadores: `getPositiveInt` rechaza texto, así que llevan un entero positivo distinto, por ejemplo `9`. Cada ejecución debe fallar con `AssertionFailedError` en el `Then` indicado:

| AC | Clave | `Then` que falla |
|---|---|---|
| AC-LOGIN-01 | `inventory.expected.title` | accede al inventario |
| AC-LOGIN-02 | `test.login.cases.locked-user.expected-error` | el acceso es rechazado… |
| AC-LOGIN-03 | `test.login.cases.invalid-password.expected-error` | el acceso es rechazado… |
| AC-COMPRA-01 | `cart.expected.count` (`9`) | el carrito refleja la cantidad… |
| AC-COMPRA-02 | `cart.expected.products` | el carrito contiene… |
| AC-COMPRA-03 | `checkout.expected.confirmation` | la compra se confirma… |
| AC-COMPRA-04 | `cart.expected.single-product.count` (`9`) y, aparte, `cart.expected.single-product.products` | el `Then` correspondiente |

**Además:**
- La autoprueba tiene al menos un caso negativo por comando de D7 y uno por directorio de capa ausente; el verifier lo comprueba leyéndola.
- `Navegador` cumple tres condiciones:
  - el primer argumento de `executeScript` es una constante;
  - ningún log ni mensaje incluye el texto escrito;
  - antes de `iniciar()` falla con un mensaje claro.
- El reporte de PIT sigue listando solo clases de `com.demo.config` y `com.demo.data`.

## Riesgos

Este ADR se escribió sin ejecutar nada: solo se leyeron archivos y se buscó con `git grep` (B-01). El estado de R-1 a R-8 refleja el cierre tras los pasos 1 a 5 y las enmiendas posteriores (*Enmiendas*). Solo siguen abiertos como P2 R-4 (solo Jenkins) y R-8.

| # | Supuesto | Lo confirma | Si es falso |
|---|---|---|---|
| R-1 | Pico construye `Navegador`, páginas y acciones de forma transitiva, con una instancia por escenario compartida por `Hooks` y las acciones. Hoy ya lo hace con `TestContext` y `PageManager` | engineer, paso 1: CHK-08. **Confirmado** (pasos 1 y 2): Pico construye `Navegador` (`Navegador.java:44`), las páginas (`LoginPage.java:19`), las acciones (`LoginActions.java:18`, `CompraActions.java:20`) y `Hooks` (`Hooks.java:16`) con el glue sin cambios (`RunnerTest.java:15`), y la suite queda en verde. Lo ratifica la verificación completa (paso 4). Si la instancia no fuera compartida, las páginas fallarían con `IllegalStateException` por usarse antes de `iniciar()` (`Navegador.java:156-160`) | Falla de forma visible al empezar el escenario. Se conserva una fábrica por escenario al estilo `PageManager`, por enmienda |
| R-2 | Mover `BasePage.java:72-125` sin cambios conserva la estabilidad en Chrome y React | verifier: diff de movimiento y CHK-09; devops: CHK-08 ×2. **Confirmado** (pasos 1 y 2): CHK-08 ×2 y los 7 AC en verde por separado en el paso 1 (`0aa3a02`), y CI en verde sobre `475651f`, según el usuario. Paso 4: los 7 AC en verde por separado y los 8 controles negativos en rojo en el `Then` | Se revierte el paso y se diagnostica; nunca se agregan reintentos ni esperas fijas (CHK-01, CHK-02) |
| R-3 | Sin `ThreadLocal`, el aislamiento depende de que cada escenario corra en un hilo con su propio contenedor. Es cierto en serie, que es el modo actual | devops, en el paso de paralelismo. **Cerrado** (`caf2fa0`): paralelismo por escenario activo, con 2 hilos y `max-pool-size=2` (`junit-platform.properties`). La independencia se verificó con CHK-08 cinco veces en paralelo, 122/122, sin fallos, y el run de GitHub Actions sobre `a66e8ce` terminó en verde (según el usuario). `Navegador` es seguro sin `ThreadLocal` porque hay uno por escenario | Se reintroduce el aislamiento dentro de `Navegador`, por enmienda |
| R-4 | Las expresiones de D7 funcionan con `git grep -P` y `--untracked`, con exclusiones `:!`, en local, GitHub Actions y Jenkins. CHK-01 ya usa `-P` | **Confirmado en GitHub Actions (run de `257baaa`, verde); Jenkins sin servidor real para validar.** Según el usuario (2026-10-10), ese run incluye CHK-17 (`check-layers.sh` y su autoprueba) en el job `mutation`. Antes, en local (paso 3, git 2.53.0, 2026-10-10): el 2026-10-09 los comandos solo marcaban la deuda que resolvieron los pasos 1 y 2. Una ruta inexistente da rc=1 sin salida, y por eso D6 exige los directorios. Ahora, en local: devops informa la autoprueba con exit 0 en sus 81 casos (154 desde `bb7f145` y 162 desde `a66e8ce`) y el script con 0 sobre HEAD. El arquitecto ejecutó los 20 `git grep` sobre `f7f7a13`, con `--untracked` y con `--cached`: todos dan rc=1, sin salida, y cada directorio de capa lista archivos. Hallazgo: con git 2.53, `--untracked` omite los archivos versionados que coinciden con `.gitignore`, de ahí la doble pasada (D7, *Nota de ejecución*). Al cierre, el arquitecto repitió los 20 `git grep` de D7 con las dos pasadas sobre el árbol de trabajo del paso 5: todos dan rc=1, sin salida. **Abierto (P2), solo Jenkins:** el primer run en un servidor real, que imprime `git --version` en la etapa `Capas (CHK-17)` (`Jenkinsfile:27` en `f7f7a13`) | Se ajusta la sintaxis en el script; la autoprueba es la especificación ejecutable |
| R-5 | Las firmas públicas ocupan una línea, como en el estilo actual (`CheckoutPage.java:21`) | Revisión del verifier. **Se cumple hoy** (paso 4); sigue como riesgo residual aceptado (D6) | Una firma partida evade la regla de firmas, lo que activa el disparador de ArchUnit (D6) |
| R-6 | Las ramas de Firefox y Grid se mueven sin cambios en el paso 1, aunque CI no las ejecuta | D8 cubre la parte pura: `BrowserSettings`, con 27 pruebas unitarias y PIT (paso 5). **Cerrado** (`e6e91bc`): los jobs `e2e-firefox` y `e2e-grid` (`selenium/standalone-chrome:4.45.0`) de `ci.yml` ejecutan la traducción a `Options` de `DriverFactory`, ambos en headless, y el run de GitHub Actions sobre `a66e8ce` terminó en verde (según el usuario). Antes, la revisión del paso 5 halló un desvío en esa traducción: Firefox sin headless enviaba `args=[]`, y se restauraron sus capacidades | Prueba manual opcional de devops, con `-Dbrowser=firefox` y `docker compose` |
| R-7 | Los reportes de Cucumber, Allure y Surefire no cambian, porque el glue no cambia | devops: CHK-08 y artefactos. **Confirmado** (pasos 1 y 2): `git diff --stat 4159952 HEAD -- src/test/resources src/test/java/com/demo/runners pom.xml` no tiene salida. La captura ante un fallo pasa por `Navegador.capturarPantalla()` y se adjunta como antes (`Hooks.java:25-34`); el paso 1 la comprobó intacta (`0aa3a02`) | Se diagnostica antes de continuar |
| R-8 | Los 15 AC pendientes caben en las dos clases de acciones, como mucho con una página nueva (menú o cierre de sesión) | Al responder las Q-*. **Abierto (P2):** pendiente de las Q-* | Se agrega una clase de acciones por flujo; el diseño no cambia |

## Enmiendas

### 2026-10-10 — Pasos 1 a 3 (commits `0aa3a02`, `475651f` y `f7f7a13`)

Las decisiones de fondo y el estado no cambian.
- **Pasos 1 y 2** (`qa-automation-engineer`):
  - `Navegador` es el único dueño del `WebDriver`, y las páginas lo componen e importan solo `By`.
  - `LoginActions` y `CompraActions` quedan entre los steps y las páginas.
  - Se retiran `BasePage` y `PageManager`.
  - R-1, R-2 y R-7 quedan confirmados (*Riesgos*).
- **Paso 3** (`devops-engineer`):
  - `scripts/check-layers.sh` y su autoprueba, con 81 casos.
  - CHK-16 suma `transport` y `actions` en `scripts/check-unit-purity.sh`.
  - El control negativo sobre `0aa3a02`, anterior a las acciones, da rc=1: marca R3 en los dos steps y `actions:0: D6`.
- **D7 se alinea con el script**, que iba más allá de la redacción original:
  - R3 también rechaza páginas como parámetro de los métodos públicos de `actions`, con los constructores exceptuados (P2 del verifier).
  - Se documentan la doble pasada, stderr como error y los códigos 0, 1 y 2 (*Nota de ejecución*).
  - D6 declara el script como implementación normativa.
- **Ubicación en CI (corrige D6):**
  - En GitHub Actions, CHK-17 corre en el job `mutation`, en paralelo a la suite, porque el job `test` expone los secrets `TEST_*` a todos sus pasos (`env` a nivel de job; lo explica el comentario que precede al job `mutation`, `ci.yml:66-69` en `f7f7a13`).
  - En Jenkins corre antes de la suite.
- **Pendientes:**
  - el primer run remoto, que cierra R-4;
  - el paso 4 (verifier) y el paso 5;
  - los cambios a reglas y agentes. Los programados hasta el paso 3 están en `4159952` y `475651f`, o en el árbol de trabajo sin commit al escribir esta enmienda. Quedan los del cierre del paso 4.

### 2026-10-10 — Pasos 4 y 5 y cierre

Las decisiones de fondo y el estado no cambian. Con este cierre, el ADR queda **completamente implementado**.
- **Autoprueba corregida** (`bb7f145`):
  - Las dos mutantes que el paso 3 dio por equivalentes fallaban abierto. Sin la rama `rc >= 2`, un `git grep` que muere por señal sin escribir en stderr daba `ok`. Sin la comprobación de raíz, una subcarpeta con su propio árbol de capas daba `ok`.
  - Ahora la autoprueba tiene 154 casos (162 desde `a66e8ce`). Suma un shim de `git` (SIGKILL y `exit 2` sin stderr), el mensaje exacto en los casos de exit 2, el caso anidado y un caso por alternativa de cada expresión, incluidos los 33 paquetes de R6.
  - Un sabotaje con 67 mutantes no dejó ninguna sobreviviente.
  - El script y D7 no cambian: la corrección está solo en la autoprueba.
- **Paso 4** (`qa-test-verifier`): APROBADO sobre `f7f7a13`, con sus P1 cerrados en `bb7f145`.
  - Los 7 AC dan verde por separado, y los 8 controles negativos fallan en el `Then`.
  - CHK-17 da 1 sobre `0aa3a02` (R3).
  - CHK-16, ya ampliada, tiene su control negativo.
  - PIT da 73/73.
- **Paso 5** (D8, `32f5b36`):
  - `BrowserSettings` está en `src/main/java/com/demo/config/`, con 27 pruebas unitarias, y `DriverFactory` solo traduce.
  - PIT da 89/89, y D6 del ADR-001 sigue en `BUILD FAILURE`. Los 4 `requireNonNull`, que PIT no muta, se validaron con control negativo manual.
- **Reglas y agentes:** todos los cambios están aplicados (*Cambios propuestos*).
- **Abiertos (P2):** R-4 (solo Jenkins) y R-8 (Q-*). R-3 y R-6 se cerraron en remoto (enmienda *R-3 y R-6 cerrados en remoto*). Desde el 2026-10-13, también los dos P2 que deja abiertos la enmienda *Firmas expuestas*: la lista cerrada de tipos de R1 en `transport` y el `extends` fuera de `pages`. Los aborda la enmienda *Selenium en el transporte y herencia* (propuesta el 2026-10-13), y se cierran con el commit que la integre junto al script.

### 2026-10-10 — R-4 confirmado en GitHub Actions

- El run de GitHub Actions sobre `257baaa` terminó en verde, con CHK-17 en el job `mutation` (según el usuario): R-4 queda confirmado en remoto, y solo sigue abierto (P2) en Jenkins, sin servidor real para validar. El paso 5 y los cambios a reglas y agentes citan ahora sus commits (`32f5b36` y `257baaa`).

### 2026-10-10 — R-3 y R-6 cerrados en remoto

Las decisiones de fondo y el estado no cambian.
- **R-3** (`caf2fa0`): paralelismo por escenario con 2 hilos; CHK-08 cinco veces en paralelo, 122/122, sin fallos.
- **R-6** (`e6e91bc`): jobs `e2e-firefox` y `e2e-grid` en `ci.yml`.
- El run de GitHub Actions sobre `a66e8ce` terminó en verde en sus 4 jobs (`test`, `e2e-firefox`, `e2e-grid` y `mutation`), según el usuario.
- Incidente: el run de `caf2fa0` falló en `mutation` porque el mantenimiento en segundo plano de git 2.55 dejaba un `.lock` efímero en el `cp -a` de la autoprueba; `a66e8ce` lo desactiva en su entorno aislado y suma 8 casos (162), sin cambiar `check-layers.sh` ni D7.
- Siguen abiertos (P2): R-4 (solo Jenkins) y R-8 (Q-*).

### 2026-10-13 — API de `Navegador`, `XPathLiteral` y referencias estables

El estado del ADR y D1–D8 no cambian. **Enmienda aprobada por el coordinador el 2026-10-13** (Regla 01, nivel 2). La parte 2 (`XPathLiteral`) se redactó como propuesta y queda aprobada con ella, así que el engineer ya puede aplicarla. Las citas `archivo:línea` de esta enmienda son de `afb6693`, salvo que indiquen otra cosa.

**1. API de `Navegador` registrada en D1.**
- La tabla de D1 suma, en filas marcadas, la API pública que agregó `146df90` (2026-10-10, AC nuevos de login y compra):
  - `urlContiene`;
  - `clickYEsperarVisible`, `clickYEsperarVisibleOUrlContiene` y `clickYEsperarInvisible`;
  - `clickYObservarUrlContiene`, con `ResultadoClic`;
  - `apareceEnTiempoMaximo` y `contar`.
- D1 suma también el contrato de `abrir` de `8d7ce8b`.
- **Cambios del árbol del 2026-10-13** (`qa-automation-engineer`, sin commit al redactar), que la tabla y D1 ya reflejan:
  - `contarEstable` sustituye a `contar`;
  - `esVisibleEstable` y `existeEnTiempoMaximo` son nuevos;
  - `ResultadoClic.NO_DISPONIBLE` sustituye a la `IllegalStateException` sin clics. `CartPage.intentarIniciarCheckout` lo acepta solo con el botón presente, y falla cerrado si no existe;
  - el tope de 3 clics;
  - `clickYEsperarInvisible` exige la visibilidad previa;
  - el DEBUG de `abrir`.
  - Además, un cambio privado: `esperarValorEstable` registra en INFO cuántas correcciones hicieron falta, sin el texto escrito.
  - El registro debía corresponder a los blobs `7432d07…` y luego `83ff5b8…` que citó el coordinador, pero ninguno está en la base de objetos (`git diff` y `git show` responden `bad object`), y `git hash-object` no está en B-01. Por eso se registró el archivo leído del árbol tras el segundo aviso. Quien haga el commit confirma que coincide, y su hash completa esta enmienda.
  - **Completado: `0de6962`** (2026-10-13, firmado). Contiene estos cambios en `Navegador`, `CartPage` (`NO_DISPONIBLE` falla cerrado sin el botón) e `InventoryPage` (`BOTONES_QUITAR`).
    - También contiene la extracción estricta del código en `BrowserErrorPage`, con sus pruebas, y un ajuste de `BrowserSettingsTest`.
    - La API pública de `Navegador` en `0de6962` es la de la tabla de D1, incluido `existeEnTiempoMaximo` (`git grep -n "public " 0de6962 -- src/test/java/com/demo/transport/Navegador.java`).
    - `git diff --stat 0de6962 HEAD -- src/test/java/com/demo/transport/Navegador.java src/test/java/com/demo/pages/CartPage.java` no da salida.
    - El verifier lo aprobó, según el coordinador.
- Las condiciones de `Navegador` del *Criterio de verificación* se cumplen en `afb6693` y en el árbol del 2026-10-13, hoy `0de6962`.
  - El primer argumento de cada `executeScript` es una constante o un literal: los de `desplazarA`, `esperarValorEstable` y el respaldo de clic (en `afb6693`, `Navegador.java:161`, `:224`, `:327` y `:355-358`; en el árbol, el respaldo vive en el método privado `pulsar`).
  - `ejecutarScriptConstante` recibe el script por parámetro, pero su único llamador le pasa `SCRIPT_LEER_CODIGO_PAGINA_ERROR`.
  - Se comprueba con `git grep -n -e "executeScript" -e "ejecutarScriptConstante(" -- src/test/java/com/demo/transport`.
- La restricción sobre `ResultadoClic` (D1) se comprueba hoy a mano con su comando, que no da salida.
  - **P2 (`devops-engineer`):** llevarla a CHK-17 como una línea más de la fila de `pages` de R6: `git grep --untracked -nP '^\s*public\b.*\bResultadoClic\b' -- "$T/pages"`, con su caso negativo en la autoprueba.
  - Ese cambio enmienda D7 en el mismo commit (D6).
  - **Cerrado** por la enmienda *R6: `ResultadoClic` fuera de los miembros públicos de las páginas*, en el mismo commit que el script.

**2. `XPathLiteral` (D2): se queda en `pages`, sin ramas especulativas (aprobado por el coordinador, 2026-10-13).**

*Contexto:*
- `146df90` sacó `literalXPath` de `InventoryPage` a `src/test/java/com/demo/pages/XPathLiteral.java` (package-private, `:7-21`). La usan `InventoryPage.agregarProductoAlCarrito` (`:52`) y `CartPage.quitarProducto` (`:66`).
- Tiene tres ramas:
  1. sin `'`, devuelve `'v'` (`:13-15`);
  2. con `'` y sin `"`, devuelve `"v"` (`:16-18`);
  3. con las dos, devuelve `concat(…)` (`:19`).
- Le llegan las claves `test.purchase.*` (`config.properties:50-54`), y ninguna tiene comillas. El catálogo del SUT tampoco (`catalog.expected.products`, `:21`). La E2E solo ejecuta la rama 1, en cada escenario que agrega o quita productos.
- Las ramas 2 y 3 no las ejecuta ninguna prueba. El motivo de D2 ("su defecto produce un selector inválido, es decir, un fallo visible") vale para la rama 1, pero no para estas dos: su defecto queda latente hasta que llegue un dato con comillas, y ningún AC lo pide (SDD-02).

*Opciones:*

| Opción | Veredicto | Motivo |
|---|---|---|
| A. Mover a `src/main/java/com/demo/config`, con pruebas unitarias y PIT | Descartada hoy; es el camino si se activa el disparador | D4 no permite `pages` → `config` (R6, `check-layers.sh:156` en `afb6693`; `:165-166` desde la enmienda sobre `ResultadoClic`): habría que abrir una arista solo para esta clase, con cambios en D7, en el script y en su autoprueba. `config` no es su sitio, porque componer localizadores es de la capa 2. Y probaría dos ramas que ningún dato ni AC necesita (SDD-02) |
| B. Prueba unitaria en `src/test/java/com/demo/pages` | Descartada | R4 rechaza JUnit en `pages`; CHK-16 solo admite unitarias en `config` y `data`; Surefire solo las incluye ahí (`pom.xml:185-190`); y PIT no muta `target/test-classes` (ADR-001, R-1). Serían excepciones en cuatro controles para una función de ocho líneas |
| C. Ejercitar las ramas 2 y 3 desde la E2E | Imposible | Ningún producto del SUT tiene comillas: un dato de entrada con comillas no encuentra producto, así que solo probaría el fallo |
| D. Quitar las ramas 2 y 3 y fallar al instante | **Elegida** | Ver *Decisión* |

*Decisión:*
- `XPathLiteral.de(valor)` solo admite valores sin comilla simple, y los devuelve entre `'…'`.
- Con una `'` lanza `IllegalArgumentException`, con un mensaje que no repite el valor: el dato puede venir de `-D` o del entorno.
- Sigue en `pages`, package-private y sin dependencias nuevas.
- **Por qué:**
  - Es la capa más baja: no abre aristas ni cambia CHK-17.
  - Cumple SDD-02.
  - Vuelve a hacer cierto el motivo de D2. La rama que queda corre en cada escenario que agrega o quita productos, y el control negativo de `cart.expected.*.products` (CHK-10) detecta un selector que agrega otro producto.
  - Un defecto de la guarda también se ve. Si lanza siempre, falla toda la compra. Si no lanza nunca, solo lo nota un valor con `'`, que produce un selector inválido o, si está construido a propósito, otro selector válido. Por eso la guarda tiene su control negativo manual (paso 3).
- **Disparador para reabrir:** una spec o un dato que necesite nombres con `'`. Entonces se aplica la opción A en un solo cambio:
  - la clase pasa a `src/main/java/com/demo/config`, con pruebas y PIT;
  - D4 suma `pages` → `config` (solo `XPathLiteral`);
  - la fila de `pages` de R6 pasa a `com\.demo\.(actions|steps|hooks|runners|data)\b` y `com\.demo\.config\.(?!XPathLiteral\b)`, como la excepción de `ConfigReader` (`check-layers.sh:153-154` en `afb6693`; `:163-164` desde la enmienda sobre `ResultadoClic`), con sus casos en la autoprueba.

*Pasos para `qa-automation-engineer` (cada uno deja la suite en verde):*
1. En `XPathLiteral.java` se eliminan las ramas de `:16-19`.
   - Si `valor` contiene `'`: `throw new IllegalArgumentException("El literal XPath no admite comillas simples (ADR-002, enmienda 2026-10-13)")`.
   - Si no, devuelve `"'" + valor + "'"`.
   - Se actualiza el Javadoc. Las llamadas de `InventoryPage` y `CartPage` no cambian.
2. Comprobaciones:
   - CHK-01, CHK-03, CHK-07 y CHK-17 (`bash scripts/check-layers.sh`, exit 0);
   - CHK-08 dos veces, con el mismo `Tests run` que antes del cambio;
   - CHK-09 de `@AC-COMPRA-04` y de `@AC-COMPRA-08`;
   - CHK-10 de `@AC-COMPRA-04` con `-Dcart.expected.single-product.products=__CONTROL_NEGATIVO__`, que falla en el `Then`;
   - el commit solo cambia `XPathLiteral.java` (`git show --stat HEAD`).
3. **Control negativo manual de la guarda**, como los `requireNonNull` del ADR-001:

   ```bash
   ./mvnw -B -ntp test -Dheadless=true -Dcucumber.filter.tags="@AC-COMPRA-04" "-Dtest.purchase.single-product=Sauce Labs Backpack'"
   ```

   - Debe fallar en el `When` *agrega el producto individual configurado al carrito*, con `IllegalArgumentException` y el mensaje del paso 1, sin agotar la espera.
   - No vale un fallo con `InvalidSelectorException` o `TimeoutException`, ni un fallo en el `Then`.
   - Con el código de `afb6693`, el mismo comando falla por tiempo de espera, porque la rama 2 produce un selector válido que no encuentra nada. Esa diferencia es la evidencia.

*Efecto en las CHK:*
- CHK-11 y CHK-15: sin cambios. `src/main` no cambia, y PIT no ve `pages`.
- CHK-16: sin cambios, porque no hay pruebas unitarias nuevas.
- CHK-17: sin cambios en el script ni en la autoprueba. `XPathLiteral` sigue sin nombrar `com.demo` ni Selenium, así que R1, R5 y R6 se cumplen igual.
- CHK-10: sin cambios. Sigue siendo el control de la rama que queda.
- `README.md:317` ("se convierte de forma segura en un literal XPath") pasa a decir que el valor se inserta entre comillas simples y que uno con comilla simple se rechaza. `README.md` no tiene dueño en la matriz: el usuario designa quién lo edita.

*Aplicado (2026-10-13):*
- **`25865e8`** (firmado): solo cambia `XPathLiteral.java`, como pide el paso 2 (`git show --stat 25865e8`).
  - El código es el del paso 1: el mensaje es literal, y el `'…'` se devuelve sin más ramas.
  - El verifier lo aprobó, incluidos los pasos 2 y 3, según el coordinador.
- **`2671a20`**: `README.md` (hoy `:318`) describe las comillas simples y el rechazo al instante.

**3. Referencias estables a CI.**
- Las citas `ci.yml:<línea>` y `Jenkinsfile:<línea>` quedaron desfasadas con cada job y etapa nuevos. Desde esta fecha, este ADR cita la CI por el nombre del job, del paso o de la etapa.
- Las citas con número de línea que quedan son registro histórico e indican su commit: *Contexto* (fila de la configuración del navegador), D6, R-4 y la enmienda de los pasos 1 a 3.

**Pendientes (P2):** la restricción de `ResultadoClic` en CHK-17 (`devops-engineer`, parte 1) y `README.md:317` (usuario, parte 2). *(Al cierre del 2026-10-13: `README.md:317` está hecho en `2671a20`. La restricción de `ResultadoClic` la implementa devops, y D7 se enmendará con su regla exacta. Hecho en la enmienda siguiente.)*

### 2026-10-13 — R6: `ResultadoClic` fuera de los miembros públicos de las páginas (CHK-17)

Las decisiones de fondo y el estado no cambian: D7 se alinea con el script, que es la implementación normativa (D6). Esta enmienda va **en el mismo commit** que `scripts/check-layers.sh` y su autoprueba (`devops-engineer`), así que no cita un hash propio: es "este commit".
- **Regla.** `check R6 "ResultadoClic en un miembro público de una página" '^\s*public\b.*\bResultadoClic\b' -- "$T/pages"` (`check-layers.sh:167-169`), justo después de la línea de `pages` de R6.
  - Imprime `archivo:línea: R6: ResultadoClic en un miembro público de una página`.
  - Es la expresión que propuso la parte 1 de la enmienda anterior.
- **D7, en este ADR:**
  - la fila R6 de la tabla, con su equivalente ArchUnit de referencia;
  - la línea nueva en los comandos;
  - el párrafo *`ResultadoClic` en páginas*;
  - la *Nota de ejecución*, que cita `check-layers.sh:11-39` y `:103-128` y pasa a 22 comprobaciones (`D1-rc`).
- Cambiaron las líneas citadas en la opción A de la parte 2 de la enmienda anterior: la fila de `pages` de R6 pasa a `:165-166` y la excepción de `ConfigReader` a `:163-164`.
- **Autoprueba** (según devops; B-01 no permite ejecutarla). Tiene 184 casos (162 antes):
  - violaciones `D1-rc`, `-b`, `-c` y `-d` (retorno calificado, retorno importado, parámetro y campo público), versionadas y sin versionar;
  - casi-violaciones permitidas `ok-5` a `ok-11`: método privado, variable local, `enum` público en `transport`, comentario, identificador que empieza por `public`, y el nombre como sufijo y como prefijo.
  - **Control negativo:** sin el `check`, fallan 8 de los 184 casos, que son los cuatro casos `D1-rc` en sus dos variantes.
- **Sobre HEAD:** la regla no da salida (`git grep -nP '^\s*public\b.*\bResultadoClic\b' -- src/test/java/com/demo/pages`, rc=1).
- **Blobs:** los que citó devops (`dac56a09…` para el script y `ae090375…` para la autoprueba) no se pueden comprobar con B-01, porque no hay nada en el índice y `git hash-object` no está permitido. El commit fija los dos archivos junto a esta enmienda.
- **Cierra:**
  - el P2 de la parte 1 de la enmienda anterior;
  - la restricción de D1, que pasa de "a mano" a CHK-17.
- **Reglas y agentes.** El usuario aplicó la mención de esta regla, sin commit al redactar esta enmienda, en dos archivos:
  - en la descripción de CHK-17 de `.claude/rules/04-quality-checks.md:23`;
  - en la fila R6 de `.claude/agents/qa-automation-architect.md:53`.
- *(Trazabilidad, 2026-10-13: "este commit" es `5329cf1`, firmado. Contiene esta enmienda, el script, la autoprueba y los dos archivos de reglas y agentes: `git show --stat 5329cf1`.)*

### 2026-10-13 — Firmas expuestas en CHK-17 (R1, R3 y R6)

**Propuesta** del `qa-automation-architect` el 2026-10-13, a petición del coordinador (P2 de `MEMORY.md`, *Próximos pasos*). La aprueba el coordinador (Regla 01, nivel 2). Las decisiones de fondo no cambian: D7 define qué es una firma "pública" y cierra los huecos de `^\s*public\b`.

- **Qué cambia en D7:**
  - las filas R1, R3 y R6 de la tabla y sus equivalentes ArchUnit;
  - el bloque de comandos: `MOD`, `EXP` y `TIPO`, las cinco comprobaciones de firmas reescritas con `EXP` y dos nuevas, `R1-tipos` y `R3-tipos`;
  - una línea al final de *R3 en acciones* y otra al final de *`ResultadoClic` en páginas*;
  - la subsección *Firmas expuestas*: definición, dos decisiones con sus opciones, expresiones, 48 casos de autoprueba, 21 mutantes y riesgo residual;
  - la *Nota de ejecución* (24 comprobaciones y el límite de PCRE).
  - Fuera de D7, D6 suma los casos previstos de la autoprueba.
- **Integración (D6).** El script y la autoprueba son de `devops-engineer`. Esta enmienda se integra **en el mismo commit** que ellos, como la de `ResultadoClic`.
  - Hasta ese commit, CHK-17 es lo que ejecuta el script: 22 comprobaciones.
  - Si la implementación se aparta de D7 en una expresión, un motivo o un caso, se corrige el ADR antes del commit. La regla nunca se relaja.
- **Comprobación sobre el árbol** (2026-10-13, HEAD `34f8528` y árbol limpio; solo `git grep`, B-01):
  - **No hay violaciones.** Las siete expresiones, cada una sobre su ámbito, se ejecutaron en tres pasadas: con `--untracked`, sin él y sobre `HEAD`. Todas dan rc=1, sin salida. El cambio no rompe la suite ni CHK-17.
  - `git grep -nP '^\s*(?:(?:@[\w.]+(?:\(.*\))?|non-sealed|[a-z]+)\s+)+(?:public|protected)\b' -- src` da rc=1 en las tres pasadas. Ninguna línea de `src` tiene una anotación o un modificador antes de `public` o `protected`, así que hoy `EXP` no encuentra nada nuevo en ninguna capa.
  - `git grep -n -w protected -- src` da rc=1.
  - `git grep -nP '\b(class|interface|record|enum)\s+\w'` sobre las tres capas solo lista 10 clases y `Navegador.java:147`, que es `public enum ResultadoClic`.
  - **Control positivo de `TIPO`:** sobre todo `src`, solo encuentra `src/main/java/com/demo/data/Credentials.java:10` (`public record Credentials(…)`), fuera de las tres capas.
  - **Control positivo de los casos:** sobre este ADR, cada expresión encuentra exactamente las líneas *Deben fallar* de su comprobación, y ninguna de *Deben pasar* ni de la prosa:
    - `D7-03`: sus 4 casos;
    - `D7-04`: sus 4, más `D7-03-col0` y `D7-03-anot`, que contienen `By` pero están en `transport`, fuera de su ámbito;
    - `TIPO`: los 5 `R1-tipos*` y los 3 `R3-tipos*`;
    - `D7-06` y `R3-param`: sus 4 cada una;
    - `D1-rc`: sus 4 y los 4 `EXP-*`.
  - **Control de los mutantes,** sobre el mismo bloque:
    - E1, E3–E9, E11–E13 y T1–T6 cambian exactamente las líneas que indica la tabla de mutantes.
    - E10 hace que PCRE agote su límite (`pcre2_jit_match failed … match limit exceeded`), porque `[a-z]+\s*` es ambiguo. En el script eso da 2, así que también mata al mutante.
    - E2, E14 y T7 se deducen de la expresión: E2 deja fuera toda línea con sangría, y E14 y T7 dependen de la comprobación o la ruta mutada.
  - **Casos vigentes:** sobre `scripts/tests/check-layers-test.sh`, con el ancla adaptada a sus comillas, cada expresión encuentra los casos negativos vigentes de su comprobación (`D7-03`…`D7-03f`, `D7-04`, `D7-06`, `R3-param`…`-c` y `D1-rc`…`-d`) y ninguno de los `ok-1`…`ok-11` de su capa.
  - **Límite de PCRE:** las seis expresiones distintas recorren todos los archivos versionados con `git grep -lP` sin texto en stderr. `R1-tipos` y `R3-tipos` comparten `TIPO`.
- **Criterio de cierre** (`devops-engineer`):
  1. `scripts/check-layers.sh` define `MOD`, `EXP` y `TIPO` una sola vez, con el texto exacto de D7. Reescribe las cinco comprobaciones de firmas con `EXP`, sin cambiar sus motivos, y suma `R1-tipos` y `R3-tipos` con los motivos de la tabla de *Firmas expuestas*.
  2. La autoprueba suma los 32 casos negativos y los 16 permitidos de D7, en sus dos modos, y los vigentes no cambian: 280 casos previstos, con exit 0.
  3. Sabotaje: cada mutante de la tabla (E1–E14 y T1–T7) hace fallar al menos un caso. Se adjunta la tabla mutante → casos en rojo, y ninguno sobrevive.
  4. `bash scripts/check-layers.sh` da 0 sobre HEAD.
  5. La CI no cambia. CHK-17 sigue en el job `mutation`, en los pasos *Capas, autoprueba con mawk, gawk y gawk --posix (CHK-17)* y *Capas (CHK-17)*, y en la etapa `Capas (CHK-17)` del `Jenkinsfile`. D6 cita los nombres de esos pasos en `f7f7a13`.
- **Fuera de alcance (P2 nuevos).** Los dos dan falsos negativos hoy no explotados. Se resuelven en otra enmienda, con sus casos:
  1. **La lista de tipos de R1 en `transport` es cerrada.** `\b(Web[A-Z]\w*|…)\b` exige un límite de palabra antes de `Web`, así que no ve `RemoteWebDriver`, `ChromeDriver`, `FirefoxDriver` (los tres en `DriverFactory.java:5-9`, en código de paquete), `Alert`, `Actions`, `Cookie` ni `Dimension` en una firma expuesta.
  2. **`extends` solo se comprueba en `pages` (R5).** Una clase de `transport` que extiende un driver hereda toda su API pública de Selenium, y una de `actions` que extiende una página hereda la página. Ninguna comprobación de firmas lo ve, porque la línea no tiene `(`. Hoy no ocurre: las 5 páginas públicas, `Navegador` y las 2 acciones son `final`, y `DriverFactory` no extiende nada.

  Ejemplos: ninguna de las siete expresiones encuentra estas líneas en este ADR.

  ```java
      public RemoteWebDriver remoto() {
  public final class Navegador extends ChromeDriver {
  public final class CompraActions extends CartPage {
  ```

  *(2026-10-13: los dos los aborda la enmienda *Selenium en el transporte y herencia*.)*
- **Reglas y agentes (opcional; usuario, P-01).** D7 ya define "pública", así que el texto actual sigue siendo correcto. Si el usuario quiere que lo diga:
  - `.claude/agents/qa-automation-architect.md`, filas R1 y R3: agregar "(públicas o protegidas; sin interfaces, anotaciones ni records expuestos en `transport`, `pages` y `actions`)";
  - `.claude/rules/04-quality-checks.md`, descripción de CHK-17: agregar "firmas expuestas con anotaciones, otro orden de modificadores o `protected`, y sin interfaces, anotaciones ni records expuestos".
- *(Trazabilidad, 2026-10-13: el usuario aplicó los textos de reglas y agentes en `7083d19`. "Ese commit" es `df87ada`, firmado: contiene esta enmienda, el script y la autoprueba (`git show --stat df87ada`). Según devops, la autoprueba da 280 casos en verde con mawk, gawk, `gawk --posix` y busybox, y el sabotaje no deja ningún sobreviviente en 28 ejecuciones de mutante: E1–E13, E14 en cada una de las siete comprobaciones, T1–T6 y T7 en cada una de sus dos rutas.)*

### 2026-10-13 — Selenium en el transporte y herencia (CHK-17, R1 y R5)

**Propuesta** del `qa-automation-architect` el 2026-10-13, a petición del coordinador (P2 que dejó la enmienda *Firmas expuestas* en *Fuera de alcance*). La aprueba el coordinador (Regla 01, nivel 2). Las decisiones de fondo no cambian: D7 completa R1 en `transport` y extiende a más capas la composición que R5 ya exigía a `pages`.

- **Qué cambia en D7:**
  - las filas R1 y R5 de la tabla, con sus equivalentes ArchUnit de referencia;
  - el bloque de comandos: `IMP`, `HER`, `R1-wild`, `R1-by`, las uniones `R1-imp` y `R1-her`, y `R5-ext`;
  - la subsección *Selenium en el transporte y herencia*: huecos, dos decisiones con sus opciones, expresiones, la unión por imports con su programa awk de referencia, 22 casos negativos, 7 permitidos y 2 de error, 28 mutantes y riesgo residual;
  - la *Nota de ejecución*: 29 comprobaciones, el código de salida de awk y el límite de PCRE.
  - Fuera de D7, D6 suma los casos previstos, y se corrige su total de *Firmas expuestas*: 280 casos, en verde con 4 implementaciones de awk sobre `df87ada` (según devops).
- **Integración (D6).** El script y la autoprueba son de `devops-engineer`. Esta enmienda se integra **en el mismo commit** que ellos.
  - Hasta ese commit, CHK-17 es lo que ejecuta el script: 24 comprobaciones.
  - Si la implementación se aparta de D7 en una expresión, un motivo, un caso o la semántica de la unión (puntos 3 a 6), se corrige el ADR antes del commit. La regla nunca se relaja.
- **Comprobación sobre `src`** (2026-10-13, solo `git grep`, B-01). Se ejecutó sobre `HEAD` tres veces, a medida que avanzaba: en `df87ada`, en `cc674a8` y en `3bab4b2`.
  - Entre `df87ada` y `cc674a8`, `src` y los dos scripts de CHK-17 no cambian (`git diff --stat df87ada cc674a8 -- src scripts/check-layers.sh scripts/tests/check-layers-test.sh` no da salida).
  - `3bab4b2` cambia `BrowserSettings`, su prueba y una línea de un método privado de `DriverFactory` (enmienda siguiente). Los resultados de abajo son los mismos en los tres commits.
  - **No hay violaciones.** Todas estas búsquedas dan rc=1, sin salida:
    - `R1-wild`, `R1-by` y `HER` sobre `transport`, y `R5-ext` sobre `transport`, `actions` y `utils`;
    - cualquier import con comodín en todo `src` (`\bimport\s+(?:static\s+)?[\w.\s]*\*`);
    - `\b(?:extends|implements)\b` en todo `src`, incluido `src/main`.
  - **Unión, hecha a mano.** `IMP` lista 17 imports: 6 en `DriverFactory.java` y 11 en `Navegador.java`, uno de ellos `By`.
    - Las líneas `EXP` de `Navegador.java` con alguno de sus 10 nombres (sin `By`) o con `openqa` dan rc=1.
    - `DriverFactory.java` no tiene ninguna línea `EXP` (rc=1): es de paquete.
    - `openqa` en una línea `EXP` o `HER` de `transport` da rc=1.
  - **Clases.** Todas las clases públicas de `transport`, `pages`, `actions`, `utils`, `steps` y `hooks` son `final`, y `DriverFactory` y `XPathLiteral` son `final` de paquete. Solo `RunnerTest` no es `final`, y queda fuera de las reglas nuevas (`git grep -nP '\b(class|interface|record|enum)\s+\w' HEAD -- src/test/java/com/demo`).
  - **Límite de PCRE.** `IMP`, `HER`, `R1-wild`, `R1-by` y `R5-ext` recorren con `git grep -lP` todos los archivos versionados de `src`, `scripts`, `docs` y `.github`, sin texto en stderr.
- **Control positivo de los casos,** sobre este ADR (líneas del bloque de casos):
  - `R1-wild` encuentra sus 2 casos y no `ok-33`.
  - `R1-by` encuentra sus 4 y no `ok-28`.
  - `IMP` encuentra las 17 líneas de import de los casos, incluida la de tres imports.
  - `EXP` encuentra las 8 candidatas de `R1-imp`, y no el campo `private` de `ok-29` ni `ok-34`.
  - `HER` encuentra los 5 casos `R1-her*` y no `ok-32` ni `ok-34`.
  - `R5-ext` encuentra sus 3 casos, y no `ok-30`, `ok-31`, `ok-32` ni `ok-34`.
  - `D7-03` no encuentra ninguno de los 8 casos `R1-imp*`: es el hueco que se cierra.
  - `TIPO` no encuentra ninguno de los casos nuevos.
- **Control de los mutantes de `git grep`,** sobre el mismo bloque:
  - W2 pierde `R1-wild-b`; W3 suma `ok-33`;
  - B2 suma `ok-28`; B3 pierde `R1-by-d`;
  - U3 pierde la línea de tres imports de `R1-imp-f`, y U5 la de `R1-imp-c`; U2 pierde `R1-imp-e`;
  - U13 pierde `R1-her` y `R1-her-d`, y U15 suma `ok-34`;
  - X3 suma `ok-30` y `ok-31`, y X4 suma `ok-32`.
  - Los mutantes del awk (U4, U6–U11 y U16–U17) y los de cableado (U1, U12, U18, W1, B1, X1 y X2) los ejecuta devops: B-01 no permite correr awk ni el script.
- **Cambios del engineer sin commit.** Se revisaron en dos momentos, de solo lectura (`git grep --untracked`, limitado a `src`):
  - **Primero:** el diagnóstico de clics en `transport` y `hooks`, con `DiagnosticoClic.java` sin versionar. No violan las reglas nuevas: `DiagnosticoClic` es una clase de paquete sin líneas `EXP`, y no hay herencia ni comodines.
  - **Después:** ese diagnóstico ya no está en el árbol. Los cambios sin commit pasaron a ser `BrowserSettings` y su prueba (`src/main` y `config`, fuera de CHK-17) y una línea dentro de un método privado de `DriverFactory`. Tampoco violan las reglas nuevas: `DriverFactory` sigue sin líneas `EXP`, sin herencia y sin comodines (rc=1). Esos cambios son hoy `3bab4b2`, y al cerrar esta enmienda `src` no tiene cambios sin commit.
- **Criterio de cierre** (`devops-engineer`):
  1. `scripts/check-layers.sh` define `IMP` y `HER` una sola vez, con el texto exacto de D7. Suma `R1-wild`, `R1-by`, `R1-imp` y `R1-her` después de `R1-tipos`, y `R5-ext` después de `D7-11`, con los motivos de la tabla. La unión reutiliza el ejecutor de dos pasadas de `check` y cumple los puntos 1 a 6 de *Unión por imports*.
  2. La autoprueba suma los 22 casos negativos y los 7 permitidos de D7, en sus dos modos, y los 2 de error. Los casos vigentes no cambian: 340 casos previstos, con exit 0 con mawk, gawk, `gawk --posix` y busybox (matriz de CHK-18). `bash scripts/check-awk-portability.sh` da exit 0.
  3. Sabotaje: cada mutante de la tabla (U1–U18, W1–W3, B1–B3 y X1–X4, con X2, U15 y X4 en cada una de sus variantes) hace fallar al menos un caso. Se adjunta la tabla mutante → casos en rojo, y ninguno sobrevive.
  4. `bash scripts/check-layers.sh` da 0 sobre HEAD.
  5. La CI no cambia: CHK-17 sigue en el job `mutation` y en la etapa `Capas (CHK-17)` del `Jenkinsfile`.
- **Reglas y agentes (usuario, P-01).** D7 es la definición normativa, así que el texto actual no es falso, pero la fila R5 queda incompleta. Texto propuesto:
  - `.claude/agents/qa-automation-architect.md`, fila R1: agregar "en `transport`, tipos de Selenium importados o calificados en firmas expuestas (`By`, solo como parámetro), herencia o implementación de tipos de Selenium e imports de Selenium con comodín";
  - la misma fila R5: "páginas que extienden una clase" pasa a "clases de `transport`, `pages`, `actions` o `utils` que extienden otra";
  - `.claude/rules/04-quality-checks.md`, descripción de CHK-17: agregar "tipos de Selenium importados en firmas del transporte y herencia en `transport`, `actions` y `utils`".

### 2026-10-13 — Preferencias de Chrome (D8) y respaldo JavaScript del clic (D1)

**Propuesta** del `qa-automation-architect` el 2026-10-13, a petición del coordinador. La aprueba el coordinador (Regla 01, nivel 2), y va en la misma entrega que la enmienda anterior. Es la "parte 3" que citan D1 y D8.

**1. Registro en D8 de `chromePreferences()`** (`3bab4b2`, firmado; `git show --stat 3bab4b2`: `BrowserSettings`, `BrowserSettingsTest` y `DriverFactory`). Detalle, motivo y evidencia en D8, junto a `--disable-component-update`. Cumple D8: la decisión es pura y está en `src/main`, y `DriverFactory` solo traduce. CHK-15 y CHK-17 no cambian: `DriverFactory` ya podía nombrar `config`, y el cambio no agrega líneas expuestas, herencia ni comodines. Se comprobó con las expresiones de la enmienda anterior, primero sobre el árbol antes del commit y después sobre `3bab4b2`; todas dan rc=1.

**2. Decisión: se retira el respaldo JavaScript del clic.** Cada acción hace **un solo clic nativo** y espera su postcondición hasta el tiempo máximo. Si no se cumple, falla.

*Hechos:*
- El respaldo (D1, *Tope de clics*) existía porque Chrome "perdía" clics nativos. La causa ya se conoce y se corrige en la capa más baja posible, la configuración pura del navegador (D8).
- Con la corrección, el respaldo no se usa: 0 de 156 clics, según el coordinador. Con 0 casos en 156, la tasa por clic queda acotada, con un 95 % de confianza, por debajo de ~1,9 % (regla del tres: 3/156). Eso no es cero.
- Chrome ignora en silencio una preferencia que no reconoce, y las pruebas unitarias no pueden probar que la respete (D8, *Límite*).

| Opción | Veredicto | Motivo |
|---|---|---|
| A. Mantenerlo como está (1 nativo y hasta 2 JS, log INFO) | Descartada | Es lo que ocultó la causa: con el respaldo, 36 de 153 clics nativos se perdían sin que la suite dejara de estar en verde. Si Chrome renombra la preferencia, o aparece otro aviso que se trague la entrada, el síntoma vuelve sin que nada falle. Además, `arguments[0].click()` entrega el evento sin pasar por el hit-testing del navegador. La postcondición se sigue exigiendo, pero el clic JS puede alcanzarla con un control que un usuario no podría pulsar: es un **verde falso** sobre la interacción, aunque no sobre el resultado. Y un control que alterna su estado puede revertirse con un clic de más (D1) |
| B. Subir el log a WARN | Descartada | Solo lo ve quien lee el log de una ejecución en verde. Para que falle haría falta un control de log como CHK-19, que mantendría vivo un código que no debería ejecutarse nunca, con su verde falso |
| C. Que usar el respaldo haga fallar la prueba | Converge con D | Si usarlo falla, el clic JS ya no aporta nada: basta con no darlo. De C se conserva el mensaje, que nombra la causa conocida |
| D. Quitarlo: un clic nativo por acción | **Elegida** | Falla cerrado: si la preferencia deja de funcionar, el primer clic tras el inicio de sesión agota el plazo en rojo, en CHK-08 y en la CI, con un mensaje que apunta a D8. Quita la vía del verde falso, el riesgo de revertir un control que alterna y un `executeScript` (superficie de PI-05). Es coherente con CHK-02 y con R-2 de este ADR: ante una pérdida de estabilidad se diagnostica, nunca se repite la acción |
| E. Repetir el clic de forma nativa en lugar de con JS | Descartada | Pasa por el hit-testing, pero sigue repitiendo la acción dentro del paso. Ocultaría una carrera del SUT (un control pulsado antes de estar listo) y conserva el riesgo de revertir un control que alterna. Si el aviso vuelve, el clic nativo repetido también se pierde, así que no protege nada |

*Coste aceptado.* Una pérdida de clics nativos que no explique la preferencia (por ejemplo, en Firefox, que no se midió) pasará a dar rojo en lugar de verde. Es lo que se busca:
- se diagnostica;
- si hace falta mientras tanto, entra en la cuarentena reglada como `inestable` (CHK-14);
- nunca se vuelve a agregar un respaldo sin una enmienda de este ADR.

*Escritura (`escribir` y `esperarValorEstable`).* Tiene un respaldo equivalente: una reescritura nativa y después un `SCRIPT_ESCRIBIR_INPUT_CONTROLADO` por JS, con un log INFO de las correcciones. El aviso de Chrome también descartaba teclas, así que aplica el mismo criterio, **condicionado a datos**: la evidencia de `3bab4b2` y del coordinador solo cuenta clics.
- El engineer mide las correcciones de escritura con la preferencia, en la misma muestra que los clics.
- Si son 0, se retiran también la reescritura y el script JS en el mismo cambio: `escribir` escribe una vez y espera el valor estable; si no llega, falla.
- Si no son 0, la escritura queda como está, y el engineer reporta los datos al arquitecto (P1) para decidir por enmienda. La decisión del clic no espera a la de la escritura.

*Contrato que cambia en D1* (lo aplica el engineer; D1 se actualiza cuando el verifier lo apruebe):
- `clickHastaCumplir`, `clickYObservarUrlContiene` y los cuatro `clickYEsperar…`: esperan a que el control sea clicable, hacen **un** clic nativo y esperan la postcondición hasta el tiempo máximo.
  - Se retiran `MAXIMO_CLICS_POR_ACCION`, el método privado `pulsar` y su `executeScript("arguments[0].click();", …)`.
  - `desplazarA` y `SCRIPT_LEER_CODIGO_PAGINA_ERROR` no cambian.
- `ResultadoClic` conserva sus tres valores:
  - `NO_AVANZO` pasa a ser "tras el clic nativo, la URL no se alcanzó";
  - `NO_DISPONIBLE` sigue siendo "no hubo clic".
  - `CartPage` no cambia.
- El `TimeoutException` de `clickHastaCumplir` conserva el localizador, el plazo y los clics efectivos (0 o 1).
  - Con 1 clic sin efecto, añade una pista fija: "el clic nativo no tuvo efecto; si ocurre en Chrome tras iniciar sesión, revisar las preferencias de Chrome (ADR-002, D8)".
  - Nunca lleva texto del SUT ni el texto escrito (PI-05 y PI-09).
- El log INFO de "clics efectivos" desaparece, porque ya no hay más de un clic. Se conservan los INFO de `clickYObservarUrlContiene`.

*Verificación (cada paso deja la suite en verde):*
1. CHK-01, CHK-03, CHK-07 y CHK-17 en verde.
2. CHK-08 ×2 con el mismo `Tests run` que en `3bab4b2` (189).
3. Para acumular muestra, CHK-08 tres veces más en Chrome local, al menos una con la máquina cargada, y el job `e2e-grid`. Ninguna puede fallar por un clic sin efecto.
4. Firefox local (`-Dbrowser=firefox`, con el geckodriver de snap) o el job `e2e-firefox`, en verde.
5. CHK-09 y CHK-10 de regresión de `@AC-COMPRA-01` y `@AC-LOGIN-01`.
6. **Control negativo manual** (como el de `XPathLiteral`): sin la preferencia (cambio local, sin commit), una ejecución de un AC con clics tras el inicio de sesión debe fallar en rojo, con `TimeoutException` y la pista de D8, y no pasar en verde.
   - Se repite hasta observar el fallo, como mucho 5 veces: en el A/B de `3bab4b2`, 3 de 6 clics lo necesitaron.
   - Si no falla en 5, se reporta, porque el síntoma no se reprodujo.
   - Con el código de `3bab4b2`, el mismo control pasa en verde gracias al respaldo. Esa diferencia es la evidencia.
7. CHK-11 sin cambios: `Navegador` está fuera de PIT.
8. Gate CRÍTICO de devops, porque toca `transport`.

*Efecto en otros artefactos:*
- `MEMORY.md` dice "tope de 3 clics por acción (1 nativo + 2 JS, con log INFO)" y tiene como P2 la causa del respaldo JS. Lo actualiza el coordinador al cerrar.
- `README.md` describe el respaldo JavaScript del clic y de la escritura en su párrafo de postcondiciones (`README.md:292` en `3bab4b2`). Dice que "no convierte un fallo real en un falso positivo", lo que vale para el resultado pero no para la interacción (opción A). Tras el cambio se reescribe; lo edita quien designe el usuario.
- **P2 (devops):** que los jobs con Chrome registren la versión del navegador, como ya hace el paso *Firefox version* del job `e2e-firefox`. Así, un rojo tras actualizar Chrome se asocia con su versión.
