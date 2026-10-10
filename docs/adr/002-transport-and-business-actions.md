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
| La configuración del navegador no se ejercita en CI | CI solo corre Chrome local headless (`ci.yml:48`, `config.properties:3`, `:5`). No se ejercitan Firefox (`DriverFactory.java:38`, `:85-97`), Grid (`:80-81`, `:94-95`, `:103-110`) ni el tamaño de ventana (`:72-77`, `:88-91`) | Un defecto en esas ramas pasa inadvertido para la suite (criterio D1(b) del ADR-001) |
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
- **`literalXPath` se queda en la página** (`InventoryPage.java:40-48`). No va a `src/main` porque su defecto produce un selector inválido, es decir, un fallo visible, y no cumple el criterio D1(b) del ADR-001.

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

  Así, una expresión regular rota no deja pasar todo en silencio. En `f7f7a13` tiene 81 casos (80 como root, donde el del archivo ilegible no aplica).
- **Dónde corren el script y la autoprueba:**
  - GitHub Actions: job `mutation`, en paralelo a la suite y sin secrets (`ci.yml:66-84`);
  - Jenkins: etapa `Capas (CHK-17)`, antes de la suite y fuera de `withCredentials` (`Jenkinsfile:22-29`);
  - el gate local de devops;
  - la autoverificación del engineer.
- **Disparador para reconsiderar ArchUnit:** una evasión real que el texto no detecte, un segundo módulo Maven o más de unos 10 paquetes. Las reglas equivalentes quedan escritas en D7.

### D7. Reglas R1–R7 en su forma final

| Regla | Rechaza | Equivalente ArchUnit (esbozo de referencia; no se implementa) |
|---|---|---|
| R1 | Selenium fuera de `transport`; en `pages`, todo lo que no sea `import org.openqa.selenium.By;`; tipos de Selenium (salvo `By`) en firmas públicas del transporte; `By` en firmas públicas de páginas | `noClasses().that().resideOutsideOfPackages("..transport..", "..pages..").should().dependOnClassesThat().resideInAPackage("org.openqa..")`; para `..pages..`, lo mismo con `.and(not(equivalentTo(By.class)))` |
| R2 | Selenium en `steps` o `actions` (incluida en R1; CHK-03 es su subconjunto rápido) | `noClasses().that().resideInAnyPackage("..steps..", "..actions..").should().dependOnClassesThat().resideInAPackage("org.openqa..")` |
| R3 | `steps` que nombran `pages` o `transport`; acciones con páginas en sus firmas públicas, como tipo de retorno o como parámetro (los constructores sí las reciben, D3) | `noClasses().that().resideInAPackage("..steps..").should().dependOnClassesThat().resideInAnyPackage("..pages..", "..transport..")` |
| R4 | JUnit fuera de `steps`, `runners` y las unitarias; Cucumber fuera de `steps`, `hooks` y `runners`; claves `*.expected*` en `transport`, `pages` o `actions` | `noClasses().that().resideInAnyPackage("..transport..", "..pages..", "..actions..").should().dependOnClassesThat().resideInAnyPackage("org.junit..", "io.cucumber..")` |
| R5 | `findElement(s)`, `executeScript` o `executeAsyncScript` fuera de `transport`; páginas que extienden una clase | `noClasses().that().resideOutsideOfPackage("..transport..").should().callMethodWhere(target(owner(assignableTo(SearchContext.class).or(assignableTo(JavascriptExecutor.class)))))` |
| R6 | Nombrar un paquete fuera de su fila de D4; secretos fuera de `utils` y `steps` (las unitarias, por CHK-16) | `layeredArchitecture().consideringOnlyDependenciesInLayers()` con las filas de D4 (`whereLayer(…).mayOnlyBeAccessedByLayers(…)`) y `slices().matching("com.demo.(*)..").should().beFreeOfCycles()` |
| R7 | Vocabulario de interfaz en las features | No aplica (Gherkin): CHK-04, sin cambios |

Comandos de CHK-17, transcritos de `scripts/check-layers.sh` (la implementación normativa, D6). Cada uno pasa **sin salida** y usa `-P`, como CHK-01:

```bash
T=src/test/java/com/demo
# R1: Selenium solo en transport; en pages, solo el import de By
git grep --untracked -nP 'org\.openqa' -- src ":!$T/transport" ":!$T/pages"
git grep --untracked -nP 'org\.openqa(?!\.selenium\.By;$)' -- "$T/pages"
# R1: firmas públicas
git grep --untracked -nP '^\s*public\b.*\b(Web[A-Z]\w*|SearchContext|JavascriptExecutor|TakesScreenshot|Capabilities|\w+Options)\b' -- "$T/transport"
git grep --untracked -nP '^\s*public\b.*\bBy\b' -- "$T/pages"
# R3: steps sin páginas ni transporte; acciones sin páginas en sus firmas públicas
git grep --untracked -nP 'com\.demo\.(pages|transport)\b' -- "$T/steps"
#   … página como tipo de retorno
git grep --untracked -nP '^\s*public\b[^(]*\b\w+Page\b[^(]*\(' -- "$T/actions"
#   … página como parámetro (constructores exceptuados)
git grep --untracked -nP '^\s*public\b(?!\s+\w+\s*\()[^(]*\(.*\b[A-Z]\w*Page\b' -- "$T/actions"
# R4: JUnit, Cucumber y esperados en su sitio
git grep --untracked -nP 'org\.junit' -- src ":!$T/steps" ":!$T/runners" ":!$T/config" ":!$T/data"
git grep --untracked -nP 'io\.cucumber' -- src ":!$T/steps" ":!$T/hooks" ":!$T/runners"
git grep --untracked -nP '\.expected' -- "$T/transport" "$T/pages" "$T/actions"
# R5: localización y scripts solo en transport; páginas por composición
git grep --untracked -nP '\bfindElements?\s*\(|\bexecute(Async)?Script\b' -- src ":!$T/transport"
git grep --untracked -nP '\bextends\b' -- "$T/pages"
# R6: una línea por fila de D4 (runners excluido; src/main lo garantiza Maven)
git grep --untracked -nP 'com\.demo\.(pages|actions|steps|hooks|runners|data)\b' -- "$T/transport"
git grep --untracked -nP 'com\.demo\.utils\.(?!ConfigReader\b)' -- "$T/transport" "$T/pages"
git grep --untracked -nP 'com\.demo\.(actions|steps|hooks|runners|config|data)\b' -- "$T/pages"
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

**Nota de ejecución** (`scripts/check-layers.sh:10-38`, `:93-118`):
- **Dos pasadas por comando.** Cada `git grep` corre con `--untracked` (lo no versionado, respetando `.gitignore`) y sin él (los archivos del índice), y los resultados se unen sin duplicados. Motivo: con git 2.53, `--untracked` recorre el árbol de trabajo sin leer el índice y omite los archivos versionados que coinciden con `.gitignore`.
- **stderr es error.** Con un archivo ilegible, `git grep` imprime "failed to stat" y aun así termina con 0 o 1. Por eso cualquier texto en su stderr da 2.
- **Códigos de salida:**
  - 0: sin violaciones;
  - 1: violaciones, una por línea, como `archivo:línea: R<n>: motivo`. Un directorio de capa sin archivos versionados se imprime como `directorio:0: D6: motivo`: es una violación de la estructura, no un error de la herramienta;
  - 2: no se pudo evaluar (falla cerrado). Ocurre con argumentos de más, una raíz que no es un directorio o no es la raíz de un repositorio, `git grep` con rc ≥ 2 o con texto en stderr, o un error de `git ls-files`.
- **21 comprobaciones:**
  - los 19 `git grep` originales de D7 (`D7-01`…`D7-19` en la autoprueba);
  - el de R3 para parámetros (`R3-param`);
  - el `git ls-files` de directorios (`D7-20`).

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

Este ADR se escribió sin ejecutar nada: solo se leyeron archivos y se buscó con `git grep` (B-01). El estado de R-1 a R-8 refleja el cierre, tras los pasos 1 a 5 (*Enmiendas*). Siguen abiertos como P2 R-3, R-4 (solo Jenkins), R-6 y R-8.

| # | Supuesto | Lo confirma | Si es falso |
|---|---|---|---|
| R-1 | Pico construye `Navegador`, páginas y acciones de forma transitiva, con una instancia por escenario compartida por `Hooks` y las acciones. Hoy ya lo hace con `TestContext` y `PageManager` | engineer, paso 1: CHK-08. **Confirmado** (pasos 1 y 2): Pico construye `Navegador` (`Navegador.java:44`), las páginas (`LoginPage.java:19`), las acciones (`LoginActions.java:18`, `CompraActions.java:20`) y `Hooks` (`Hooks.java:16`) con el glue sin cambios (`RunnerTest.java:15`), y la suite queda en verde. Lo ratifica la verificación completa (paso 4). Si la instancia no fuera compartida, las páginas fallarían con `IllegalStateException` por usarse antes de `iniciar()` (`Navegador.java:156-160`) | Falla de forma visible al empezar el escenario. Se conserva una fábrica por escenario al estilo `PageManager`, por enmienda |
| R-2 | Mover `BasePage.java:72-125` sin cambios conserva la estabilidad en Chrome y React | verifier: diff de movimiento y CHK-09; devops: CHK-08 ×2. **Confirmado** (pasos 1 y 2): CHK-08 ×2 y los 7 AC en verde por separado en el paso 1 (`0aa3a02`), y CI en verde sobre `475651f`, según el usuario. Paso 4: los 7 AC en verde por separado y los 8 controles negativos en rojo en el `Then` | Se revierte el paso y se diagnostica; nunca se agregan reintentos ni esperas fijas (CHK-01, CHK-02) |
| R-3 | Sin `ThreadLocal`, el aislamiento depende de que cada escenario corra en un hilo con su propio contenedor. Es cierto en serie, que es el modo actual | devops, en el paso de paralelismo (`MEMORY.md`, *Próximos pasos*). **Abierto (P2):** sin `ThreadLocal`, el diseño solo vale en serie hasta que se adopte el paralelismo | Se reintroduce el aislamiento dentro de `Navegador`, por enmienda |
| R-4 | Las expresiones de D7 funcionan con `git grep -P` y `--untracked`, con exclusiones `:!`, en local, GitHub Actions y Jenkins. CHK-01 ya usa `-P` | **Confirmado en GitHub Actions (run de `257baaa`, verde); Jenkins sin servidor real para validar.** Según el usuario (2026-10-10), ese run incluye CHK-17 (`check-layers.sh` y su autoprueba) en el job `mutation`. Antes, en local (paso 3, git 2.53.0, 2026-10-10): el 2026-10-09 los comandos solo marcaban la deuda que resolvieron los pasos 1 y 2. Una ruta inexistente da rc=1 sin salida, y por eso D6 exige los directorios. Ahora, en local: devops informa la autoprueba con exit 0 en sus 81 casos (154 desde `bb7f145`) y el script con 0 sobre HEAD. El arquitecto ejecutó los 20 `git grep` sobre `f7f7a13`, con `--untracked` y con `--cached`: todos dan rc=1, sin salida, y cada directorio de capa lista archivos. Hallazgo: con git 2.53, `--untracked` omite los archivos versionados que coinciden con `.gitignore`, de ahí la doble pasada (D7, *Nota de ejecución*). Al cierre, el arquitecto repitió los 20 `git grep` de D7 con las dos pasadas sobre el árbol de trabajo del paso 5: todos dan rc=1, sin salida. **Abierto (P2), solo Jenkins:** el primer run en un servidor real, que imprime `git --version` (`Jenkinsfile:27`) | Se ajusta la sintaxis en el script; la autoprueba es la especificación ejecutable |
| R-5 | Las firmas públicas ocupan una línea, como en el estilo actual (`CheckoutPage.java:21`) | Revisión del verifier. **Se cumple hoy** (paso 4); sigue como riesgo residual aceptado (D6) | Una firma partida evade la regla de firmas, lo que activa el disparador de ArchUnit (D6) |
| R-6 | Las ramas de Firefox y Grid se mueven sin cambios en el paso 1, aunque CI no las ejecuta | D8 cubre la parte pura: `BrowserSettings`, con 27 pruebas unitarias y PIT (paso 5). **Abierto (P2):** la traducción a `Options` en `DriverFactory` sigue sin ejecutarse, porque CI no corre Firefox ni el Grid. La revisión del paso 5 ya halló un desvío en esa traducción: Firefox sin headless enviaba `args=[]`, y se restauraron sus capacidades | Prueba manual opcional de devops, con `-Dbrowser=firefox` y `docker compose` |
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
  - En GitHub Actions, CHK-17 corre en el job `mutation`, en paralelo a la suite, porque el job `test` expone los secrets `TEST_*` a todos sus pasos (`ci.yml:66-69`).
  - En Jenkins corre antes de la suite.
- **Pendientes:**
  - el primer run remoto, que cierra R-4;
  - el paso 4 (verifier) y el paso 5;
  - los cambios a reglas y agentes. Los programados hasta el paso 3 están en `4159952` y `475651f`, o en el árbol de trabajo sin commit al escribir esta enmienda. Quedan los del cierre del paso 4.

### 2026-10-10 — Pasos 4 y 5 y cierre

Las decisiones de fondo y el estado no cambian. Con este cierre, el ADR queda **completamente implementado**.
- **Autoprueba corregida** (`bb7f145`):
  - Las dos mutantes que el paso 3 dio por equivalentes fallaban abierto. Sin la rama `rc >= 2`, un `git grep` que muere por señal sin escribir en stderr daba `ok`. Sin la comprobación de raíz, una subcarpeta con su propio árbol de capas daba `ok`.
  - Ahora la autoprueba tiene 154 casos. Suma un shim de `git` (SIGKILL y `exit 2` sin stderr), el mensaje exacto en los casos de exit 2, el caso anidado y un caso por alternativa de cada expresión, incluidos los 33 paquetes de R6.
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
- **Abiertos (P2):** R-3 (paralelismo), R-4 (solo Jenkins), R-6 (Firefox y Grid sin CI) y R-8 (Q-*).

### 2026-10-10 — R-4 confirmado en GitHub Actions

- El run de GitHub Actions sobre `257baaa` terminó en verde, con CHK-17 en el job `mutation` (según el usuario): R-4 queda confirmado en remoto, y solo sigue abierto (P2) en Jenkins, sin servidor real para validar. El paso 5 y los cambios a reglas y agentes citan ahora sus commits (`32f5b36` y `257baaa`).
