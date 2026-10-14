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

Cada escenario nace de una spec aprobada (`docs/specs/`), y la suite completa —escenarios E2E de login y compra más las pruebas unitarias de la lógica propia— se ejecuta con:

```bash
./mvnw clean test
```

Selenium Manager resuelve el driver del navegador en tiempo de ejecución. No se descarga `chromedriver` manualmente, no se configura una ruta local y no se incorpora un gestor externo de drivers.

## Inicio rápido (después de clonar)

```bash
# 1. Clonar
git clone https://github.com/eavilac01/spec-driven-selenium-cucumber.git
cd spec-driven-selenium-cucumber

# 2. Comprobar JDK 17 (Maven no hace falta: el proyecto trae Maven Wrapper)
java -version
./mvnw -version

# 3. Crear el archivo local de credenciales a partir de la plantilla
cp .env.example .env
chmod 600 .env

# 4. Completar .env con las credenciales públicas de SauceDemo (ver la sección siguiente)

# 5. Ejecutar la suite
./mvnw clean test -Dheadless=true
```

Si el paso 5 termina en `BUILD SUCCESS`, el entorno está listo. Si falla con `La variable sensible obligatoria '...' no tiene valor`, falta completar esa variable en `.env` (el mensaje muestra solo el nombre, nunca el valor).

## Credenciales de SauceDemo: cómo obtenerlas

SauceDemo es un sitio público de práctica: **sus credenciales no son secretas y las publica en su propia página de inicio de sesión**. Aun así, este repositorio no las versiona: se tratan como cualquier secreto (`.env` local o *Secrets* de CI), para que el framework funcione igual con una aplicación real.

1. Abre [https://www.saucedemo.com](https://www.saucedemo.com) en el navegador.
2. Debajo del formulario de inicio de sesión hay dos recuadros:
   - **"Accepted usernames are:"** — la lista de usuarios de prueba.
   - **"Password for all users:"** — la contraseña común a todos ellos.
3. Copia esos valores en tu `.env` según esta tabla:

| Variable de `.env` | Qué valor poner |
|---|---|
| `TEST_USER_STANDARD_USERNAME` | El usuario **estándar** de la lista (el que empieza por `standard`) |
| `TEST_USER_STANDARD_PASSWORD` | La contraseña común que muestra la página |
| `TEST_LOGIN_CASES_LOCKED_USER_USERNAME` | El usuario **bloqueado** de la lista (el que contiene `locked_out`) |
| `TEST_LOGIN_CASES_LOCKED_USER_PASSWORD` | La misma contraseña común |
| `TEST_LOGIN_CASES_INVALID_PASSWORD_USERNAME` | El usuario estándar otra vez |
| `TEST_LOGIN_CASES_INVALID_PASSWORD_PASSWORD` | **Cualquier valor distinto** de la contraseña común (ver abajo cómo generarlo) |

Para el caso de contraseña incorrecta conviene un valor aleatorio, así nunca coincide por accidente con la real:

```bash
openssl rand -hex 12
```

El resultado de `.env` tiene esta forma (los valores reales los copias tú de la página):

```dotenv
TEST_USER_STANDARD_USERNAME=<usuario estándar de la página>
TEST_USER_STANDARD_PASSWORD=<contraseña común de la página>
TEST_LOGIN_CASES_LOCKED_USER_USERNAME=<usuario bloqueado de la página>
TEST_LOGIN_CASES_LOCKED_USER_PASSWORD=<contraseña común de la página>
TEST_LOGIN_CASES_INVALID_PASSWORD_USERNAME=<usuario estándar de la página>
TEST_LOGIN_CASES_INVALID_PASSWORD_PASSWORD=<valor aleatorio, distinto de la contraseña común>
```

Reglas de seguridad que aplica el proyecto:

- `.env` está en `.gitignore`; solo `.env.example` (sin valores) se versiona.
- Ningún log, reporte ni mensaje de error imprime un valor de `.env`: los errores nombran la variable, nunca su contenido.
- El objeto de credenciales se imprime enmascarado (`Credentials[username=***, password=***]`).
- Nunca pegues las credenciales en `config.properties`, en una feature ni en el código.

Si SauceDemo cambia sus usuarios o su contraseña, basta con actualizar `.env` (y los *Secrets* de CI): ningún archivo del repositorio cambia.

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

La arquitectura se describe en tres vistas, de lo general a lo particular:

1. **Contexto:** con qué sistemas externos habla el framework.
2. **Capas:** cómo se organiza el código y qué dependencias están autorizadas.
3. **Cadena de calidad:** qué controles recorre un cambio hasta llegar a `main`.

Las decisiones que las sostienen están en los ADR de [`docs/adr/`](docs/adr/).

### Vista de contexto

```mermaid
flowchart LR
    qa(["<b>Equipo QA</b><br/>y contribuidores"])
    agents["<b>Equipo de agentes QE</b><br/>Claude Code · .claude/<br/>reglas, permisos y hooks"]

    subgraph REPO["Repositorio · GitHub"]
        direction TB
        fw["<b>spec-driven-selenium-cucumber</b><br/>Java 17 · Selenium 4 · Cucumber 7 · JUnit 5"]
        docs["<b>docs/</b><br/>specs aprobadas · ADR · cuarentena"]
    end

    subgraph CI["Integración continua"]
        direction TB
        gha["<b>GitHub Actions</b><br/>6 jobs · checks requeridos en main"]
        jenkins["<b>Jenkins</b><br/>Jenkinsfile equivalente"]
    end

    subgraph EXT["Servicios externos"]
        direction TB
        sut[("<b>SauceDemo</b><br/>sistema bajo prueba")]
        grid[("<b>Selenium Grid</b><br/>Docker, imagen por digest")]
        central[("<b>Maven Central</b><br/>Maven 3.9.9 con checksum<br/>y dependencias")]
    end

    reports[["<b>Evidencia</b><br/>Cucumber HTML · Allure<br/>Surefire · PIT"]]

    qa -->|spec, PR y revisión| REPO
    agents -->|delegación con gate y control negativo| REPO
    docs -.->|rige| fw
    REPO -->|push / pull request| gha
    REPO -->|pipeline| jenkins
    fw ==>|HTTPS · navegador real| sut
    fw -.->|remote.url| grid
    grid ==> sut
    gha & jenkins -.->|./mvnw| central
    gha & jenkins -->|publican| reports

    classDef actor fill:#FFFFFF,stroke:#0F172A,stroke-width:1.5px,color:#0F172A
    classDef core fill:#FFFFFF,stroke:#1D4ED8,stroke-width:3px,color:#0F172A
    classDef neutral fill:#FFFFFF,stroke:#94A3B8,stroke-width:1px,color:#0F172A
    classDef external fill:#0F172A,stroke:#0F172A,color:#FFFFFF
    class qa,agents actor
    class fw core
    class docs,gha,jenkins,reports neutral
    class sut,grid,central external
    style REPO fill:#E8EEFB,stroke:#B9C7EE,color:#1E3A8A
    style CI fill:#F5F6F8,stroke:#D5DAE1,color:#334155
    style EXT fill:#F5F6F8,stroke:#D5DAE1,color:#334155
```

**Sin salidas de red no autorizadas:**
- La única URL del SUT es `base.url` (PI-08).
- Selenium Manager no envía telemetría (`SE_AVOID_STATS=true`).
- Chrome no consulta el servicio de contraseñas filtradas (ADR-002, D8).
- Las pruebas de contrato del transporte usan páginas locales `file:`, sin red (ADR-004).

### Vista de capas

Cada flecha del diagrama es una **dependencia autorizada** por el [ADR-002](docs/adr/002-transport-and-business-actions.md) (D4) y el [ADR-004](docs/adr/004-transport-contract-tests.md). Cualquier otra la rechaza **CHK-17** en cada ejecución del CI, por ejemplo:
- un step que importe una página;
- Selenium fuera de `transport`;
- un segundo clic nativo;
- una clase que nombre `contract`.

```mermaid
flowchart TB
    subgraph SDD["Especificación · SDD (Regla 01)"]
        direction TB
        spec["<b>Spec aprobada</b><br/>criterios AC con su ID<br/>docs/specs"]
        feat["<b>features</b><br/>Gherkin con @AC- y @tec-<br/>src/test/resources/features"]
    end

    subgraph ORQ["Orquestación y contrato · capa 5"]
        direction TB
        runner["<b>runners · RunnerTest</b><br/>JUnit Platform Suite + Cucumber"]
        hooks["<b>hooks</b><br/>inician, capturan y cierran"]
        contract["<b>contract</b> · ADR-004<br/>pruebas JUnit de Navegador<br/>contra páginas locales"]
    end

    subgraph CAPAS["Capas de ejecución · verificadas por CHK-17"]
        direction TB
        steps["<b>steps</b><br/>aserciones contra valores esperados"]
        actions["<b>actions</b><br/>flujos de negocio, sin aserciones"]
        pages["<b>pages</b><br/>estado y localizadores · solo By"]
        transport["<b>transport · Navegador</b><br/>único dueño del WebDriver y de las esperas<br/>un clic y una escritura nativos por acción<br/><b>DriverFactory</b>: Chrome, Firefox o Grid"]
    end

    selenium[("<b>Selenium WebDriver</b><br/>Chrome · Firefox · Grid")]

    subgraph SOPORTE["Soporte · datos y configuración (capa 4)"]
        direction TB
        utils["<b>utils · fachadas</b><br/>ConfigReader · SecretReader<br/>CredentialsProvider · TestContext<br/>leen entorno, .env y config"]
        pure["<b>src/main · lógica pura</b><br/>config: ConfigResolver · BrowserSettings<br/>BrowserErrorPage · ClicNativoUnico<br/>data: Credentials<br/>sin E/S ni Selenium · mutada por PIT"]
        props[/"<b>config.properties</b> · URL, rutas y *.expected*<br/><b>.env</b> o Secrets · credenciales"/]
    end

    sut[("<b>SauceDemo</b><br/>base.url")]
    localpages[/"<b>Páginas locales</b><br/>src/test/resources/contract · file:"/]

    spec -->|deriva| feat
    feat ==>|enlaza| steps
    runner -.->|descubre el glue| steps
    steps ==>|usa| actions
    actions ==>|orquesta| pages
    pages ==>|solo vía Navegador| transport
    transport ==>|controla| selenium
    selenium ==>|HTTPS| sut
    steps -.->|configura| utils
    utils -.->|delega| pure
    utils -.->|lee| props
    pages -.->|rutas y textos| utils
    transport -.->|configuración, describeHost<br/>y ClicNativoUnico| pure
    hooks -.->|ciclo de vida| transport
    contract ==>|API pública| transport
    contract -.->|abre| localpages

    classDef layer fill:#FFFFFF,stroke:#1D4ED8,stroke-width:1.5px,color:#0F172A
    classDef owner fill:#FFFFFF,stroke:#1D4ED8,stroke-width:3px,color:#0F172A
    classDef neutral fill:#FFFFFF,stroke:#94A3B8,stroke-width:1px,color:#0F172A
    classDef driver fill:#0F172A,stroke:#0F172A,color:#FFFFFF
    class steps,actions,pages layer
    class transport owner
    class spec,feat,runner,utils,pure,hooks,contract,props,localpages neutral
    class selenium,sut driver
    style CAPAS fill:#E8EEFB,stroke:#B9C7EE,color:#1E3A8A
    style SDD fill:#F5F6F8,stroke:#D5DAE1,color:#334155
    style ORQ fill:#F5F6F8,stroke:#D5DAE1,color:#334155
    style SOPORTE fill:#F5F6F8,stroke:#D5DAE1,color:#334155
```

> Flechas gruesas: cadena de ejecución de un escenario y de una prueba de contrato. Flechas punteadas: soporte (descubrimiento, configuración, datos y ciclo de vida). Ningún paquete nombra `contract`, y `contract` solo nombra `transport` y `ConfigReader`.

### Responsabilidad de cada capa

| Capa | Paquete | Responsabilidad | Puede depender de | Nunca |
|---|---|---|---|---|
| Especificación | `docs/specs`, `features` | Qué se espera del negocio, con criterios `AC-*` trazables | — | Selectores ni vocabulario de interfaz |
| Steps | `com.demo.steps` | Aserciones JUnit 5 contra valores esperados de configuración | `actions`, `utils`, `data` | Importar páginas, `transport` ni Selenium |
| Acciones | `com.demo.actions` | Flujos de negocio entre páginas; devuelven lo observado | `pages`, `data` | Aserciones, lectura de valores esperados, páginas en sus firmas públicas, herencia |
| Páginas | `com.demo.pages` | Estado y localizadores de cada vista, por composición | `transport`, `ConfigReader` | Selenium distinto de `By`, aserciones, herencia |
| Transporte | `com.demo.transport` | `Navegador`: único dueño del `WebDriver`, esperas explícitas y postcondiciones, con un solo clic y una sola escritura nativos por acción. `DriverFactory`: Chrome, Firefox o Grid, con las preferencias de D8 | `utils` (solo `ConfigReader`), `config` | Lógica de negocio, tipos de Selenium en sus firmas públicas (`By` solo como parámetro), imports de Selenium con comodín, herencia |
| Fachadas | `com.demo.utils` | Leen entorno, `.env` y `config.properties`; delegan en `src/main` | `config`, `data` | Depender de capas superiores, herencia |
| Lógica pura | `com.demo.config`, `com.demo.data` (`src/main`) | Resolución de configuración y de su fuente, secretos, credenciales, opciones y preferencias del navegador (D8), páginas de error de Chrome, el clic nativo único (`ClicNativoUnico`, ADR-004) y `describeHost`, la única regla para nombrar una URL en un log (PI-09) | Solo entre sí | E/S, Selenium, Cucumber, JUnit |
| Hooks | `com.demo.hooks` | Inician el navegador, adjuntan la captura si falla y lo cierran | `transport`, `utils` | Reglas de negocio |
| Runners | `com.demo.runners` | `RunnerTest`: JUnit Platform Suite que ejecuta Cucumber con su glue y sus plugins | Ninguno: el glue se declara como texto | Lógica de prueba |
| Contrato del transporte | `com.demo.contract` (ADR-004) | Pruebas JUnit de la API pública de `Navegador` contra páginas locales estáticas (`src/test/resources/contract`, por `file:`): clic único, pista de D8 y fallo cerrado | `transport`, `ConfigReader` | Selenium distinto de `By`, red, `base.url`/`remote.url`, temporizadores o eventos sintéticos en sus páginas; ningún otro paquete la nombra |

### Garantías automáticas

| Comprobación | Qué impide | Dónde corre |
|---|---|---|
| **CHK-17** · `scripts/check-layers.sh` | Saltos de capa (reglas R1–R6): firmas expuestas (públicas o protegidas, con anotaciones o modificadores en cualquier orden), cualquier tipo de Selenium importado o calificado en las firmas del transporte, imports con comodín y herencia en `transport`, `pages`, `actions` y `utils`; en `transport`, un único clic nativo, `executeScript` solo con scripts de una lista cerrada y ningún evento sintético; y exige que `DriverFactory` aplique la preferencia de Chrome de D8. Con autoprueba en la matriz de awk y mutantes | CI (job `mutation`) y Jenkins |
| **CHK-12** · `scripts/check-traceability.sh` | Escenarios sin spec aprobada o sin `@AC-`/`@tec-` | CI y Jenkins, antes de la suite |
| **CHK-15/16** · `scripts/check-unit-purity.sh` | E/S o Selenium en `src/main`; pruebas unitarias acopladas | CI (job `mutation`) y Jenkins |
| **CHK-11** · PIT + `scripts/check-mutation-report.sh` | Pruebas unitarias que no detectan defectos (umbral 80 %) | CI (job `mutation`) y Jenkins |
| **CHK-14** · `scripts/check-quarantine.sh` | Pruebas en cuarentena sin registro, sin dueño o con plazo vencido | CI (job `mutation`) y Jenkins |
| **CHK-18** · `scripts/check-awk-portability.sh` y `scripts/run-with-each-awk.sh` | Scripts que solo funcionan con una implementación de awk (en el runner de GitHub `awk` es gawk; en Ubuntu de escritorio, mawk): control estático y autopruebas con mawk, gawk y `gawk --posix` | CI (job `mutation`, exige las tres) y Jenkins (con los awk del agente) |
| **CHK-19** · `scripts/check-no-expected-override.sh` | Una ejecución E2E en verde contra un valor esperado inyectado por `-D` (por ejemplo desde `MAVEN_ARGS`): si el log trae el aviso de `ConfigReader`, el job falla (ADR-003, R-2) | CI (`test`, `e2e-firefox`, `e2e-grid`, `quarantine`; autoprueba en `mutation`) y Jenkins (`Test`, `Cuarentena (CHK-14)`) |

### Cadena de calidad: de un cambio a `main`

```mermaid
flowchart LR
    subgraph LOCAL["Local · equipo de agentes"]
        direction TB
        change["<b>Cambio</b><br/>spec → feature → código<br/>o ADR → código"]
        verifier["<b>Verificador independiente</b><br/>control negativo · mutación<br/>sin permisos de escritura"]
        gate["<b>Gate DevOps</b><br/>CHK-01…19 · CHK-08 ×2<br/>.claude/devops-gate.json"]
        hook{{"<b>Hook de push</b><br/>sin gate APROBADO<br/>sobre HEAD: bloqueado"}}
    end

    subgraph GH["GitHub"]
        direction TB
        branch["<b>Rama</b><br/>commits firmados"]
        pr["<b>Pull request</b><br/>plantilla con trazabilidad y CHK"]
        actions["<b>GitHub Actions</b><br/>test · e2e-firefox · e2e-grid<br/>mutation · quarantine"]
        ruleset{{"<b>Ruleset proteger-main</b><br/>5 checks en verde · firmas<br/>sin force push ni push directo"}}
        main[("<b>main</b>")]
    end

    change --> verifier --> gate --> hook
    hook -->|git push| branch --> pr --> actions --> ruleset -->|merge commit| main

    classDef step fill:#FFFFFF,stroke:#94A3B8,stroke-width:1px,color:#0F172A
    classDef control fill:#FFFFFF,stroke:#1D4ED8,stroke-width:3px,color:#0F172A
    classDef target fill:#0F172A,stroke:#0F172A,color:#FFFFFF
    class change,branch,pr,actions step
    class verifier,gate,hook,ruleset control
    class main target
    style LOCAL fill:#F5F6F8,stroke:#D5DAE1,color:#334155
    style GH fill:#E8EEFB,stroke:#B9C7EE,color:#1E3A8A
```

> En los pull requests de forks, los E2E se omiten porque no reciben secrets (`fork-pr-notice`), y un mantenedor los ejecuta antes de aprobar. Jenkins reproduce los jobs `test`, `mutation` y `quarantine` (ver [Jenkins](#jenkins)).

Las reglas completas (R1–R7) y su equivalente en ArchUnit están en el [ADR-002](docs/adr/002-transport-and-business-actions.md); la decisión de mutar solo la lógica pura, en el [ADR-001](docs/adr/001-mutation-testing-pit.md); y las fuentes permitidas para los valores esperados y las URL, en el [ADR-003](docs/adr/003-expected-values-config-sources.md).

## Estructura del proyecto

### Mapa del repositorio y sus dueños

Cada parte del repositorio tiene **un dueño** que puede escribirla. Los demás solo la leen y le devuelven el trabajo por handoff ([Regla 02](.claude/rules/02-agent-permissions.md)). Las flechas indican qué artefacto origina a cuál.

```mermaid
flowchart LR
    subgraph USR["Usuario (autor del repositorio)"]
        direction TB
        cfg[".claude/ · CLAUDE.md · AGENTS.md<br/>reglas, agentes, hooks y permisos"]
        approve["Aprobación de specs<br/>y de PR"]
    end

    subgraph ARQ["qa-automation-architect"]
        adr["docs/adr/<br/>ADR-001 … ADR-004"]
    end

    subgraph DIS["qa-test-designer"]
        specs["docs/specs/<br/>login · compra"]
        features["src/test/resources/features/"]
    end

    subgraph ENG["qa-automation-engineer"]
        direction TB
        main["src/main/java<br/>lógica pura"]
        test["src/test/java<br/>capas, unitarias y contrato"]
        res["config.properties · contract/<br/>.env.example"]
    end

    subgraph OPS["devops-engineer"]
        direction TB
        ci[".github/ · Jenkinsfile<br/>docker-compose.yml"]
        build["pom.xml (plugins) · .mvn/wrapper/<br/>junit-platform.properties"]
        scripts["scripts/ · docs/quarantine.md<br/>.claude/devops-gate.json"]
    end

    subgraph VER["qa-test-verifier"]
        ver["Solo lee y ejecuta<br/>veredicto independiente"]
    end

    coord["<b>Coordinador</b><br/>MEMORY.md · README.md<br/>CONTRIBUTING.md · SECURITY.md"]

    approve -->|aprueba| specs
    specs -->|deriva| features
    features -->|SDD-02| test
    adr -->|aplica| test
    adr -->|aplica| scripts
    test -.->|revisa| ver
    ver -.->|APROBADO| scripts
    coord -.->|delega| ARQ & DIS & ENG & OPS & VER

    classDef box fill:#FFFFFF,stroke:#94A3B8,stroke-width:1px,color:#0F172A
    classDef lead fill:#FFFFFF,stroke:#1D4ED8,stroke-width:3px,color:#0F172A
    class cfg,approve,adr,specs,features,main,test,res,ci,build,scripts,ver box
    class coord lead
    style USR fill:#F5F6F8,stroke:#D5DAE1,color:#334155
    style ARQ fill:#E8EEFB,stroke:#B9C7EE,color:#1E3A8A
    style DIS fill:#E8EEFB,stroke:#B9C7EE,color:#1E3A8A
    style ENG fill:#E8EEFB,stroke:#B9C7EE,color:#1E3A8A
    style OPS fill:#E8EEFB,stroke:#B9C7EE,color:#1E3A8A
    style VER fill:#F5F6F8,stroke:#D5DAE1,color:#334155
```

### Árbol de archivos

```text
.
├── .claude                      # configuración del equipo de agentes (la cambia solo el usuario)
│   ├── agents/                  # README del equipo y los 5 agentes:
│   │                            #   qa-automation-architect, qa-test-designer, qa-automation-engineer,
│   │                            #   qa-test-verifier y devops-engineer
│   ├── rules/                   # 01 SDD · 02 permisos · 03 prompt injection · 04 catálogo CHK-01…19
│   ├── hooks
│   │   ├── devops-gate-hook.sh      # bloquea git push sin .claude/devops-gate.json APROBADO sobre HEAD
│   │   ├── protect-config-hook.sh   # bloquea escrituras por Bash en .claude/**, CLAUDE.md, MEMORY.md,
│   │   │                            # AGENTS.md y .github/** (solo Edit/Write, con confirmación)
│   │   └── tests/                   # batería del hook de protección
│   └── settings.json            # permisos (deny/ask) y registro de los hooks
├── .github
│   ├── workflows/ci.yml         # 6 jobs; acciones fijadas por SHA e imagen del Grid por digest
│   ├── ISSUE_TEMPLATE/          # defecto del framework · divergencia sistema/spec · enlace al reporte privado
│   └── PULL_REQUEST_TEMPLATE.md # trazabilidad (spec, AC, ADR) y CHK ejecutadas
├── .mvn/wrapper/maven-wrapper.properties   # Maven 3.9.9 con distributionSha256Sum
├── .env.example                 # nombres de las 6 variables de credenciales, sin valores
├── .gitattributes · .gitignore
├── AGENTS.md                    # guía para cualquier agente de código
├── CLAUDE.md                    # coordinación del equipo y reglas obligatorias
├── MEMORY.md                    # estado, decisiones y próximos pasos entre sesiones
├── CONTRIBUTING.md              # flujo SDD, comprobaciones locales y PR de forks
├── SECURITY.md                  # reporte privado de vulnerabilidades y alcance
├── README.md · LICENSE (MIT)
├── Jenkinsfile                  # pipeline equivalente a test, mutation y quarantine (verificado en Jenkins real)
├── docker-compose.yml           # Selenium Grid local: hub + nodo Chrome, por digest
├── mvnw / mvnw.cmd · pom.xml    # Maven Wrapper y build (Surefire, PIT, SE_AVOID_STATS)
├── docs
│   ├── adr
│   │   ├── 001-mutation-testing-pit.md                 # PIT solo sobre la lógica pura
│   │   ├── 002-transport-and-business-actions.md       # capas, transporte y reglas de CHK-17
│   │   ├── 003-expected-values-config-sources.md       # fuentes de esperados y URL; CHK-19
│   │   └── 004-transport-contract-tests.md             # pruebas de contrato del transporte; ClicNativoUnico
│   ├── quarantine.md            # registro de la cuarentena reglada (CHK-14)
│   └── specs/                   # _plantilla.md · login.md · compra.md (aprobadas)
├── scripts
│   ├── check-awk-portability.sh      # CHK-18: construcciones exclusivas de una implementación de awk
│   ├── check-layers.sh               # CHK-17: reglas de capas (R1–R6)
│   ├── check-mutation-report.sh      # CHK-11: guarda del reporte de PIT
│   ├── check-no-expected-override.sh # CHK-19: esperados y destinos de red por -D, por job
│   ├── check-quarantine.sh           # CHK-14: registro de cuarentena frente a @quarantine
│   ├── check-required-secrets.sh     # CI/Jenkins: nombra los secrets que faltan
│   ├── check-traceability.sh         # CHK-12: escenario → spec aprobada
│   ├── check-unit-purity.sh          # CHK-15/16: src/main puro y unitarias aisladas
│   ├── evaluate-quarantine-run.sh    # evalúa el job quarantine (fallo esperado vs. error real)
│   ├── run-with-each-awk.sh          # CHK-18: ejecuta un comando con cada awk (mawk, gawk, gawk --posix, busybox)
│   ├── wait-for-grid.sh              # espera activa a que el Grid esté listo
│   └── tests/                        # autopruebas:
│                                     #   check-awk-portability-test.sh · check-layers-test.sh
│                                     #   check-no-expected-override-test.sh · check-quarantine-test.sh
│                                     #   evaluate-quarantine-run-test.sh · run-with-each-awk-test.sh
├── src/main/java/com/demo       # lógica pura, sin E/S ni Selenium (ADR-001); la muta PIT
│   ├── config
│   │   ├── BrowserErrorPage.java     # reconoce las páginas de error de Chrome (net::ERR_*), solo con el host
│   │   ├── BrowserSettings.java      # opciones del navegador y preferencias de Chrome (D8)
│   │   ├── ClicNativoUnico.java      # un clic nativo por acción; fallo cerrado si el clic lanza (ADR-004)
│   │   ├── ConfigResolver.java       # precedencia -D > entorno > archivo (esperados y URL sin entorno), fuente y describeHost
│   │   ├── DotEnvParser.java
│   │   └── SecretResolver.java
│   └── data/Credentials.java         # credenciales con toString enmascarado
└── src/test
    ├── java/com/demo
    │   ├── config/      # pruebas unitarias de src/main/.../config
    │   ├── data/        # pruebas unitarias de src/main/.../data
    │   ├── actions
    │   │   ├── CompraActions.java
    │   │   └── LoginActions.java
    │   ├── contract/    # pruebas de contrato de Navegador contra páginas locales (ADR-004)
    │   ├── hooks/Hooks.java
    │   ├── pages
    │   │   ├── CartPage.java
    │   │   ├── CheckoutPage.java
    │   │   ├── InventoryPage.java
    │   │   ├── LoginPage.java
    │   │   ├── MenuPage.java
    │   │   └── XPathLiteral.java   # literal XPath seguro para localizadores con datos
    │   ├── runners/RunnerTest.java
    │   ├── steps
    │   │   ├── CompraSteps.java
    │   │   └── LoginSteps.java
    │   ├── transport
    │   │   ├── DriverFactory.java  # Chrome, Firefox o Grid; aplica chromePreferences (D8)
    │   │   └── Navegador.java      # único dueño del WebDriver; un clic y una escritura nativos por acción
    │   └── utils
    │       ├── ConfigReader.java       # fachada de configuración; avisa de esperados por -D y registra destinos
    │       ├── CredentialsProvider.java
    │       ├── SecretReader.java
    │       └── TestContext.java
    └── resources
        ├── config.properties           # URL, rutas, valores esperados (*.expected*) y datos no sensibles
        ├── junit-platform.properties   # paralelismo por escenario (2 hilos)
        ├── contract/                   # páginas HTML estáticas de las pruebas de contrato (ADR-004)
        └── features
            ├── compra_e2e.feature
            └── login.feature
```

### Vista de diseño

La misma estructura, organizada en cuatro bloques, con la etiqueta del dueño de cada carpeta según la [Regla 02](.claude/rules/02-agent-permissions.md):

1. **Código del framework**
2. **Especificación y decisiones**
3. **Calidad y entrega**
4. **Gobierno y comunidad**

<p align="center">
  <a href="docs/assets/estructura-del-proyecto.png">
    <img src="docs/assets/estructura-del-proyecto.png" alt="Estructura del proyecto: cuatro bloques. 01 Código del framework (src/main/java, src/test/java/com/demo y src/test/resources, del engineer). 02 Especificación y decisiones (docs/specs y features del designer, docs/adr del architect y docs/quarantine.md de devops). 03 Calidad y entrega (scripts y CI/CD y build, de devops). 04 Gobierno y comunidad (.claude del usuario; instrucciones, memoria y archivos del repositorio público, del coordinador)." width="100%">
  </a>
</p>

> Haz clic en la imagen para verla a tamaño completo (3120×2980).

## Decisiones de arquitectura

### `Navegador`: un dueño del `WebDriver` por escenario (ADR-002)

`com.demo.transport.Navegador` es el único dueño del `WebDriver` y del `WebDriverWait`. PicoContainer crea una instancia por escenario, compartida por `Hooks` y las páginas; `Hooks` lo inicia, adjunta la captura si el escenario falla y lo cierra de forma idempotente. No hay `ThreadLocal` ni estado estático: el aislamiento lo da el contenedor por escenario. Su API solo recibe `By` y tipos de Java y nunca devuelve tipos de Selenium, de modo que Selenium queda confinado a `transport`.

### PicoContainer y `TestContext`

Cucumber crea un grafo de objetos nuevo para cada escenario. PicoContainer construye por constructor, de forma transitiva, `Navegador`, las páginas, las acciones, `TestContext` y los steps de ese escenario, sin campos estáticos ni service locator. `TestContext` solo guarda el estado de los steps (qué juego de valores esperados del carrito aplica); al comenzar el siguiente escenario se construye otro grafo limpio.

### Acciones de negocio en lugar de `PageManager`

Los steps no conocen las páginas: reciben por constructor `LoginActions` y `CompraActions`, que PicoContainer construye con las páginas del escenario. Las acciones expresan el flujo de negocio (iniciar sesión, agregar productos, tramitar la compra) y devuelven lo observado; los steps comparan contra los valores esperados de la configuración. Así cada capa tiene una sola razón para cambiar y no hace falta un registro de páginas aparte.

### Esperas centralizadas

La espera implícita se establece en `Duration.ZERO` y `Navegador` concentra las esperas explícitas con el límite definido en `explicit.wait.seconds`. Esto evita combinar dos modelos de espera —una fuente común de tiempos impredecibles— y permite que todas las interacciones sigan la misma política. Las pausas fijas no forman parte de la estrategia porque retrasan siempre y no expresan la condición que se espera.

Las acciones sensibles esperan además una postcondición observable: el botón de producto adopta el texto configurado en `inventory.remove-button.text`, la ruta avanza al siguiente paso o el valor de un input permanece estable en dos sondeos. Cada acción hace **un solo clic o una sola escritura nativos** de WebDriver y espera su postcondición; no hay respaldo JavaScript (ADR-002, D1 y D8). Un clic por JavaScript se salta la comprobación de qué elemento recibe el clic del navegador y puede dar por buena una interacción que un usuario real no podría hacer. Si la postcondición no llega, la prueba falla con un mensaje que dice si el clic tuvo efecto.

Los clics y escrituras nativos que se perdían en Chrome tenían una causa concreta: tras el login, Chrome consulta si la contraseña aparece en filtraciones conocidas y muestra un aviso que en headless no se ve y que descarta la entrada nativa. Ocurre cuando el servicio de Google responde (y no con un 429), por eso parecía depender de la carga de la máquina. `BrowserSettings.chromePreferences()` desactiva esa comprobación (`profile.password_manager_leak_detection=false`) y `DriverFactory` la aplica en local y en Grid. Si una versión futura de Chrome renombra la preferencia, la suite dará rojo con la pista "revisar las preferencias de Chrome (ADR-002, D8)" en vez de ocultarlo.

### Compatibilidad de reportes JUnit

El plugin Maven requerido se conserva en `maven-surefire-plugin:3.5.3`. Esa versión ejecuta Cucumber 7.34.4, pero no asocia correctamente sus escenarios `UriSource` con el test set del runner y puede informar cero pruebas. El POM carga internamente el proveedor corregido `surefire-junit-platform:3.5.4`, versión que incorporó la corrección de Apache, para que un escenario fallido produzca XML y termine Maven con error. Así se evita aceptar un `BUILD SUCCESS` sin resultados reales y se mantiene la versión exacta del plugin solicitada.

### `By` frente a PageFactory y `@FindBy`

Se usan constantes privadas `By` porque hacen visible cuándo y cómo se localiza un elemento, funcionan de manera natural con la API de `Navegador` y permiten construir localizadores dinámicos sin proxies. PageFactory no aporta valor aquí: sus proxies posponen la búsqueda, pueden ocultar el momento de una excepción y no resuelven por sí mismos sincronización ni elementos dinámicos.

### Configuración y secretos

Las fuentes están separadas deliberadamente:

```text
Configuración no sensible:  -Dpropiedad  >  variable de entorno  >  config.properties
Esperados y URL:            -Dpropiedad  >  config.properties
Credenciales:                variable de entorno de CI  >  .env local
```

`ConfigReader` solo resuelve configuración no sensible y nunca abre `.env`. `SecretReader` solo consulta nombres explícitos de variables del sistema o del `.env`; nunca consulta `config.properties` ni propiedades JVM. `CredentialsProvider` construye objetos tipados para usuario estándar, usuario bloqueado y contraseña inválida, evitando que los steps conozcan el mecanismo de almacenamiento.

Esta separación impide que una credencial vuelva a `config.properties` por un fallback accidental. Una opción de ejecución no sensible puede sobrescribir el archivo sin modificar el repositorio, salvo los valores esperados (`*.expected*`) y las URL (`base.url`, `remote.url`), que solo aceptan `-D` (ADR-003); las variables del sistema reciben los secretos de CI y `.env` facilita el desarrollo local sin confirmar credenciales. Una entrada obligatoria ausente o vacía falla inmediatamente indicando únicamente su nombre, nunca su valor. `remote.url` es la única configuración que admite un valor vacío porque representa ejecución local.

Ejemplo: el archivo define `headless=false`; al ejecutar Maven con `-Dheadless=true`, la propiedad de sistema gana y activa la ejecución sin ventana.

Para configuración no sensible, las variables de entorno se aceptan con el nombre exacto o normalizado a mayúsculas, reemplazando puntos y guiones por guion bajo. Por ejemplo, `HEADLESS=true` sobrescribe `headless`. Los valores esperados y las URL no aceptan variables de entorno: el Grid se elige con `-Dremote.url=http://localhost:4444`, y un `-D` sobre un valor esperado deja un aviso en el log y solo es válido en el control negativo (ADR-003). Para secretos, `CredentialsProvider` usa directamente los nombres `TEST_*` declarados en `.env.example`; el lector no registra valores y admite líneas vacías, comentarios, el prefijo `export` y valores entre comillas.

### Estrategia de localizadores

La prioridad es `id`, después CSS con atributos estables como `data-test` y, solo cuando expresa una relación del DOM, XPath relativo. Se prohíben XPath absolutos e índices posicionales porque acoplan la prueba a la estructura visual. El botón de un producto es un caso dinámico legítimo: parte del nombre visible y encuentra el botón dentro del mismo contenedor `inventory_item`.

```xpath
//div[@data-test='inventory-item'][.//div[@data-test='inventory-item-name' and normalize-space()='Sauce Labs Backpack']]//button
```

El valor procedente de datos de prueba se envuelve en un literal XPath entre comillas simples antes de construir el selector; si contiene una comilla simple, falla al instante en lugar de agotar la espera (ADR-002, enmienda del 2026-10-13).

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

# Datos de entrada (no sensibles)
test.purchase.products=Sauce Labs Backpack,Sauce Labs Bike Light
test.purchase.single-product=Sauce Labs Backpack
test.checkout.first-name=Ada
test.checkout.last-name=Lovelace
test.checkout.postal-code=01000

# Valores esperados (salen de la spec; independientes de la entrada)
cart.expected.count=2
cart.expected.products=Sauce Labs Backpack,Sauce Labs Bike Light
```

| Grupo | Propiedades | Responsabilidad |
|---|---|---|
| Ejecución | `base.url`, `browser`, `headless`, `remote.url` | Ambiente y navegador |
| Sincronización | `explicit.wait.seconds` | Límite común de esperas explícitas |
| Ventana | `browser.window.width`, `browser.window.height` | Resolución headless |
| Navegación | `route.*` | Rutas esperadas entre páginas |
| Sincronización de UI | `inventory.remove-button.text` | Postcondición de agregar un producto |
| Datos de entrada | `test.purchase.*`, `test.checkout.*` | Productos y datos de envío que usan las acciones |
| Valores esperados | `inventory.expected.title`, `cart.expected.*`, `checkout.expected.confirmation`, `test.login.cases.<caso>.expected-error` | Lo que la spec dice que debe observarse; los `Then` comparan solo contra estas claves |
| Credenciales | Variables `TEST_USER_*` y `TEST_LOGIN_CASES_*` | `.env` local o *Secrets* de CI, nunca en este archivo |
| Evidencia | `evidence.screenshot.*` | Tipo y nombre de capturas en fallos |

**Por qué los esperados van separados de la entrada:** si un `Then` comparara contra el mismo dato que usó el `When`, un defecto que cambiara ambos lados pasaría en verde. Con claves independientes, cualquier esperado se puede alterar desde la línea de comandos para comprobar que la prueba de verdad falla (control negativo):

```bash
./mvnw test -Dheadless=true -Dcucumber.filter.tags="@AC-COMPRA-04" \
  -Dcart.expected.single-product.count=2
# Debe fallar en el Then: expected: <2> but was: <1>
```

### Credenciales: local y CI

**Local.** El repositorio solo conserva `.env.example`, sin valores; la sección [Credenciales de SauceDemo](#credenciales-de-saucedemo-cómo-obtenerlas) explica cómo completarlo. `.gitignore` excluye `.env` y todas sus variantes, salvo la plantilla. El archivo no está cifrado ni es un gestor de secretos: evita su versionado accidental, y los permisos del sistema operativo (`chmod 600 .env`) siguen siendo necesarios.

**GitHub Actions.** En el repositorio, `Settings → Secrets and variables → Actions → New repository secret`, crea un secret por cada variable de `.env.example`, con el mismo nombre y el mismo valor que en tu `.env`. El workflow verifica al inicio que estén los seis y falla con un mensaje claro si falta alguno.

**Jenkins.** Las mismas credenciales se registran en el almacén de credenciales de Jenkins (ver [Jenkins](#jenkins)).

Los nombres de `.env.example` se referencian de forma explícita en `CredentialsProvider`; no se transforman en claves de propiedades. En depuración, el flujo navegable es `step → CredentialsProvider → SecretReader → variable del sistema/.env`. En CI no se crea `.env`: el gestor de credenciales inyecta directamente las mismas variables de entorno, que tienen prioridad sobre `.env`.

## Requisitos previos

- JDK 17 disponible en `JAVA_HOME`.
- Maven no es obligatorio: el proyecto incluye Maven Wrapper (`./mvnw` en Linux/macOS, `mvnw.cmd` en Windows), que descarga Maven 3.9.9 la primera vez.
- Chrome o Firefox instalado para ejecución local. Selenium Manager obtiene el driver compatible.
- Docker con Compose v2 para el ejemplo de Grid.
- Allure CLI para abrir el reporte Allure de forma local.
- `gawk` (además del `mawk` que trae Ubuntu) para correr CHK-18 en local como en CI: `sudo apt install gawk`. Sin gawk, la matriz con `--require gawk` falla cerrado con 2.

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

Un criterio de aceptación concreto (cada escenario lleva la etiqueta `@AC-<DOMINIO>-<NN>` de su spec):

```bash
./mvnw clean test -Dheadless=true -Dcucumber.filter.tags="@AC-LOGIN-02"
```

Solo las pruebas unitarias de la lógica propia (`src/main/java`), sin navegador:

```bash
./mvnw test -Dtest='com.demo.config.*Test,com.demo.data.*Test' -Dsurefire.failIfNoSpecifiedTests=false
```

### Comprobaciones de calidad

Las mismas que corre el CI, ejecutables en local:

```bash
bash scripts/check-traceability.sh   # CHK-12: cada escenario trazado a una spec aprobada
bash scripts/check-layers.sh         # CHK-17: reglas de capas (Selenium solo en transport, etc.)
bash scripts/check-unit-purity.sh    # CHK-15/16: src/main puro y pruebas unitarias aisladas
bash scripts/check-quarantine.sh     # CHK-14: cada @quarantine registrado en docs/quarantine.md
bash scripts/check-awk-portability.sh # CHK-18: sin construcciones exclusivas de una implementación de awk
bash scripts/tests/check-no-expected-override-test.sh # CHK-19: autoprueba del control de esperados por -D

# CHK-19 sobre una ejecución real: guardar el log y comprobar que no trae esperados sobrescritos por -D
bash -c 'set -o pipefail; ./mvnw -B -ntp clean test -Dheadless=true -Dcucumber.filter.tags="not @quarantine" 2>&1 | tee test.log'
bash scripts/check-no-expected-override.sh test.log

# CHK-18: autopruebas que ejercitan awk, con cada implementación (como en CI; requiere gawk)
bash scripts/run-with-each-awk.sh --require mawk --require gawk --require gawk-posix -- bash scripts/tests/check-layers-test.sh
bash scripts/run-with-each-awk.sh --require mawk --require gawk --require gawk-posix -- bash scripts/tests/check-quarantine-test.sh
bash scripts/run-with-each-awk.sh --require mawk --require gawk --require gawk-posix -- bash scripts/tests/evaluate-quarantine-run-test.sh

# CHK-11: pruebas de mutación (umbral 80 %) con la guarda contra el "Skipping project" de PIT
rm -rf target/pit-reports
bash -c 'set -o pipefail; ./mvnw -B -ntp test-compile org.pitest:pitest-maven:mutationCoverage 2>&1 | tee pit.log' \
  && bash scripts/check-mutation-report.sh pit.log
```

El catálogo completo de comprobaciones (CHK-01…19) y sus comandos está en [`.claude/rules/04-quality-checks.md`](.claude/rules/04-quality-checks.md).

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
- `target/pit-reports/index.html`: reporte de mutación, tras ejecutar CHK-11.

Abrir un reporte Allure temporal:

```bash
allure serve target/allure-results
```

Cuando un step falla, `@AfterStep` toma una captura PNG y la adjunta al escenario mediante la API de Cucumber. La captura aparece embebida en `target/cucumber-report.html` y queda disponible para el adaptador de Allure. No se captura en pasos exitosos para evitar ruido y consumo innecesario. El hook `@After` libera el navegador siempre, incluso después de una excepción.

Para comprobar la evidencia durante desarrollo, puede cambiarse temporalmente una expectativa por un valor incorrecto, ejecutar el escenario y abrir el HTML. Esa alteración deliberada no debe confirmarse en el repositorio.

## Extensiones CI/CD

### GitHub Actions

`.github/workflows/ci.yml` corre en cada `push` y `pull request` a `main` (y manualmente con `workflow_dispatch`), con permisos mínimos (`contents: read`), checkout sin credenciales persistidas (`persist-credentials: false`) y `concurrency` que cancela el run anterior de un mismo PR. Tiene seis jobs en paralelo:

| Job | Qué hace | Secrets |
|---|---|---|
| `test` | CHK-12 (trazabilidad) y la suite completa en Chrome headless, sin `@quarantine`; después, CHK-19 sobre su log | Sí |
| `e2e-firefox` | Los escenarios E2E en Firefox headless; después, CHK-19 sobre su log | Sí |
| `e2e-grid` | Los escenarios E2E contra un Selenium Grid (`selenium/standalone-chrome`), con espera activa a que esté listo; después, CHK-19 sobre su log | Sí |
| `mutation` | CHK-12 (trazabilidad, también aquí para que corra en los PR de forks); CHK-18 (portabilidad de awk); CHK-17 (capas) y CHK-14 (cuarentena) con sus autopruebas, que corren con mawk, gawk y `gawk --posix`; la autoprueba de CHK-19; CHK-15/16 y CHK-11 (PIT) con la guarda de reporte | No |
| `quarantine` | Solo los escenarios `@quarantine`, evaluados por `scripts/evaluate-quarantine-run.sh` contra `docs/quarantine.md`: **verde** si un `defecto-sut` falla por aserción (lo esperado) o un `inestable` falla por aserción o pasa; **verde con aviso** si un `defecto-sut` pasa (revisar la spec) o un `inestable` termina con error (revisar su diagnóstico); **rojo** si un `defecto-sut` termina con error (excepción o timeout) o si la cuarentena no mide nada (cero escenarios, sin reporte, fallo de compilación o un escenario sin fila). Después, CHK-19 sobre su log: un esperado sobrescrito por `-D` lo deja en **rojo** | Sí |
| `fork-pr-notice` | Solo en los PR que vienen de un fork: avisa (`::notice::` y resumen del run) de que los E2E se omitieron porque esos PR no reciben secrets; un mantenedor los ejecuta antes de fusionar ([CONTRIBUTING.md](CONTRIBUTING.md)) | No |

En los PR de forks se omiten `test`, `e2e-firefox`, `e2e-grid` y `quarantine` (la condición depende de quién origina el PR, no de que falte un secret: en `main` y en los PR internos, un secret ausente sigue dejando el job en rojo). Un job omitido cuenta como correcto en los checks requeridos, por eso la ejecución de los E2E antes de fusionar es un paso del mantenedor.

Los jobs con navegador registran su versión antes de Maven: `google-chrome --version` en `test` y `quarantine`, la del contenedor del Grid en `e2e-grid` y `firefox --version` en `e2e-firefox`. Así, si una versión nueva de Chrome cambia algo (por ejemplo, renombra la preferencia de D8), el log dice con qué versión empezó.

Los jobs que ejecutan pruebas publican sus reportes como artefactos aunque fallen, con una retención de 14 días (`fork-pr-notice` no publica ninguno). Los artefactos no pasan por el enmascarado de secrets de GitHub, por eso los logs de Maven de los jobs con credenciales (`test.log`, `quarantine.log`) no se suben, ni en GitHub ni en Jenkins; solo se archiva `pit.log` de la mutación, que corre sin credenciales. Los jobs con secrets los verifican al inicio con `scripts/check-required-secrets.sh`, que solo nombra las variables que faltan.

Las credenciales se cargan como *Secrets* del repositorio (`Settings → Secrets and variables → Actions`), uno por variable de `.env.example` y con el mismo nombre: `TEST_USER_STANDARD_USERNAME`, `TEST_USER_STANDARD_PASSWORD`, `TEST_LOGIN_CASES_LOCKED_USER_USERNAME`, `TEST_LOGIN_CASES_LOCKED_USER_PASSWORD`, `TEST_LOGIN_CASES_INVALID_PASSWORD_USERNAME` y `TEST_LOGIN_CASES_INVALID_PASSWORD_PASSWORD`.

### Ejecución en paralelo

Los escenarios corren en paralelo con 2 hilos (`src/test/resources/junit-platform.properties`), el mismo número de sesiones que admite el nodo del Grid. Es seguro porque PicoContainer crea un `Navegador` por escenario y no hay estado estático mutable. Para depurar en serie:

```bash
./mvnw clean test -Dcucumber.execution.parallel.enabled=false
```

### Jenkins

El `Jenkinsfile` es un pipeline declarativo equivalente a los jobs `test`, `mutation` y `quarantine` de GitHub Actions. Firefox y el Grid solo se cubren en GitHub.

**Estado: verificado en un Jenkins real.** El build `#1` terminó en **SUCCESS** en 7 min 16 s, el 2026-10-13. Corrió en Jenkins 2.541.3 (imagen `jenkins/jenkins:lts-jdk17`) sobre el commit `0a51d89`, con Google Chrome 155 en el agente.

#### Qué ejecuta, en orden

| # | Etapa | Qué hace | Credenciales | Resultado esperado |
|---|---|---|---|---|
| 1 | `Checkout` | Descarga el commit bajo prueba | No | — |
| 2 | `Traceability SDD (CHK-12)` | Cada escenario apunta a una spec aprobada | No | Verde, sin salida |
| 3 | `Portabilidad de awk` | CHK-18: control estático y autopruebas con cada awk instalado en el agente | No | Verde |
| 4 | `Capas (CHK-17)` | Autoprueba de las reglas de capas con cada awk, más las reglas sobre el código | No | Verde. Es la etapa sin navegador más larga (unos 5 min) |
| 5 | `Cuarentena reglada (CHK-14)` | Autopruebas de la cuarentena y del evaluador, más el registro `docs/quarantine.md` | No | Verde |
| 6 | `Esperados por -D (ADR-003, R-2)` | Autoprueba de CHK-19 | No | Verde |
| 7 | `Mutation (CHK-11)` | CHK-15/16 y PIT, con la guarda del reporte. Archiva `pit-reports` y `pit.log` | No | Verde (umbral 80 %) |
| 8 | `Test` | Suite completa sin `@quarantine` y, aunque Maven falle, CHK-19 sobre su log. Publica JUnit y Allure y archiva el HTML de Cucumber, Surefire y Allure. No archiva `test.log` | **Sí** | Verde |
| 9 | `Cuarentena (CHK-14)` | Solo los escenarios `@quarantine`, con la misma evaluación que en GitHub, y CHK-19 sobre su log. Archiva `quarantine-reports/` sin el log | **Sí** | **Verde** si AC-COMPRA-09 falla por aserción, que es lo esperado. **UNSTABLE** si un `defecto-sut` pasa o un `inestable` termina con error. **FAILURE** ante un error real o un esperado sobrescrito por `-D` |
| — | `post` global | Limpia el espacio de trabajo (`cleanWs`) | — | — |

**Opciones del pipeline:**
- límite global de 60 min y límites propios en Mutation (10 min), Test (20 min) y Cuarentena (20 min);
- conserva 30 builds y los artefactos de 10;
- sin builds concurrentes (`disableConcurrentBuilds`).

**Ejecución del shell:** los bloques de varias órdenes corren en bash con `set -euo pipefail`. Todos usan comillas simples para que Groovy no interpole ningún valor, y solo `Test` y `Cuarentena` reciben las credenciales (`withCredentials`), que Jenkins enmascara en la consola.

#### Elegir la opción

| | Opción A: servidor existente | Opción B: Jenkins local en Docker |
|---|---|---|
| Cuándo usarla | Integrar el pipeline en el Jenkins de tu equipo o de tu organización | Probar el `Jenkinsfile` en tu máquina, sin servidor, y borrarlo al terminar |
| Qué necesitas | Acceso de administrador a Jenkins y un agente Linux | Docker y salida a Internet durante la construcción de la imagen |
| Origen del código | El repositorio público de GitHub | Tu clon local, montado en solo lectura (o GitHub) |
| Tiempo de preparación | 15–20 min | 10–15 min, casi todo construyendo la imagen |
| Persistencia | Permanente | Efímera: se borra con el paso B8 |

> [!IMPORTANT]
> Los valores marcados como **exactos** los usa el `Jenkinsfile` literalmente: el nombre de la herramienta `jdk-17`, los seis ID de credenciales y la ruta `Jenkinsfile`. Si no coinciden carácter a carácter, el build falla.

#### Opción A: servidor Jenkins existente

**Requisitos previos**

- [ ] Jenkins con permisos de administrador. Versión verificada: **2.541.3**.
- [ ] Un agente **Linux x86_64** (puede ser el propio controlador).
- [ ] Los valores de las seis variables de tu `.env` (ver [Credenciales de SauceDemo](#credenciales-de-saucedemo-cómo-obtenerlas)).

**A1. Versión de Jenkins**

La configuración verificada es Jenkins **2.541.3**, con la imagen `jenkins/jenkins:lts-jdk17`.

> [!NOTE]
> La línea `lts-jdk17` está congelada en 2.541.3, porque las LTS posteriores exigen Java 21 en el controlador, y algunos plugins compatibles con ella tienen avisos de seguridad publicados (`workflow-multibranch`, `pipeline-groovy-lib`). En un servidor permanente usa la LTS vigente: el Java del controlador no afecta al pipeline, que compila con la herramienta `jdk-17` del paso A3. *Ese montaje con la LTS vigente no está verificado en este repositorio.*

**A2. Plugins**

`Manage Jenkins → Plugins → Available plugins`. Instala los ocho y reinicia Jenkins si te lo pide.

| Plugin | ID | Versión verificada | Lo usa el `Jenkinsfile` para |
|---|---|---|---|
| Pipeline | `workflow-aggregator` | 608 | Ejecutar pipelines |
| Pipeline: Declarative | `pipeline-model-definition` | 2.2293 | `pipeline { … }`, `options` y `post` |
| Git | `git` | 5.11.0 | `checkout scm` |
| Credentials Binding | `credentials-binding` | 728 | `withCredentials` y `string(...)` |
| Timestamper | `timestamper` | 1.30 | `timestamps()` |
| JUnit | `junit` | 1438 | `junit` |
| Workspace Cleanup | `ws-cleanup` | 0.49 | `cleanWs` |
| Allure Jenkins Plugin | `allure-jenkins-plugin` | 3.0.0 | `allure` |

*Verificación:* los ocho aparecen en `Manage Jenkins → Plugins → Installed plugins`.

**A3. Herramientas**

`Manage Jenkins → Tools`:

| Sección | Campo | Valor |
|---|---|---|
| JDK installations → *Add JDK* | Name | **`jdk-17`** (exacto) |
| | `JAVA_HOME` | Ruta de un JDK 17, por ejemplo Temurin 17 |
| Allure Commandline installations → *Add Allure Commandline* | Name | `allure` |
| | Instalación | *Install automatically* (versión 2.x; verificada con **2.30.0**) o la ruta de una instalación existente |

Maven no se configura: lo descarga `./mvnw` desde Maven Central y verifica su checksum.

*Verificación:* `jdk-17` y `allure` aparecen guardados en `Manage Jenkins → Tools`.

**A4. Agente**

El pipeline usa `agent any`, así que corre en cualquier nodo con un ejecutor libre. Ese nodo debe cumplir:

| Requisito | Detalle |
|---|---|
| Sistema | Linux x86_64 |
| Programas | `bash`, `git`, `awk` (mawk), **`gawk`** y **Google Chrome** estable. `gawk` hace falta porque CHK-18 prueba los scripts con cada awk instalado |
| chromedriver | No se instala: Selenium Manager lo resuelve en la primera ejecución |
| Red de salida | `www.saucedemo.com` (el SUT), `repo.maven.apache.org` (Maven y dependencias), y `googlechromelabs.github.io` y `storage.googleapis.com` (chromedriver) |
| Memoria compartida | Si el agente es un contenedor, `--shm-size=2g` o más; con menos, Chrome se cierra |
| Telemetría | Ninguna acción: `pom.xml` ya define `SE_AVOID_STATS=true` y Selenium Manager no envía estadísticas |
| Ejecutores | Al menos 1. El job no admite builds concurrentes |

*Verificación:* en una consola del agente, `google-chrome --version`, `gawk --version` y `git --version` responden sin error.

**A5. Credenciales**

`Manage Jenkins → Credentials → System → Global credentials (unrestricted) → Add Credentials`. Crea **seis**, todas con esta configuración:

| Campo | Valor |
|---|---|
| Kind | `Secret text` |
| Scope | `Global (Jenkins, nodes, items, all child items, etc)` |
| Secret | El valor de esa variable en tu `.env` |
| ID | Uno de los seis nombres de abajo (**exacto**) |
| Description | Vacía, o un texto que no sea el valor |

Los seis ID, iguales a los nombres de `.env.example`:

```text
TEST_USER_STANDARD_USERNAME
TEST_USER_STANDARD_PASSWORD
TEST_LOGIN_CASES_LOCKED_USER_USERNAME
TEST_LOGIN_CASES_LOCKED_USER_PASSWORD
TEST_LOGIN_CASES_INVALID_PASSWORD_USERNAME
TEST_LOGIN_CASES_INVALID_PASSWORD_PASSWORD
```

*Verificación:* `Global credentials (unrestricted)` lista exactamente esos seis ID.

**A6. Job**

`New Item` → nombre `spec-driven-selenium-cucumber` (o el que prefieras) → tipo **Pipeline** → *OK*. En la sección *Pipeline*:

| Campo | Valor |
|---|---|
| Definition | `Pipeline script from SCM` |
| SCM | `Git` |
| Repository URL | `https://github.com/eavilac01/spec-driven-selenium-cucumber.git` |
| Credentials | `- none -` (el repositorio es público) |
| Branch Specifier | `*/main`. Para fijar un commit concreto, su SHA completo |
| Script Path | **`Jenkinsfile`** (exacto) |
| Lightweight checkout | Desmarcado (configuración verificada) |

*Save* → **Build Now**.

**A7. Criterios de aceptación**

El build está bien configurado si se cumple todo esto:

- [ ] Resultado **SUCCESS**, en unos 7–8 min.
- [ ] Las nueve etapas de la tabla [Qué ejecuta, en orden](#qué-ejecuta-en-orden) en verde.
- [ ] **Test Result:** 204 pruebas, 0 fallos, 1 omitida (AC-COMPRA-09, en cuarentena).
- [ ] **Allure Report** disponible en el build.
- [ ] Artefactos: `target/cucumber-report.html`, `target/surefire-reports/`, `target/allure-results/`, `target/pit-reports/`, `pit.log` y `quarantine-reports/`.
- [ ] En la consola de `Cuarentena (CHK-14)`: `VERDE: ejecutados=1 fallaron=1 errores=0 pasaron=0`.
- [ ] En la consola, ninguna credencial en claro: Jenkins anuncia `Masking supported pattern matches of $TEST_…`.

**A8. Seguridad**

> [!WARNING]
> No construyas pull requests de forks con estas credenciales. Si usas un job *Multibranch* con GitHub Branch Source, configura *Discover pull requests from forks → Trust: From users with Admin or Write permission*. Si no, el `Jenkinsfile` de un fork podría leer las credenciales.

Restringe además quién puede configurar el job y ver las credenciales.

#### Opción B: Jenkins local y efímero en Docker

Reproduce la configuración verificada en tu máquina:

- Jenkins queda accesible solo en `127.0.0.1:8090`, con inicio de sesión obligatorio y sin acceso anónimo.
- Lee el repositorio en **solo lectura**, montando únicamente su carpeta `.git`; tu árbol de trabajo, con el `.env`, no se monta.
- Todo se borra con el paso B8.

**Requisitos previos**

- [ ] Docker Engine (verificado con la 29.9) y unos 3 GB libres.
- [ ] Salida a Internet durante el paso B3: Docker Hub, `deb.debian.org`, `dl.google.com`, `repo1.maven.org` y `updates.jenkins.io`/`get.jenkins.io`. Durante los builds, la red es la del paso A4.
- [ ] El puerto `127.0.0.1:8090` libre.
- [ ] Los valores de las seis variables de tu `.env`.

**B1. Variables de la sesión**

Define una vez estas dos variables en tu terminal; los pasos siguientes las usan:

```bash
export JENKINS_DIR="$HOME/jenkins-local"        # carpeta de trabajo, fuera del repositorio
export REPO_DIR="/ruta/a/spec-driven-selenium-cucumber"   # tu clon (debe contener .git)
mkdir -p "$JENKINS_DIR/ref/jobs/spec-driven-selenium-cucumber" "$JENKINS_DIR/secrets"
chmod 700 "$JENKINS_DIR/secrets"
test -d "$REPO_DIR/.git" && echo "REPO_DIR correcto"
```

**B2. Archivos de la imagen**

Copia y ejecuta cada bloque: cada uno crea un archivo con su contenido exacto. Las comillas de `'EOF'` impiden que el shell sustituya nada, así que `${…}` llega literal.

`Dockerfile`: Jenkins 2.541.3 con JDK 17, `gawk`, Chrome estable (sin actualizaciones automáticas) y Allure 2.30.0.

```bash
cat > "$JENKINS_DIR/Dockerfile" <<'EOF'
FROM jenkins/jenkins:lts-jdk17

USER root
ARG ALLURE_VERSION=2.30.0
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends gawk ca-certificates unzip; \
    curl -fsSL -o /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb; \
    apt-get install -y --no-install-recommends /tmp/chrome.deb; \
    rm -f /tmp/chrome.deb /etc/apt/sources.list.d/google-chrome.list* /etc/cron.daily/google-chrome; \
    rm -rf /var/lib/apt/lists/*; \
    curl -fsSL -o /tmp/allure.zip "https://repo1.maven.org/maven2/io/qameta/allure/allure-commandline/${ALLURE_VERSION}/allure-commandline-${ALLURE_VERSION}.zip"; \
    unzip -q /tmp/allure.zip -d /opt; \
    mv "/opt/allure-${ALLURE_VERSION}" /opt/allure; \
    rm -f /tmp/allure.zip; \
    google-chrome --version; gawk --version | head -1; /opt/allure/bin/allure --version

COPY --chown=jenkins:jenkins ref/ /usr/share/jenkins/ref/
COPY --chown=jenkins:jenkins casc.yaml /usr/share/jenkins/casc/jenkins.yaml

USER jenkins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/casc/jenkins.yaml \
    JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Dhudson.plugins.git.GitSCM.ALLOW_LOCAL_CHECKOUT=true" \
    SE_AVOID_STATS=true
EOF
```

`plugins.txt`: los ocho plugins del paso A2, más Configuration as Code.

```bash
cat > "$JENKINS_DIR/plugins.txt" <<'EOF'
workflow-aggregator
pipeline-model-definition
git
credentials-binding
timestamper
junit
ws-cleanup
allure-jenkins-plugin
configuration-as-code
EOF
```

`casc.yaml`: configuración como código, con el usuario `admin`, sin registro de usuarios ni acceso anónimo, y las herramientas `jdk-17` y `allure`.

```bash
cat > "$JENKINS_DIR/casc.yaml" <<'EOF'
jenkins:
  systemMessage: "Jenkins local y efímero (127.0.0.1)."
  numExecutors: 1
  mode: NORMAL
  slaveAgentPort: -1
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: "admin"
          password: "${JENKINS_ADMIN_PASSWORD}"
  authorizationStrategy:
    loggedInUsersCanDoAnything:
      allowAnonymousRead: false
  crumbIssuer: "standard"
tool:
  jdk:
    installations:
      - name: "jdk-17"
        home: "/opt/java/openjdk"
  allure:
    installations:
      - name: "allure"
        home: "/opt/allure"
unclassified:
  location:
    url: "http://127.0.0.1:8090/"
EOF
```

> [!NOTE]
> `${JENKINS_ADMIN_PASSWORD}` no es una variable de entorno: Configuration as Code la lee del archivo `/run/secrets/JENKINS_ADMIN_PASSWORD` del contenedor, que se monta en el paso B4. La contraseña nunca entra en la imagen.

`config.xml`: el job, creado al arrancar. Lee el `Jenkinsfile` de la rama `main` del repositorio montado en `/repo.git`.

```bash
cat > "$JENKINS_DIR/ref/jobs/spec-driven-selenium-cucumber/config.xml" <<'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>Jenkinsfile del repositorio local montado en solo lectura (/repo.git).</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps">
    <scm class="hudson.plugins.git.GitSCM" plugin="git">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>file:///repo.git</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="empty-list"/>
      <extensions/>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
    <lightweight>false</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF
```

Para variar el origen del código:
- **Desde GitHub en vez de tu clon:** cambia `file:///repo.git` por `https://github.com/eavilac01/spec-driven-selenium-cucumber.git` y omite el montaje `-v "$REPO_DIR/.git:/repo.git:ro"` del paso B4.
- **Un commit concreto:** cambia `main` por su SHA completo.

*Verificación:* `ls -R "$JENKINS_DIR"` muestra `Dockerfile`, `plugins.txt`, `casc.yaml`, `ref/jobs/spec-driven-selenium-cucumber/config.xml` y la carpeta `secrets/`.

**B3. Contraseña de `admin` e imagen**

```bash
(umask 077; openssl rand -base64 24 > "$JENKINS_DIR/secrets/JENKINS_ADMIN_PASSWORD")
[ "$(id -u)" = 1000 ] || chmod 644 "$JENKINS_DIR/secrets/JENKINS_ADMIN_PASSWORD"
docker build -t jenkins-sdsc:local "$JENKINS_DIR"
```

- La contraseña queda en un archivo `600` dentro de una carpeta `700`.
- El usuario `jenkins` del contenedor tiene el UID 1000. Si tu UID es otro, la segunda línea abre la lectura del archivo; la carpeta sigue siendo privada.
- La construcción tarda unos 5–10 min.

*Verificación:* el final de `docker build` muestra la versión de Google Chrome, la de GNU Awk y `2.30.0` (Allure).

**B4. Arranque**

```bash
docker network create jenkins-sdsc-net
docker volume create jenkins-sdsc-home
docker run -d --name jenkins-sdsc \
  --network jenkins-sdsc-net \
  -p 127.0.0.1:8090:8080 \
  --shm-size=2g \
  -v jenkins-sdsc-home:/var/jenkins_home \
  -v "$JENKINS_DIR/secrets:/run/secrets:ro" \
  -v "$REPO_DIR/.git:/repo.git:ro" \
  jenkins-sdsc:local
docker logs -f jenkins-sdsc
```

Espera a la línea `Jenkins is fully up and running` y sal de los logs con `Ctrl+C`; el contenedor sigue en marcha.

*Verificación:* `docker ps --filter name=jenkins-sdsc` muestra el contenedor `Up` con `127.0.0.1:8090->8080/tcp`.

**B5. Acceso**

1. **Lee la contraseña** en una terminal, fuera de cualquier herramienta que registre la salida:
   ```bash
   cat "$JENKINS_DIR/secrets/JENKINS_ADMIN_PASSWORD"; echo
   ```
2. **Inicia sesión:** abre `http://127.0.0.1:8090/` y entra con el usuario **`admin`** y esa contraseña.

*Verificación:* el panel muestra el job `spec-driven-selenium-cucumber` y el mensaje "Jenkins local y efímero (127.0.0.1)".

**B6. Credenciales**

Crea las seis credenciales del paso A5 en `http://127.0.0.1:8090/manage/credentials/store/system/domain/_/newCredentials`.

*Verificación:* `Global credentials (unrestricted)` lista los seis ID.

**B7. Build**

Abre el job `spec-driven-selenium-cucumber` → **Build Now**. Tarda unos 7–8 min.

*Verificación:* se cumplen los criterios de aceptación del paso A7.

**B8. Limpieza**

```bash
docker rm -f jenkins-sdsc
docker volume rm jenkins-sdsc-home
docker network rm jenkins-sdsc-net
docker rmi jenkins-sdsc:local jenkins/jenkins:lts-jdk17
rm -rf "$JENKINS_DIR"
```

Borra el contenedor, la imagen, el volumen, que guarda las credenciales cifradas, la red y la carpeta con la contraseña.

*Verificación:* `docker ps -a --filter name=jenkins-sdsc` y `docker volume ls --filter name=jenkins-sdsc` no devuelven nada.

**Diferencia con el build verificado**

En la verificación, el chromedriver se copió a la imagen desde la caché de Selenium del host y se usó `SE_OFFLINE=true`, para no salir a Chrome for Testing. Este `Dockerfile` deja que Selenium Manager lo descargue, como en GitHub Actions.

Para reproducir la variante sin red:
1. Antes del paso B3, copia `~/.cache/selenium/chromedriver/linux64/<versión>/chromedriver` del host a `$JENKINS_DIR/chromedriver`.
2. Añade al `Dockerfile` la línea `COPY --chown=jenkins:jenkins chromedriver /usr/share/jenkins/ref/.cache/selenium/chromedriver/linux64/<versión>/chromedriver`.
3. Añade `SE_OFFLINE=true` al `ENV`.

La versión mayor del chromedriver debe coincidir con la del Chrome instalado en la imagen; la muestra la salida del paso B3.

#### Problemas frecuentes en Jenkins

| Síntoma | Causa | Solución |
|---|---|---|
| `Tool type "jdk" does not have an install of "jdk-17" configured` | La herramienta no se llama `jdk-17` | Renómbrala exactamente `jdk-17` (paso A3) |
| `Could not find credentials entry with ID 'TEST_…'` | Falta la credencial o su ID no coincide | Revisa los seis ID (paso A5) |
| `Secret faltante: 'TEST_…' (credencial de tipo Secret text con el mismo ID)` | Esa credencial está vacía | Edítala y pon el valor de tu `.env` |
| Chrome se cierra (`session deleted because of page crash`) | `/dev/shm` pequeño en el contenedor | `--shm-size=2g` o más |
| `SessionNotCreatedException`: versión de chromedriver incompatible | `SE_OFFLINE=true` con un chromedriver de otra versión mayor | Quita `SE_OFFLINE` o copia el chromedriver de la misma versión mayor que Chrome |
| `Portabilidad de awk` o `Capas (CHK-17)` falla con `gawk: not found` o con errores de `gawk` | El agente no tiene `gawk`, o un script usa algo exclusivo de una implementación de awk | Instala `gawk` (paso A4). Si falla con un awk concreto, es un defecto del script: ver CHK-18 |
| El Jenkins local no arranca o Configuration as Code no encuentra `JENKINS_ADMIN_PASSWORD` | Falta `secrets/JENKINS_ADMIN_PASSWORD` o el contenedor no puede leerlo | Repite el paso B3 y revisa el UID |
| `docker run` falla con `port is already allocated` | El puerto `127.0.0.1:8090` está ocupado | Cambia el puerto en `-p` (B4) y en `url` de `casc.yaml` (B2), y reconstruye la imagen |
| `Cuarentena (CHK-14)` en **UNSTABLE** | Un `defecto-sut` pasó (posible corrección del SUT) o un `inestable` terminó con error | Lee el aviso en la consola y la sección [Cuarentena y defectos conocidos](#cuarentena-y-defectos-conocidos) |

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
4. Implementar la interacción con la API de `Navegador`; si falta una operación genérica, agregarla allí en vez de acceder al driver desde la página.
5. Orquestar páginas en una acción de negocio y realizar la aserción descriptiva en el step, contra un valor esperado de configuración.
6. Ejecutar tanto el nuevo escenario como la suite completa.

Lista de control antes de integrar cambios:

```text
[ ] ./mvnw clean test termina en BUILD SUCCESS
[ ] @smoke ejecuta únicamente el alcance esperado
[ ] los escenarios no comparten estado
[ ] no hay pausas fijas ni esperas implícitas
[ ] no hay assert en pages
[ ] no hay Selenium fuera de transport (en pages, solo By) ni findElement fuera de Navegador
[ ] los steps no importan pages ni transport
[ ] no hay XPath absoluto ni índice posicional frágil
[ ] no hay catch vacío
[ ] no hay variables, parámetros, campos privados ni métodos privados sin uso
[ ] no hay URLs, credenciales, datos de prueba, rutas, timeouts ni expectativas configurables en duro
[ ] `.env` está ignorado y solo `.env.example` permanece versionable y sin secretos
[ ] no hay gestores externos ni rutas fijas de drivers
[ ] un fallo conserva captura y los hooks cierran el navegador
```

## Cuarentena y defectos conocidos

Una prueba nunca se desactiva ni se borra para que el pipeline pase. La única vía es la **cuarentena reglada**: la etiqueta `@quarantine` en el escenario más una fila en [`docs/quarantine.md`](docs/quarantine.md), que CHK-14 valida en cada ejecución.

| Tipo | Cuándo | Plazo | Cómo sale |
|---|---|---|---|
| `inestable` | Una prueba falla de forma intermitente sin cambios de código | Máximo 14 días | Se corrige la causa raíz |
| `defecto-sut` | La aplicación incumple la spec (defecto conocido del sistema bajo prueba) | Revisión cada 90 días | La aplicación se corrige: el escenario pasa y se quita la etiqueta |

En el job `quarantine`, un escenario que termina con error (excepción o timeout, no aserción) deja el job en verde con aviso si es `inestable`, porque esa es justo la causa que se está diagnosticando, y en rojo si es `defecto-sut`, porque entonces no mide el criterio. La tabla completa está en [`docs/quarantine.md`](docs/quarantine.md).

Hoy hay un caso: **AC-COMPRA-09**. La regla de negocio dice que no se puede comprar con el carrito vacío, pero SauceDemo lo permite. La prueba exige la regla, así que falla por aserción y el job `quarantine` lo reporta como **fallo esperado** (en verde, con una nota en el resumen del run). Si algún día SauceDemo se corrige, el escenario pasará y el job emitirá un aviso para revisar la spec y quitarlo de la cuarentena.

## Solución de problemas

**Un escenario falla al abrir la página con una página de error de Chrome (`ERR_CONNECTION_CLOSED`, `ERR_CERT_VERIFIER_CHANGED`).** Suele ocurrir con la máquina saturada, por ejemplo con PIT corriendo a la vez que la suite. Ejecuta la suite y las pruebas de mutación por separado. La captura del escenario en `target/cucumber-report.html` muestra el error real.

**`El clic en … no alcanzó su postcondición … el clic nativo no tuvo efecto` o `La escritura en … no conservó el valor escrito`, después del login en Chrome.** El aviso de contraseñas filtradas de Chrome se está tragando la entrada nativa. Comprueba que `BrowserSettings.chromePreferences()` sigue devolviendo `profile.password_manager_leak_detection=false` y que la versión de Chrome no ha renombrado esa preferencia (ADR-002, D8).

**Una autoprueba de `scripts/` pasa en local y falla en CI con `awk: … fatal` o `gawk: error`.** El runner de GitHub usa gawk y Ubuntu de escritorio usa mawk: un nombre reservado de gawk (como `RT`) o una construcción que `gawk --posix` rechaza solo falla allí. Instala gawk (`sudo apt install gawk`) y corre las autopruebas con `scripts/run-with-each-awk.sh` (CHK-18) antes de subir.

**`La variable sensible obligatoria '...' no tiene valor`.** Falta esa variable en `.env` (local) o en los *Secrets* (CI), o está vacía. Revisa la sección [Credenciales de SauceDemo](#credenciales-de-saucedemo-cómo-obtenerlas).

**El login falla con credenciales que parecen correctas.** Vuelve a copiarlas desde [saucedemo.com](https://www.saucedemo.com): pueden haber cambiado. Comprueba también que no haya espacios ni comillas sobrantes en `.env`.

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
- **Comprobaciones deterministas:** catálogo CHK-01…19 (sleep, reintentos, capas, control negativo, mutación, trazabilidad, cuarentena, portabilidad de awk, esperados por `-D`), un hook que bloquea `git push` sin el gate DevOps y otro que impide modificar por Bash la configuración de los agentes y los workflows del CI (`.claude/rules/02` y `04`).

Índice, justificación de roles y asignación de modelo: [`.claude/agents/README.md`](.claude/agents/README.md).

## Contribuir y seguridad

Las contribuciones siguen el flujo SDD y las comprobaciones de [CONTRIBUTING.md](CONTRIBUTING.md). En los pull requests desde un fork el CI omite los E2E, porque no reciben secrets, y un mantenedor los ejecuta antes de fusionar. Las vulnerabilidades se reportan en privado según [SECURITY.md](SECURITY.md), nunca en un issue público.

## Licencia

Distribuido bajo la licencia MIT. Consulta [`LICENSE`](LICENSE) para más detalles.

© 2026 Eduardo Avila Carranza
