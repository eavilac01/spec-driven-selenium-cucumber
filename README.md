# Spec-Driven Selenium Cucumber

[![E2E Tests](https://github.com/eavilac01/spec-driven-selenium-cucumber/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/eavilac01/spec-driven-selenium-cucumber/actions/workflows/ci.yml)
![Java](https://img.shields.io/badge/Java-17-orange?logo=openjdk)
![Selenium](https://img.shields.io/badge/Selenium-4.45-43B02A?logo=selenium)
![Cucumber](https://img.shields.io/badge/Cucumber-7.34-23D96C?logo=cucumber)
![JUnit](https://img.shields.io/badge/JUnit-5-25A162?logo=junit5)
![Allure](https://img.shields.io/badge/Report-Allure-yellow)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> Framework de automatización E2E guiado por especificaciones (Spec Driven Development) con Java 17, Selenium 4, Cucumber 7 y JUnit 5. POM, inyección de dependencias, ejecución en paralelo, Selenium Grid, Allure, CI (GitHub Actions y Jenkins) y un equipo de agentes de IA gobernado por reglas, hooks y un gate de calidad.

Framework de referencia para automatizar [SauceDemo](https://www.saucedemo.com) con Java 17, Selenium 4, Maven, Cucumber y JUnit 5. La solución aplica Page Object Model (POM), inyección de dependencias por escenario y una separación estricta entre especificación, orquestación, interfaz e infraestructura.

El objetivo verificable es que los cuatro casos de negocio —login exitoso, dos rechazos de login y compra de dos productos— se ejecuten en verde con:

```bash
./mvnw clean test
```

Selenium Manager resuelve el driver del navegador en tiempo de ejecución. No se descarga `chromedriver` manualmente, no se configura una ruta local y no se incorpora un gestor externo de drivers.

## Stack

| Componente | Versión | Responsabilidad |
|---|---:|---|
| Java | 17 | Lenguaje y runtime |
| Selenium | 4.45.0 | Automatización del navegador y Selenium Manager |
| Cucumber | 7.34.4 | Especificaciones BDD y ejecución de escenarios |
| JUnit | 5.14.2 | Suite de ejecución y aserciones |
| Allure Cucumber JVM | 2.29.1 | Resultados enriquecidos para Allure |
| SLF4J Simple | 2.0.16 | Registro de eventos |
| Maven Surefire | 3.5.3 | Ejecución de pruebas con Maven |

Las versiones de Cucumber y JUnit se administran con sus respectivos BOM en `dependencyManagement`; el resto se centraliza en las propiedades de `pom.xml`.

## Arquitectura por capas

```text
┌─────────────────────────────────────────────────────────────┐
│ features/ · reglas y escenarios de negocio en Gherkin       │
└─────────────────────────────┬───────────────────────────────┘
                              │ enlazan con
                              v
┌─────────────────────────────────────────────────────────────┐
│ steps/ · orquestación y aserciones JUnit 5                  │
└─────────────────────────────┬───────────────────────────────┘
                              │ usan
                              v
┌─────────────────────────────────────────────────────────────┐
│ pages/ · acciones, estado y localizadores de cada vista     │
└─────────────────────────────┬───────────────────────────────┘
                              │ extienden
                              v
┌─────────────────────────────────────────────────────────────┐
│ BasePage · interacción y esperas explícitas centralizadas   │
└─────────────────────────────┬───────────────────────────────┘
                              │ recibe infraestructura de
                              v
┌─────────────────────────────────────────────────────────────┐
│ utils/ · driver · configuración · secretos · contexto        │
└─────────────────────────────┬───────────────────────────────┘
                              │ controla
                              v
┌─────────────────────────────────────────────────────────────┐
│ Selenium WebDriver / navegador local o Selenium Grid        │
└─────────────────────────────────────────────────────────────┘

              hooks/ ── ciclo de vida y evidencia ──> utils/
```

Reglas de dependencia:

- Los `features` describen resultados observables en lenguaje de negocio y no conocen Selenium, selectores ni detalles visuales.
- Los `steps` dependen de las páginas y del contexto del escenario. Las aserciones JUnit 5 existen únicamente en esta capa.
- Las páginas exponen acciones y estado; no contienen aserciones, no comparten estado global y nunca invocan `driver.findElement` directamente.
- `BasePage` es el único punto para sincronizar e interactuar: visibilidad, clic, escritura, texto, invisibilidad, listas, URL y scroll.
- `utils` concentra configuración, creación/liberación del driver y estado por escenario; no depende de capas superiores.
- La lógica pura de configuración, secretos y credenciales vive en `src/main/java` (`com.demo.config`, `com.demo.data`), sin E/S ni Selenium: las fachadas de `utils` leen el entorno y delegan en ella. Es el código que verifican las pruebas unitarias y PIT (ADR-001).
- Los hooks administran el ciclo de vida y la evidencia, pero no implementan reglas de negocio.
- No se admiten dependencias circulares ni saltos de capa, por ejemplo, un feature que codifique un selector o una página que invoque un step.

## Estructura del proyecto

```text
.
├── .claude
│   ├── agents/          # equipo de agentes QE (ver README interno)
│   ├── rules/           # SDD, permisos, prompt injection, CHK
│   ├── hooks/           # gate DevOps y protección de la configuración (+ pruebas)
│   └── settings.json
├── .env.example
├── .github/workflows/ci.yml
├── .mvn/wrapper/maven-wrapper.properties
├── AGENTS.md
├── CLAUDE.md
├── MEMORY.md
├── Jenkinsfile
├── LICENSE
├── README.md
├── .gitignore
├── docker-compose.yml
├── docs
│   ├── adr/001-mutation-testing-pit.md
│   └── specs/           # _plantilla.md, login.md, compra.md
├── mvnw / mvnw.cmd
├── pom.xml
├── scripts/check-traceability.sh
├── src/main/java/com/demo      # lógica pura, sin E/S (ADR-001)
│   ├── config
│   │   ├── ConfigResolver.java
│   │   ├── DotEnvParser.java
│   │   └── SecretResolver.java
│   └── data/Credentials.java
└── src/test
    ├── java/com/demo
    │   ├── config/      # pruebas unitarias de src/main/.../config
    │   ├── data/        # pruebas unitarias de src/main/.../data
    │   ├── hooks/Hooks.java
    │   ├── pages
    │   │   ├── BasePage.java
    │   │   ├── CartPage.java
    │   │   ├── CheckoutPage.java
    │   │   ├── InventoryPage.java
    │   │   ├── LoginPage.java
    │   │   └── PageManager.java
    │   ├── runners/RunnerTest.java
    │   ├── steps
    │   │   ├── CompraSteps.java
    │   │   └── LoginSteps.java
    │   └── utils
    │       ├── ConfigReader.java
    │       ├── CredentialsProvider.java
    │       ├── DriverFactory.java
    │       ├── SecretReader.java
    │       └── TestContext.java
    └── resources
        ├── config.properties
        ├── features
        │   ├── compra_e2e.feature
        │   └── login.feature
```

## Decisiones de arquitectura

### `ThreadLocal<WebDriver>`

Cada hilo de ejecución recibe su propia instancia de `WebDriver`. Esto evita que dos escenarios paralelos naveguen, cierren o lean la misma sesión. `quitDriver()` cierra la sesión en un bloque de salida seguro y ejecuta `ThreadLocal.remove()` para que el hilo reutilizado no conserve referencias. El driver no es un singleton global: solo el contenedor `ThreadLocal` es compartido.

### PicoContainer y `TestContext`

Cucumber crea un grafo de objetos nuevo para cada escenario. PicoContainer inyecta por constructor el mismo `TestContext` en steps y hooks de ese escenario, sin campos estáticos ni service locator. Así, el driver y la selección temporal de productos tienen un dueño y un alcance explícitos; al comenzar el siguiente escenario se construye otro contexto limpio. La lista procede de `test.purchase.products` y se reutiliza para contrastar que el contenido real del carrito corresponda exactamente con lo configurado.

### `PageManager`

Los steps no instancian páginas. Reciben por constructor un `PageManager` (también inyectado por PicoContainer, uno por escenario) que crea cada Page Object de forma perezosa con el driver del escenario. Así, `LoginSteps` y `CompraSteps` comparten exactamente las mismas instancias de página, se elimina código duplicado y agregar una página nueva implica tocar un único punto.

### Esperas centralizadas

La espera implícita se establece en `Duration.ZERO` y `BasePage` concentra las esperas explícitas con el límite definido en `explicit.wait.seconds`. Esto evita combinar dos modelos de espera —una fuente común de tiempos impredecibles— y permite que todas las interacciones sigan la misma política. Las pausas fijas no forman parte de la estrategia porque retrasan siempre y no expresan la condición que se espera.

Las acciones sensibles esperan además una postcondición observable: el botón de producto adopta el texto configurado en `inventory.remove-button.text`, la ruta avanza al siguiente paso o el valor de un input permanece estable en dos sondeos. El intento inicial siempre usa las APIs nativas de WebDriver. Solo si Chrome pierde ese evento se reubica el elemento y se usa un respaldo JavaScript acotado; en inputs controlados se invoca el setter nativo y se emiten eventos `input/change` para que React actualice su estado. El respaldo también queda sujeto a la misma postcondición, por lo que no convierte un fallo real en un falso positivo.

### Compatibilidad de reportes JUnit

El plugin Maven requerido se conserva en `maven-surefire-plugin:3.5.3`. Esa versión ejecuta Cucumber 7.34.4, pero no asocia correctamente sus escenarios `UriSource` con el test set del runner y puede informar cero pruebas. El POM carga internamente el proveedor corregido `surefire-junit-platform:3.5.4`, versión que incorporó la corrección de Apache, para que un escenario fallido produzca XML y termine Maven con error. Así se evita aceptar un `BUILD SUCCESS` sin resultados reales y se mantiene la versión exacta del plugin solicitada.

### `By` frente a PageFactory y `@FindBy`

Se usan constantes privadas `By` porque hacen visible cuándo y cómo se localiza un elemento, funcionan de manera natural con los wrappers de `BasePage` y permiten construir localizadores dinámicos sin proxies. PageFactory no aporta valor aquí: sus proxies posponen la búsqueda, pueden ocultar el momento de una excepción y no resuelven por sí mismos sincronización ni elementos dinámicos.

### Configuración y secretos

Las fuentes están separadas deliberadamente:

```text
Configuración no sensible:  -Dpropiedad  >  variable de entorno  >  config.properties
Credenciales:                variable de entorno de CI  >  .env local
```

`ConfigReader` solo resuelve configuración no sensible y nunca abre `.env`. `SecretReader` solo consulta nombres explícitos de variables del sistema o del `.env`; nunca consulta `config.properties` ni propiedades JVM. `CredentialsProvider` construye objetos tipados para usuario estándar, usuario bloqueado y contraseña inválida, evitando que los steps conozcan el mecanismo de almacenamiento.

Esta separación impide que una credencial vuelva a `config.properties` por un fallback accidental. Una opción de ejecución no sensible puede sobrescribir el archivo sin modificar el repositorio; las variables del sistema reciben los secretos de CI y `.env` facilita el desarrollo local sin confirmar credenciales. Una entrada obligatoria ausente o vacía falla inmediatamente indicando únicamente su nombre, nunca su valor. `remote.url` es la única configuración que admite un valor vacío porque representa ejecución local.

Ejemplo: el archivo define `headless=false`; al ejecutar Maven con `-Dheadless=true`, la propiedad de sistema gana y activa la ejecución sin ventana.

Para configuración no sensible, las variables de entorno se aceptan con el nombre exacto o normalizado a mayúsculas, reemplazando puntos y guiones por guion bajo. Por ejemplo, `REMOTE_URL=http://localhost:4444` sobrescribe `remote.url`. Para secretos, `CredentialsProvider` usa directamente los nombres `TEST_*` declarados en `.env.example`; el lector no registra valores y admite líneas vacías, comentarios, el prefijo `export` y valores entre comillas.

### Estrategia de localizadores

La prioridad es `id`, después CSS con atributos estables como `data-test` y, solo cuando expresa una relación del DOM, XPath relativo. Se prohíben XPath absolutos e índices posicionales porque acoplan la prueba a la estructura visual. El botón de un producto es un caso dinámico legítimo: parte del nombre visible y encuentra el botón dentro del mismo contenedor `inventory_item`.

```xpath
//div[@data-test='inventory-item'][.//div[@data-test='inventory-item-name' and normalize-space()='Sauce Labs Backpack']]//button
```

El valor procedente de datos de prueba se convierte de forma segura en un literal XPath antes de construir el selector.

### Granularidad BDD

Cada feature representa una funcionalidad y cada escenario es completo e independiente. `login.feature` agrupa el acceso exitoso y sus rechazos; `compra_e2e.feature` narra una compra de punta a punta. Un `Background` solo establece el contexto común y un `Scenario Outline` elimina duplicación de casos equivalentes. Los features expresan intención y usan identificadores de caso; los valores concretos se resuelven desde la fuente tipada correspondiente para no duplicar credenciales, productos, mensajes ni datos personales en Gherkin y Java.

Ejemplo del estilo esperado:

```gherkin
@e2e
Scenario: Compra exitosa de dos productos
  Given que el usuario está autenticado para comprar
  When agrega los productos configurados al carrito
  Then el carrito refleja la cantidad de productos configurada
  And el carrito contiene los productos seleccionados
  When tramita la compra con los datos de envío configurados
  Then la compra se confirma con el mensaje configurado
```

El escenario comunica intención y resultado. El step decide qué páginas orquestar; la página decide cómo operar la interfaz.

## Configuración

Los valores no sensibles se encuentran en `src/test/resources/config.properties`:

```properties
base.url=https://www.saucedemo.com
browser=chrome
headless=false
remote.url=
explicit.wait.seconds=10
browser.window.width=1920
browser.window.height=1080

test.purchase.products=Sauce Labs Backpack,Sauce Labs Bike Light
test.checkout.first-name=Ada
test.checkout.last-name=Lovelace
test.checkout.postal-code=01000
```

| Grupo | Propiedades | Responsabilidad |
|---|---|---|
| Ejecución | `base.url`, `browser`, `headless`, `remote.url` | Ambiente y navegador |
| Sincronización | `explicit.wait.seconds` | Límite común de esperas explícitas |
| Ventana | `browser.window.width`, `browser.window.height` | Resolución headless |
| Navegación | `route.*` | Rutas esperadas entre páginas |
| UI esperada | `inventory.*`, `checkout.expected.confirmation` | Textos observables de la aplicación |
| Credenciales | Variables `TEST_USER_*` y `TEST_LOGIN_CASES_*` | `.env` local o gestor de secretos de CI |
| Casos negativos | `test.login.cases.<caso>.expected-error` | Resultado funcional esperado, no sensible |
| Compra | `test.purchase.products`, `test.checkout.*` | Productos y datos de envío |
| Evidencia | `evidence.screenshot.*` | Tipo y nombre de capturas en fallos |

### Credenciales locales

El repositorio solo conserva `.env.example`, sin valores. Para desarrollo local:

```bash
cp .env.example .env
```

Completar `.env` con valores obtenidos del almacén seguro autorizado. `.gitignore` excluye `.env` y todas sus variantes, salvo la plantilla. El archivo no es cifrado ni constituye un gestor de secretos: evita su versionado accidental, mientras que los permisos del equipo y del sistema operativo siguen siendo necesarios.

Los nombres de `.env.example` se referencian de forma explícita en `CredentialsProvider`; no se transforman en claves de propiedades. En depuración, el flujo navegable es `step → CredentialsProvider → SecretReader → variable del sistema/.env`. En CI no se crea `.env`: el gestor de credenciales inyecta directamente las mismas variables de entorno.

## Requisitos previos

- JDK 17 disponible en `JAVA_HOME`.
- Maven no es obligatorio: el proyecto incluye Maven Wrapper (`./mvnw` en Linux/macOS, `mvnw.cmd` en Windows), que descarga Maven 3.9.9 la primera vez.
- Chrome o Firefox instalado para ejecución local. Selenium Manager obtiene el driver compatible.
- Docker con Compose v2 para el ejemplo de Grid.
- Allure CLI para abrir el reporte Allure de forma local.

Comprobación rápida:

```bash
java -version
./mvnw -version
```

## Cómo ejecutar

Todos los escenarios:

```bash
./mvnw clean test
```

Solo los escenarios marcados como smoke:

```bash
./mvnw clean test -Dcucumber.filter.tags="@smoke"
```

En Chrome headless:

```bash
./mvnw clean test -Dheadless=true
```

En Firefox local:

```bash
./mvnw clean test -Dbrowser=firefox
```

Las opciones se pueden combinar:

```bash
./mvnw clean test \
  -Dheadless=true \
  -Dbrowser=chrome \
  -Dcucumber.filter.tags="@smoke"
```

### Ejecución contra Selenium Grid

Iniciar el hub y el nodo Chrome reales incluidos en este repositorio:

```bash
docker compose up -d
docker compose ps
```

La consola de Grid queda disponible en `http://localhost:4444/ui`. Ejecutar las pruebas desde el host:

```bash
./mvnw clean test \
  -Dremote.url=http://localhost:4444 \
  -Dbrowser=chrome \
  -Dheadless=true
```

Detener y retirar los contenedores:

```bash
docker compose down
```

`remote.url` debe apuntar a `http://selenium-hub:4444` únicamente cuando Maven se ejecute desde otro contenedor conectado a la misma red de Compose.

## Reportes y evidencia

Después de `./mvnw clean test` se generan:

- `target/cucumber-report.html`: reporte HTML de Cucumber.
- `target/surefire-reports/*.xml`: resultados JUnit consumibles por CI.
- `target/allure-results`: datos de entrada para Allure.

Abrir un reporte Allure temporal:

```bash
allure serve target/allure-results
```

Cuando un step falla, `@AfterStep` toma una captura PNG y la adjunta al escenario mediante la API de Cucumber. La captura aparece embebida en `target/cucumber-report.html` y queda disponible para el adaptador de Allure. No se captura en pasos exitosos para evitar ruido y consumo innecesario. El hook `@After` libera el navegador siempre, incluso después de una excepción.

Para comprobar la evidencia durante desarrollo, puede cambiarse temporalmente una expectativa por un valor incorrecto, ejecutar el escenario y abrir el HTML. Esa alteración deliberada no debe confirmarse en el repositorio.

## Extensiones CI/CD

### GitHub Actions

`.github/workflows/ci.yml` ejecuta la suite en headless en cada `push` y `pull request` a `main` (y manualmente con `workflow_dispatch`). Usa Temurin 17, la caché de Maven y el Chrome preinstalado del runner. Publica como artefactos el HTML de Cucumber, los XML de Surefire y los resultados Allure, incluso si hay fallos.

Las credenciales se leen de *Secrets* del repositorio (`Settings → Secrets and variables → Actions`) con los mismos nombres de `.env.example`:

`TEST_USER_STANDARD_USERNAME`, `TEST_USER_STANDARD_PASSWORD`, `TEST_LOGIN_CASES_LOCKED_USER_USERNAME`, `TEST_LOGIN_CASES_LOCKED_USER_PASSWORD`, `TEST_LOGIN_CASES_INVALID_PASSWORD_USERNAME`, `TEST_LOGIN_CASES_INVALID_PASSWORD_PASSWORD`.

### Jenkins

El `Jenkinsfile` declarativo contiene exactamente el flujo mínimo reproducible:

1. `Checkout` obtiene el commit bajo prueba.
2. `Test` obtiene tres pares de credenciales mediante `withCredentials`, valida Java/Maven y ejecuta `./mvnw -B -ntp clean test -Dheadless=true`.
3. `post/always` publica XML de Surefire, resultados Allure y el HTML de Cucumber aun cuando una prueba falle.

El agente de Jenkins necesita JDK 17, Maven y Chrome. Jenkins requiere los plugins Pipeline, Credentials Binding, JUnit y Allure; el servidor también debe tener configurada una instalación de Allure Commandline. El almacén de Jenkins debe proporcionar credenciales de tipo usuario/contraseña con los IDs `saucedemo-standard-user`, `saucedemo-locked-user` y `saucedemo-invalid-login`.

### Selenium Grid con Docker Compose

`docker-compose.yml` crea un hub y un nodo Chrome. Las variables `SE_EVENT_BUS_HOST`, `SE_EVENT_BUS_PUBLISH_PORT` y `SE_EVENT_BUS_SUBSCRIBE_PORT` registran el nodo en el bus de eventos del hub. `shm_size: 2gb` evita cierres de Chrome por memoria compartida insuficiente, un problema frecuente en Linux CI.

Para escalar a tres nodos sin cambiar el archivo:

```bash
docker compose up -d --scale node-chrome=3
```

No debe definirse `container_name` en el nodo porque impediría crear varias réplicas.

## Convenciones para extender el framework

Al agregar una funcionalidad:

1. Escribir primero un escenario independiente, observable y con vocabulario del dominio.
2. Reutilizar steps cuando expresen exactamente la misma intención; no reutilizarlos solo porque hacen clic en el mismo elemento.
3. Añadir el localizador privado a la página dueña de esa vista.
4. Implementar la interacción mediante un wrapper de `BasePage`; si falta una operación genérica, agregarla allí en vez de acceder al driver desde la página.
5. Orquestar páginas y realizar la aserción descriptiva en el step.
6. Ejecutar tanto el nuevo escenario como la suite completa.

Lista de control antes de integrar cambios:

```text
[ ] ./mvnw clean test termina en BUILD SUCCESS
[ ] @smoke ejecuta únicamente el alcance esperado
[ ] los escenarios no comparten estado
[ ] no hay pausas fijas ni esperas implícitas
[ ] no hay assert en pages
[ ] no hay driver.findElement fuera de BasePage
[ ] no hay XPath absoluto ni índice posicional frágil
[ ] no hay catch vacío
[ ] no hay variables, parámetros, campos privados ni métodos privados sin uso
[ ] no hay URLs, credenciales, datos de prueba, rutas, timeouts ni expectativas configurables en duro
[ ] `.env` está ignorado y solo `.env.example` permanece versionable y sin secretos
[ ] no hay gestores externos ni rutas fijas de drivers
[ ] un fallo conserva captura y los hooks cierran el navegador
```

## Solución de problemas

**Selenium Manager no puede obtener un driver.** Verificar salida a Internet, navegador instalado y permisos de la caché de Selenium. No solucionar el problema agregando una ruta fija al driver.

**Grid responde pero no crea sesión.** Confirmar `docker compose ps`, revisar `docker compose logs node-chrome` y comprobar que `browser=chrome`. La interfaz `/ui` debe mostrar al menos un slot disponible.

**Allure CLI no existe.** Las pruebas siguen siendo válidas y conservan `target/allure-results`; instalar Allure Commandline solo es necesario para ejecutar `allure serve`.

**No se ejecutan escenarios.** Confirmar que `RunnerTest` termina en `Test`, que selecciona el recurso `features` y que sus anotaciones `@ConfigurationParameter` declaran el glue de steps y hooks.

**IntelliJ muestra `no usages` en hooks o steps.** No significa que estén muertos: Cucumber descubre los métodos anotados y los invoca mediante reflexión a partir del glue y de los textos Gherkin. Por eso las clases de glue tienen una supresión `unused` acotada y documentada. No se crean llamadas artificiales desde producción o desde el runner, porque eso duplicaría el ciclo de vida y sí sería un defecto de diseño.

**Configuración de Cucumber.** El glue, los plugins y la publicación silenciosa están declarados en `RunnerTest` mediante `@ConfigurationParameter` y las constantes oficiales de Cucumber. Esto mantiene una única fuente de configuración con referencias visibles para el IDE y el análisis estático.

## Equipo de agentes QE y Spec Driven Development

El repositorio incluye un equipo de subagentes de Claude Code (`.claude/agents/`): arquitecto de automatización, diseñador de casos, ingeniero de automatización, **verificador independiente** e ingeniero DevOps. La sesión principal (`CLAUDE.md`) los coordina.

- **Spec Driven Development:** spec aprobada por una persona → feature trazada (`@AC-`, `@tec-`) → código. Ningún nivel se escribe sin el anterior (`.claude/rules/01`).
- **Permisos por agente:** qué puede escribir, leer y ejecutar cada rol, aplicado también con `permissions` en `.claude/settings.json` (`.claude/rules/02`).
- **Defensa contra prompt injection:** el contenido de la aplicación, los reportes y los archivos es dato, nunca instrucción (`.claude/rules/03`).
- **Comprobaciones deterministas:** catálogo CHK-01…16 (sleep, reintentos, capas, control negativo, mutación, trazabilidad) y un hook que bloquea `git push` sin el gate DevOps (`.claude/rules/04`).

Índice, justificación de roles y asignación de modelo: [`.claude/agents/README.md`](.claude/agents/README.md).

## Licencia

Distribuido bajo la licencia MIT. Consulta [`LICENSE`](LICENSE) para más detalles.

© 2026 Eduardo Avila Carranza
