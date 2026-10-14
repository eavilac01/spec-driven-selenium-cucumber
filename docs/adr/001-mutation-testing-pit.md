# ADR-001 — Pruebas de mutación con PIT sobre la lógica propia del framework (CHK-11)

- **Estado:** Aceptado (ADR y cambios a reglas y agentes aprobados por el usuario, 2026-10-09). *(Al 2026-10-13: completamente implementado desde `90687f4`, y sin P2 abiertos (*Enmiendas*). Su alcance, todo `src/main/java`, creció con la lógica pura de los ADR-002, ADR-003 y ADR-004. PIT da 164/164 desde `aa3cda5`, según el verifier. Ningún riesgo queda abierto: R-6 (macOS) es un límite aceptado (*Riesgos*).)*
- **Fecha:** 2026-10-09
- **Autor:** `qa-automation-architect`
- **Aprueba:** coordinador (Regla 01, nivel 2). Los cambios a reglas y a archivos de agentes los aprueba y aplica el usuario (P-01, PI-07).
- **Numeración:** es el primer ADR del repositorio. El ADR de transporte y acciones de negocio, previsto antes como ADR-001, pasa a ser el **ADR-002**.

## Contexto

- CHK-11 exige un puntaje de mutación ≥ 80 % (`.claude/rules/04-quality-checks.md:17`) y aún no está configurada (*Estado actual*, `:66`). PIT es una dependencia nueva y requiere un ADR (P-06).
- Decisiones previas que este ADR respeta: PIT se aplica **solo** a la lógica propia del framework; los escenarios E2E se validan con el control negativo (CHK-10), porque el SUT es externo y no se puede mutar.
- Hechos del repositorio:
  - Todo el código está en `src/test/java`; `git ls-files src/main` no devuelve nada.
  - No hay pruebas unitarias: el único `*Test.java` es `com.demo.runners.RunnerTest`, una `@Suite` del motor de Cucumber (`RunnerTest.java:12-15`).
  - Surefire solo incluye `**/RunnerTest.java` (`pom.xml:162-164`).
  - Selenium, Cucumber y JUnit tienen `scope` `test` (`pom.xml:51,56,61,66,71,76`).
  - El plugin `pitest-maven` toma como código mutable el directorio de salida principal (`target/classes`); las clases de `target/test-classes` solo se usan como pruebas. Confirmado en el paso 1 (R-1, *Enmiendas*).

## Decisión

### D1. Qué se muta

Criterio: se muta la lógica propia que **(a)** no necesita navegador, red, archivos ni variables de entorno reales y **(b)** cuyo defecto podría pasar inadvertido para la suite E2E.

| Clase | Veredicto | Evidencia | Motivo |
|---|---|---|---|
| `ConfigReader` (lógica) | **Dentro** | Validaciones `ConfigReader.java:21-68`; precedencia `:70-84`; normalización de clave `:96-100` | CHK-10 depende de que una propiedad `-D` gane a las demás fuentes (`:73-76`). Hoy lee `System` y el classpath directamente (`:16`, `:73`, `:87`, `:93`), así que necesita fuentes inyectadas |
| `SecretReader` (validación y parser) | **Dentro** | Nombre `SecretReader.java:21`; precedencia y vacío `:26-33`; parser `.env` `:56-89`, con fronteras en `:66` (`<= 0`) y `:80` (`>= 2`) | Es la lógica más densa del repo, y sus mensajes de error no deben exponer valores (`:32`, `:67`, `:72`). Hoy carga `.env` en un inicializador estático (`:13-14`): una prueba que tocara la clase leería el `.env` real (P-02) |
| `CredentialsProvider.Credentials` | **Dentro** | `CredentialsProvider.java:26-31` (antes del paso 4) | El `toString` enmascarado protege PI-09. Si se rompe, ningún E2E falla: solo se filtran credenciales en los reportes. Desde el paso 4, el record vive en `com.demo.data.Credentials` (`Credentials.java:10`) |
| `CredentialsProvider` (fábricas) | Fuera | `CredentialsProvider.java:8-24` | Solo asocian un perfil a dos nombres de variable; un error falla de forma visible en el primer `Given` |
| `TestContext` | Fuera | `TestContext.java:5`, `:12-35` | Contiene un `WebDriver` (de `scope` `test`) y sus guardas de `null` fallan de forma visible en el E2E |
| `DriverFactory` | Fuera | `DriverFactory.java:36-41`, `:69-97` | Su trabajo es crear un `WebDriver`; probarla exige un navegador o mocks (dependencia nueva). Se reevalúa en el ADR-002 si el transporte separa una configuración de navegador pura |
| `pages`, `steps`, `hooks`, `runners` | Fuera | Selenium en `BasePage.java:8-15`; aserciones en `CompraSteps.java:3`, `:55-58` | Interactúan con el SUT externo: mutarlos exigiría un navegador y los secrets por cada mutante. CHK-10 ya demuestra su capacidad de detección |

### D2. Dónde vive: `src/main/java`, sin E/S

- La lógica de D1 pasa a `src/main/java`, en los paquetes de la capa 4: `com.demo.config` (configuración y secretos) y `com.demo.data` (`Credentials`). Nombres orientativos: `ConfigResolver`, `SecretResolver`, `DotEnvParser`, `Credentials`.
- **Regla de pureza:** `src/main/java` no llama a `System.getenv` ni a `System.getProperty`, no usa `java.nio.file`, `java.io.File*` ni `getResource*`, y no importa Selenium, Cucumber ni JUnit. Recibe sus fuentes como parámetros: búsquedas `UnaryOperator<String>` para el entorno y las propiedades del sistema, `Properties` o `Map` para `config.properties`, y las líneas del `.env` como `List<String>`.
- Las fachadas estáticas `ConfigReader`, `SecretReader` y `CredentialsProvider` se quedan en `com.demo.utils` (`src/test/java`), con su API pública actual. Leen el entorno y los archivos, y delegan en `src/main`. Las 32 llamadas a `ConfigReader` en 9 archivos no cambian; solo cambia el import de `Credentials` (`CompraSteps.java:8`, `LoginSteps.java:8`). Su ubicación definitiva la decide el ADR-002.
- Consecuencia estructural: como Selenium, Cucumber y JUnit tienen `scope` `test`, el compilador impide que `src/main` dependa de ellos o de las capas de prueba. R6 queda garantizada por Maven para esta parte de la capa 4.

### D3. Pruebas unitarias

- Se escriben con JUnit 5 Jupiter, que ya está en el POM (`pom.xml:73-77`). Sin Mockito ni AssertJ.
- Ubicación: `src/test/java/com/demo/config/` y `src/test/java/com/demo/data/`, en el mismo paquete que la clase probada y con nombre `*Test`. Estos dos directorios del árbol de pruebas solo contienen pruebas unitarias.
- Aislamiento: no importan Selenium, Cucumber ni `com.demo.(utils|pages|steps|hooks|runners)`, no leen `System.getenv` ni el `.env` real, construyen sus fuentes en memoria y sus esperados son literales de la prueba.
- Casos mínimos (cada uno con un valor concreto; ninguno es solo de "no nulo"):
  - **Configuración:** precedencia sistema > entorno exacto > entorno normalizado (`a.b-c` → `A_B_C`) > archivo; un valor en blanco en una fuente prioritaria no cae a la siguiente (`:74`, `:79` comparan con `null`); `getRequired` rechaza ausente y en blanco con la clave en el mensaje; `getOptional` ausente → `""`; `getBoolean` acepta `true`, `FALSE` y ` true ` y rechaza `yes` y `1`; `getPositiveInt` acepta `1` y ` 5 ` y rechaza `0`, `-1` y `abc` (esta última con causa `NumberFormatException`); `getList` convierte `a, b` en `[a, b]` y rechaza `a,,b`, `a,` y `,`; una clave `null` lanza NPE.
  - **Secretos:** nombres válidos `A` y `_X1`, inválidos `a`, `1A` y `A-B`; el entorno gana al `.env`; ausente o en blanco → `IllegalStateException`. Parser: ignora líneas vacías y `#`; acepta `export K=v`; `K==v` da el valor `=v`; rechaza `=v`, `K` sin `=` y `1K=v`, con el número de línea en el error; quita comillas `"v"` y `'v'` y conserva `"v'` y `"`. **Ningún mensaje de error contiene el valor ni la línea.**
  - **Credentials:** `toString()` es exactamente `Credentials[username=***, password=***]` y no contiene ninguno de los dos valores.
- Separación del runner de Cucumber:
  - PIT usa `targetTests` acotado a `com.demo.config.*Test` y `com.demo.data.*Test`, y `excludedTestClasses` = `com.demo.runners.*`. Sin `targetTests` explícito, PIT seleccionaría las pruebas de todo `com.demo*` (incluido `RunnerTest`) y lanzaría la suite E2E.
  - Surefire agrega esos patrones a `includes` (`pom.xml:162-164`), para que CHK-07 y CHK-08 detecten una prueba unitaria rota sin esperar al job de mutación.

### D4. Dependencias y plugins (P-06)

| Artefacto | Dónde | Versión confirmada |
|---|---|---|
| `org.pitest:pitest-maven` | `<build><plugins>`, **sin** `<executions>`: no se ata a ninguna fase y `./mvnw test` no cambia | `1.30.0` (`pom.xml:26`) |
| `org.pitest:pitest-junit5-plugin` | `<dependency>` del plugin `pitest-maven`, no del proyecto | `1.2.3` (`pom.xml:27`) |
| `org.junit.platform:junit-platform-launcher` | Solo si PIT no la aporta: dependencia `test` sin versión, gestionada por `junit-bom` | No se agrega: no hace falta (R-3 refutado) |

- Versiones confirmadas por `devops-engineer` en Maven Central con `./mvnw` (paso 1, commit `4d75090`), compatibles con JUnit 5.14.2 y Java 17.
- Las versiones van en `<properties>`, como el resto (`pom.xml:13-25`).
- No hace falta nada más: ni `exec-maven-plugin`, ni Mockito, ni AssertJ. ArchUnit pertenece al ADR-002.

### D5. Configuración y ejecución

- **Comando de CHK-11** (sin cambios respecto de la Regla 04): `./mvnw -B -ntp test-compile org.pitest:pitest-maven:mutationCoverage`
- **Configuración del plugin:**
  - `targetClasses` = `com.demo.*`: todo lo de `src/main/java` entra solo. Una lista explícita de paquetes dejaría fuera, sin aviso, una clase nueva.
  - `targetTests` = `com.demo.config.*Test,com.demo.data.*Test`, parametrizable con `-D` (por ejemplo `pit.targetTests`) solo para el control negativo de D6.
  - `excludedTestClasses` = `com.demo.runners.*`.
  - `mutationThreshold` = `80`, **literal en el POM y no parametrizable**.
  - `failWhenNoMutations` = `true` (el valor por defecto; no se cambia).
  - `outputFormats` = `HTML,XML`; `timestampedReports` = `false`, para tener una ruta estable en `target/pit-reports/`.
  - `threads` = `2`. Sin `withHistory` ni `scmMutationCoverage`.
- **Mutadores: `STRONGER`.** El código mutable es casi todo guardas (`isBlank`, `<= 0`, `matches`, `startsWith`, comillas con `&&` y `||`). `STRONGER` agrega a `DEFAULTS` las variantes `_IF` de `REMOVE_CONDITIONALS` (`EQUAL_IF`, `ORDER_IF`), que junto con las `_ELSE` de `DEFAULTS` obligan a ejercitar las dos ramas de cada guarda, y `REMOVE_SWITCH` (composición confirmada en R-5). Con unas 150 líneas mutables, el coste extra es de segundos. `ALL` queda descartado porque incluye mutadores experimentales que generan muchos equivalentes.
- **Dónde corre:**
  - **GitHub Actions:** job `mutation` en `.github/workflows/ci.yml`, en paralelo al job `test`. Va sin `env` de secrets: hoy están en el nivel del job `test` (en su `env`; `ci.yml:14-20` al 2026-10-09) y deben seguir ahí, nunca en el nivel del workflow. Tampoco lleva el paso de verificación de secrets ni navegador, y publica `target/pit-reports/`. *(Nota del 2026-10-13: desde `e6e91bc` y `7faaead` también reciben los secrets, en el `env` de cada job, `e2e-firefox`, `e2e-grid` y `quarantine`; el workflow sigue sin ellos y `mutation` también.)*
  - **Jenkins:** etapa `Mutation (CHK-11)` fuera de `withCredentials`. *(Nota del 2026-10-13: la cita original, `Jenkinsfile:26-44`, era la ubicación prevista antes de crear la etapa.)*
  - **Gate local:** previo al push (paso 7 de devops).
  - **Falla cerrada:** si se colara un escenario, fallaría por falta de secrets en el primer `Given` y PIT abortaría en la fase de cobertura.
- **Presupuesto:** estimado, sin ejecutar, ≤ 2 min de PIT y ≤ 5 min de job con la caché de Maven, con `timeout-minutes: 10`. Superar los 5 min indica que una prueba hace E/S: se investiga; no se sube el timeout.
- **Mutantes equivalentes** (no se excluyen; se siguen estos pasos en orden):
  1. Primero se reescribe el código para eliminar la equivalencia.
  2. Si no se puede, el verifier lo registra en su reporte (archivo:línea, mutador y por qué es equivalente) y el mutante cuenta contra el puntaje. El margen del 20 % existe para esto.
  3. `excludedMethods`, `excludedClasses` o `avoidCallsTo` solo se usan con una enmienda de este ADR que indique el método, el motivo y la fecha de revisión. El umbral no se baja.

### D6. Control negativo de CHK-11

Con la lógica de configuración sin pruebas, el puntaje cae por debajo del umbral. Este comando **debe** terminar en `BUILD FAILURE`:

```bash
./mvnw -B -ntp test-compile org.pitest:pitest-maven:mutationCoverage -Dpit.targetTests='com.demo.data.*Test'
```

Si termina en `BUILD SUCCESS`, el umbral no protege nada y el resultado es RECHAZO.

## Alternativas consideradas

| Alternativa | Motivo del descarte |
|---|---|
| Módulo Maven aparte | Exige POM padre, `-pl` en CI y en la Regla 04, y cambiar las rutas de CHK-01…06 y de los reportes. Es desproporcionado para 4 clases; se reconsidera si el núcleo se comparte entre varias suites |
| Mutar `target/test-classes` | `pitest-maven` no expone, hasta donde sé, un parámetro para declarar el árbol de pruebas como código mutable (R-1). La vía alternativa es invocar la línea de comandos de PIT con `exec-maven-plugin` y un classpath armado a mano: otro plugin (P-06) y un uso no soportado. Además mezcla código y pruebas en un directorio y obliga a mantener listas de exclusión (steps, pages, runners) que fallan abiertas cuando aparece una clase nueva |
| Mutar `pages` y `steps` con la suite E2E | Un navegador y el SUT externo por mutante, secrets en el job y un tiempo inviable. CHK-10 ya cubre su detección |
| Mockito para `pages` y `DriverFactory` | Dependencia nueva; verifica llamadas a la API de Selenium, no comportamiento |
| Fachadas también en `src/main` | Mete E/S en el alcance: sus mutantes sobrevivirían (`System.getenv` no se puede fijar en una prueba) y habría que excluirlos |
| Cobertura de líneas en lugar de mutación | No es una CHK (Regla 04): mide ejecución, no verificación |
| Mutadores `DEFAULTS` o `ALL` | `DEFAULTS` es más débil justo en las guardas; `ALL` genera ruido de equivalentes |

## Consecuencias

- **Positivas:**
  - CHK-11 se puede activar.
  - La capa 4 pura queda con su frontera impuesta por el compilador.
  - Las pruebas unitarias documentan la precedencia de configuración en la que se apoya CHK-10.
  - `./mvnw test` solo suma milisegundos.
- **Costes:**
  - Hay dos árboles de código.
  - Las fachadas de `utils` quedan sin mutar. Su riesgo residual es el cableado al entorno, que el E2E ejercita en cada escenario.
  - Se agrega un job de CI.
  - Las reglas y los archivos de agentes cambian, y solo el usuario puede aplicarlo.
- **Comportamiento actual fijado:** las pruebas fijan el comportamiento de hoy, incluidos dos P2 abiertos (`MEMORY.md`, *Próximos pasos* 5): el entorno puede sobrescribir claves `*.expected*` y `getPositiveInt` rechaza `0`. Se deciden aparte; si cambian, primero cambian sus pruebas. *(Nota del 2026-10-13: ver la enmienda de esa fecha; el primero lo decide el ADR-003.)* *(Los dos están cerrados al 2026-10-13: el primero lo implementa el ADR-003 (`2c33885`), y el segundo se resolvió con `getNonNegativeInt` (`146df90`).)*
- **AppleDouble:** la limpieza de `._*` en `src` corría en `generate-test-sources`, después de `compile`, y no protegía `src/main/java`. Mitigado en el paso 1 (R-6): corre en `generate-sources` (`pom.xml:115`) y también sobre `target/classes` en `process-classes` (`pom.xml:132`).

## Cambios propuestos a reglas y agentes (aplicados el 2026-10-09)

Todos aplicados por el usuario; no queda ninguno pendiente. La fila de `AGENTS.md` y `README.md` quedó hecha en el paso 4; el *Estado actual* de la Regla 04 y la última fila, al cerrar el paso 6 (*Enmiendas*).

| Archivo | Cambio | Cuándo |
|---|---|---|
| `.claude/rules/02-agent-permissions.md:10` | `qa-automation-engineer` también escribe `src/main/java/`. Hoy nadie puede (P-10) | **Prerrequisito del paso 2** |
| `.claude/rules/04-quality-checks.md:17` | CHK-11: "≥ 80 % sobre el alcance de ADR-001 (todo `src/main/java`); cada sobreviviente de las clases tocadas, justificado". PIT calcula el umbral por ejecución, no por clase | Antes del paso 5 |
| `.claude/rules/04-quality-checks.md` | CHK-15 (pureza de `src/main/java`) y CHK-16 (aislamiento de las pruebas unitarias), con los comandos de *Criterio de verificación*. Actualizar el *Estado actual* (`:66`) al cerrar el paso 6 | Antes del paso 5 (CHK-15 y CHK-16 aplicadas). El *Estado actual* (hoy en `:69`), **hecho** al cerrar el paso 6 |
| `.claude/rules/01-spec-driven-development.md` | Nota en la tabla: "la lógica pura de la capa 4 vive en `src/main/java` (ADR-001)". Aclarar que un ADR también puede originarse en una CHK y que las pruebas unitarias del framework no requieren spec (SDD-02 rige el código que ejecuta features) | Con el paso 0 |
| `.claude/agents/qa-automation-engineer.md:24` | Agregar `src/main/java/` a *Escribe en* | Con el paso 0 |
| `.claude/agents/devops-engineer.md:38`, `:45` | Alinear CHK-11 con D5 (`targetClasses` `com.demo.*`, `targetTests`); agregar `src/main/java/com/demo/config/` a las rutas CRÍTICAS (manejo de secretos) | Antes del paso 1 |
| `.claude/agents/qa-automation-architect.md:48`, `:56`; `.claude/agents/README.md:52` | Renumerar el ADR de transporte a ADR-002 | Con el paso 0 |
| `AGENTS.md:27`; `README.md:61`, `:69`, `:78`, `:117` | Estructura con `src/main/java`. `README.md` no tiene dueño en la matriz | **Hecha** en el paso 4; el verifier comprobó en el paso 5 que coincide con `git ls-files` |
| `.claude/rules/04-quality-checks.md:17`, `:47-49`, `:60`; `.claude/agents/devops-engineer.md:38`, `:50` | CHK-11 exige la guarda en 0, y su comando la ejecuta después de PIT; comando conjunto de CHK-15/16 (`scripts/check-unit-purity.sh`); el gate de devops (paso 7) usa los dos scripts | **Hecha** al cerrar el paso 6 |

## Plan de implementación

Cada paso deja la suite en verde.

| Paso | Dueño | Qué | Verde si | Estado |
|---|---|---|---|---|
| 0 | Usuario, vía coordinador | Aprueba este ADR y los cambios a reglas y agentes | — | Hecho |
| 1 | `devops-engineer` | POM: versiones en `<properties>`; `pitest-maven` con `pitest-junit5-plugin` y la configuración de D5; los `includes` de surefire de D3; la limpieza de `._*` antes de `compile` y sobre `target/classes` | CHK-07; CHK-08 con el mismo `Tests run` que antes. CHK-11 da `Skipping project` con `BUILD SUCCESS`: es lo esperado sin `src/main` y no verifica nada (*Enmiendas*) | Hecho (`4d75090`) |
| 2 | `qa-automation-engineer` | Lógica de configuración en `com.demo.config` con sus pruebas; `ConfigReader` delega | CHK-07, CHK-08, CHK-15 y CHK-16; CHK-11 ≥ 80 % | Hecho (`decb120`) |
| 3 | `qa-automation-engineer` | Validación de nombres y parser de secretos en `com.demo.config`, con pruebas de contenido sintético; `SecretReader` lee el archivo y el entorno y delega | Lo mismo; el gate lo trata como CRÍTICO | Hecho (`afe8618`) |
| 4 | `qa-automation-engineer` | `Credentials` en `com.demo.data` con la prueba de enmascarado; imports en los steps | Lo mismo y CHK-03 | Hecho (`c8486ee`) |
| 5 | `qa-test-verifier` | Criterio de verificación completo | APROBADO | Hecho (APROBADO, 2026-10-09) |
| 6 | `devops-engineer` | Job `mutation` en GitHub Actions, etapa en Jenkins y CHK-11 en el gate. Todos exigen `target/pit-reports/mutations.xml` y tratan `Skipping project` como rechazo cuando existe `src/main/java` (*Enmiendas*) | CHK-13; run remoto en verde en los dos jobs; sin `mutations.xml`, el job y el gate fallan | Hecho (`90687f4`) |

## Criterio de verificación

```bash
# CHK-11: debe dar BUILD SUCCESS y un puntaje >= 80 %
./mvnw -B -ntp test-compile org.pitest:pitest-maven:mutationCoverage
# D6: debe dar BUILD FAILURE por el umbral
./mvnw -B -ntp test-compile org.pitest:pitest-maven:mutationCoverage -Dpit.targetTests='com.demo.data.*Test'
# CHK-15: pureza de src/main (pasa sin salida)
git grep -nE 'System\.(getenv|getProperty)|java\.nio\.file|java\.io\.File|getResource|org\.openqa|io\.cucumber|org\.junit' -- src/main/java
# CHK-16: aislamiento de las pruebas unitarias (pasa sin salida)
git grep -nE 'org\.openqa|io\.cucumber|com\.demo\.(utils|pages|steps|hooks|runners)|System\.getenv|"\.env"' -- src/test/java/com/demo/config src/test/java/com/demo/data
# Solo hay pruebas en esos directorios (pasa sin salida)
git ls-files src/test/java/com/demo/config src/test/java/com/demo/data | grep -v 'Test\.java$'
```

Además:
- Existe `target/pit-reports/mutations.xml` y el log no contiene `Skipping project`: el `BUILD SUCCESS` de CHK-11 no basta (*Enmiendas*).
- `target/pit-reports/index.html` lista solo clases de `com.demo.config` y `com.demo.data`.
- El log de PIT no ejecuta `RunnerTest` ni el motor `cucumber`.
- Cada mutante sobreviviente tiene su justificación (D5).

## Riesgos

Este ADR se escribió sin red y sin `./mvnw`. El estado refleja el paso 6: todos los riesgos están cerrados, resueltos o mitigados (*Enmiendas*).

| # | Supuesto | Lo confirma | Si es falso | Estado (2026-10-09) |
|---|---|---|---|---|
| R-1 | `pitest-maven` solo muta `target/classes` | devops, paso 1: el reporte | `pages` y `steps` saldrían como NO_COVERAGE y el umbral fallaría (error visible, nunca un verde falso); se acota `targetClasses` por enmienda | **Confirmado** |
| R-2 | Las versiones de referencia existen y son compatibles con JUnit 5.14.2 y Java 17 | devops, en Maven Central | Se usa la última estable compatible | **Resuelto:** 1.30.0 y 1.2.3 (D4) |
| R-3 | PIT aporta `junit-platform-launcher` | devops, paso 1: la fase de cobertura encuentra las pruebas | Se agrega desde el BOM (D4) | **Refutado:** no hace falta |
| R-4 | Los motores `cucumber` y `junit-platform-suite` no descubren nada con un selector de una clase que no es `@Suite` | verifier, paso 5: el log | Se excluyen los motores por enmienda | **Cerrado** (verifier, paso 5): solo corrió `[engine:junit-jupiter]`, sin `RunnerTest`, Cucumber ni navegador |
| R-5 | La composición exacta de `STRONGER` en la versión elegida | Los mutadores del reporte | Se documenta la composición real en este ADR | **Resuelto** (verifier, paso 5, `javap` sobre `StandardMutatorGroups` de 1.30.0): `STRONGER` = `DEFAULTS` + `REMOVE_SWITCH` + `REMOVE_CONDITIONALS_ORDER_IF` + `REMOVE_CONDITIONALS_EQUAL_IF`. `DEFAULTS` ya incluye las variantes `_ELSE` (*Enmiendas*) |
| R-6 | En macOS, los `._*` romperían la compilación de `src/main` (no es reproducible en Linux) | devops, paso 1 | — | **Mitigado;** sin confirmar en macOS. *(Límite aceptado desde el 2026-10-13: no se puede verificar sin un equipo macOS. Lo mitiga la limpieza de `._*` del `pom.xml` (`maven-antrun-plugin`), que se ejecuta siempre: en `generate-sources`, sobre `target/classes` y sobre `target/test-classes` (paso 1). El perfil `macos-selenium-manager-isolated-path` del mismo `pom.xml` cubre otro problema de macOS, el driver de Homebrew en cuarentena, no este. Se reabre si un colaborador con macOS informa de un fallo.)* |
| R-7 | El tiempo se mantiene dentro del presupuesto de D5 | El primer run de CI | Se investiga la E/S en las pruebas | **Cerrado en cuanto al resultado** (paso 6): el usuario confirmó el run remoto de `90687f4` en verde, sin informar el tiempo del job. En local, PIT tarda unos 3 s y Maven con PIT 5,8 s. El tiempo remoto exacto no se midió; lo acota `timeout-minutes: 10` del job `mutation` (`ci.yml:64` en `90687f4`), que haría fallar el job |

## Enmiendas

### 2026-10-09 — Paso 1 (commit `4d75090`, `devops-engineer`)

Sin cambios en D1–D6 ni en el estado. Hallazgos:
- **R-1 confirmado:** con una clase sonda en `src/main/java/com/demo/config`, `mutations.xml` contenía solo esa clase (sin `utils`, `pages` ni `steps`).
- **R-2 resuelto:** `pitest-maven` 1.30.0 y `pitest-junit5-plugin` 1.2.3, confirmados en Maven Central con `./mvnw`; funcionan con JUnit 5.14.2 y Java 17. D4 actualizado.
- **R-3 refutado:** `junit-platform-launcher` no hace falta; con pruebas sonda corrió `[engine:junit-jupiter]`.
- **R-4 parcial:** los logs de PIT no mencionan `RunnerTest`, `cucumber`, `chrome` ni `webdriver`. Lo cierra el verifier en el paso 5.
- **R-6 mitigado:** la limpieza de `._*` pasa a `generate-sources` y se agrega una ejecución sobre `target/classes` en `process-classes`. Sin confirmar en macOS. *(Límite aceptado desde el 2026-10-13: *Riesgos*, R-6.)*
- **Fallo abierto de CHK-11 (corrige el paso 1):** sin `target/classes`, PIT 1.30.0 imprime `Skipping project because: Project has either no tests or no production code` y termina en `BUILD SUCCESS`, aun con `failWhenNoMutations=true` (`pom.xml:221`). Ningún parámetro lo cambia. Mitigación en el paso 6: el job `mutation` y el gate exigen `target/pit-reports/mutations.xml` y tratan `Skipping project` como rechazo cuando existe `src/main/java`. Se agrega el mismo requisito al *Criterio de verificación*.
- **Comprobado en una copia aislada:** D6 da `BUILD FAILURE` con un puntaje de 50 % frente al umbral de 80; `-DmutationThreshold=0` no baja el umbral (D5); Surefire ejecuta las pruebas unitarias (D3).
- Cambios a reglas y agentes aplicados, salvo los pendientes indicados en su sección. Cita corregida: el *Estado actual* de la Regla 04 está en `:66`, no en `:53`. *(Todos aplicados al cierre del paso 6: enmienda *Paso 6 y cierre*.)*

### 2026-10-09 — Pasos 2 a 5 (commits `decb120` y `afe8618`; los pasos 4 y 5 aún sin commit)

*(El paso 4 quedó en `c8486ee`; el paso 5 es la verificación y no tiene commit propio.)*

Sin cambios en D1–D6 ni en el estado. Resultado del paso 5 (`qa-test-verifier`, APROBADO):
- **`src/main` completo:** `ConfigResolver`, `DotEnvParser` y `SecretResolver` (`com.demo.config`) y `Credentials` (`com.demo.data`), con 90 pruebas unitarias. CHK-08 da 95 (5 E2E y 90 unitarias) en las dos ejecuciones.
- **CHK-11:** 73/73 KILLED (100 %): 33 en `ConfigResolver`, 1 en `Credentials` y 39 en las dos clases de secretos. Sin `Skipping project` y con `mutations.xml` presente. PIT omite los métodos generados del record (`Record junk mutation filter`).
- **D6:** `BUILD FAILURE` con un puntaje de 1 frente al umbral de 80.
- **R-4 cerrado y R-5 resuelto** (*Riesgos*). Se corrige D5: `REMOVE_CONDITIONALS_EQUAL_ELSE` ya está en `DEFAULTS`; `STRONGER` agrega las variantes `_IF` y `REMOVE_SWITCH`. La decisión no cambia. Las variantes `_IF` aportaron 24 de los 73 mutantes (`EQUAL_IF` 21, `ORDER_IF` 3).
- **Lo que PIT no alcanza** (`requireNonNull`, entrada vacía del parser, `trim` tras `export` y accesores del record): el coordinador lo validó con control negativo manual en copias aisladas sin `.env` (2 casos en el paso 2, 5 en el paso 3 y 3 en el paso 4), todos con rojo observado.
- `AGENTS.md` y `README.md` describen `src/main/java` y las pruebas unitarias; el verifier comprobó que coinciden con `git ls-files`.
- **Pendiente:** solo el paso 6 y, con él, el *Estado actual* de la Regla 04 y R-7. *(Hecho en `90687f4` y `e4dd132`: enmienda siguiente.)*

### 2026-10-09 — Paso 6 y cierre (commit `90687f4`, `devops-engineer`)

Sin cambios en D1–D6 ni en el estado. Con este paso, el ADR queda **completamente implementado**: no le quedan pasos ni cambios a reglas o agentes pendientes.

- **Guarda contra el fallo abierto de PIT** (`scripts/check-mutation-report.sh`). Corre después de PIT, que ya habrá fallado si el puntaje quedó bajo el umbral. Sale con 1 si:
  - (a) hay código en `src/main/java` y falta `target/pit-reports/mutations.xml`;
  - (b) el log contiene `Skipping project`;
  - (c) el reporte no tiene ninguna mutación;
  - (d) el reporte está truncado (le falta `</mutations>`), el log no tiene el resumen `Generated N mutations`, o N no coincide con las mutaciones del reporte (es un reporte de otra ejecución);
  - (e) no hay ningún `.java` en `src/main/java`. Para retirar el código mutable hay que enmendar este ADR y retirar el job.
- **Criterio de falla cerrada:** la guarda solo da 0 si demuestra que el reporte existe, es completo y es de esta ejecución. Una raíz equivocada, un reporte anterior o un log sin resumen se rechazan. Ante un error de uso sale con 2. Automatiza la condición de `mutations.xml` y `Skipping project` del *Criterio de verificación*: el `BUILD SUCCESS` de PIT no basta (enmienda del paso 1).
- **`scripts/check-unit-purity.sh`:** ejecuta CHK-15 y CHK-16 con los comandos de la Regla 04, para que GitHub Actions y Jenkins no repitan las expresiones regulares. También falla cerrado: si `git grep` termina con un código mayor que 1 (un error), el resultado es 1.
- **GitHub Actions:** job `mutation` (`ci.yml:62-95` en `90687f4`), en paralelo a `test`, sin `env` de secrets ni navegador y con `timeout-minutes: 10`. Ejecuta el script de pureza, PIT con `pipefail` y `tee` y la guarda, y publica `target/pit-reports/` como artefacto. Los secrets siguen en el `env` del job `test` (`ci.yml:14-20` en `90687f4`).
- **Jenkins:** etapa `Mutation (CHK-11)` (`Jenkinsfile:24-45` en `90687f4`), fuera de `withCredentials` y con un timeout de 10 minutos. Corre antes de `Test`, porque `clean test` borra `target/pit-reports`. Además borra el reporte y el log anteriores, porque el workspace persiste entre builds.
- **Gate local (devops):** CHK-08 dio 95/95 en las dos ejecuciones, CHK-11 dio 73/73 y la guarda terminó en 0. La guarda se probó con 12 controles negativos, todos en rojo, incluido un log real de `Skipping project` con `BUILD SUCCESS`.
- **Run remoto:** el usuario confirmó en la conversación que el CI de `90687f4` está en verde. Con eso se cierra R-7 (*Riesgos*).
- **Reglas y agentes:** el usuario los aplicó, y estaban sin commit al redactar esta enmienda. *(Están en `e4dd132`.)*
  - La Regla 04 agrega la guarda al criterio y al comando de CHK-11 (`:17`, `:47-49`), el comando conjunto de CHK-15/16 (`:60`) y un *Estado actual* con CHK-11, CHK-15 y CHK-16 activas (`:69`).
  - `devops-engineer.md` usa los dos scripts en su tabla (`:38`) y en el paso 7 del gate (`:50`).
  - La invocación de PIT de D5 no cambia: la Regla 04 la envuelve con la guarda.
- **P2 abiertos (no bloquean; dueño: `devops-engineer`):** *(Los dos están cerrados al 2026-10-13.)*
  - `.github/workflows/ci.yml` no declara `permissions: contents: read`, ni en el workflow ni en los jobs. El `GITHUB_TOKEN` queda con los permisos por defecto del repositorio. *(Cerrado en `6c6b95b`, 2026-10-09: permisos mínimos en el workflow.)*
  - El `Jenkinsfile` no se validó en un Jenkins real. *(Cerrado el 2026-10-13, según el usuario: build 3 en `SUCCESS` sobre `a66ea58`, con 10 etapas, incluida `Mutation (CHK-11)`. Ver el R-4 del ADR-002.)*

### 2026-10-13 — Referencias estables a CI y P2 de *Consecuencias*

Sin cambios en D1–D6 ni en el estado.
- **Referencias a CI.** Las citas `ci.yml:<línea>` y `Jenkinsfile:<línea>` quedaron desfasadas con cada job y etapa nuevos (`6c6b95b`, `e6e91bc`, `7faaead`, `1e1e1e3`). Desde esta fecha, este ADR cita la CI por el nombre del job, del paso o de la etapa, que no cambia al editar el archivo. Las citas con número de línea que quedan en D5, *Riesgos* y las enmiendas son registro histórico e indican el commit o la fecha en que eran ciertas. La de D5 para Jenkins (`:26-44`) nunca fue exacta: se escribió antes de crear la etapa.
- **P2 de *Consecuencias* ("Comportamiento actual fijado"):**
  - Que el entorno pueda sobrescribir las claves `*.expected*` lo decide el **ADR-003**, propuesto y aceptado el 2026-10-13. Por decisión del usuario, el ADR-003 también quita el entorno a `base.url` y `remote.url` (D5). Como exige este ADR, la migración empieza por la prueba que fija el comportamiento actual (`ConfigResolverTest.java:130-136`).
  - Lo de `getPositiveInt` y el `0` se resolvió sin cambiar ese getter: `146df90` agregó `getNonNegativeInt` (`ConfigResolver.java:59-61`) para los conteos que admiten cero. `getPositiveInt` sigue rechazando el `0` a propósito, y lo fija `ConfigResolverTest.java:146-154`.
