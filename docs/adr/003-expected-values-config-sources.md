# ADR-003 — Fuentes de configuración de los valores esperados y de los destinos de red

- **Estado:** Aceptado (aprobado por el coordinador, 2026-10-13). Se propuso el mismo día con D1 a D4; D5 incorpora la decisión del usuario sobre R-3, tomada en la conversación el 2026-10-13.
- **Fecha:** 2026-10-13
- **Autor:** `qa-automation-architect`
- **Aprueba:** coordinador (Regla 01, nivel 2). `AGENTS.md` y `.claude/rules/` los cambia el usuario (P-01, PI-07). `README.md` no tiene dueño en la matriz: el usuario designa quién lo edita.
- **Decide:**
  - el P2 que el ADR-001 dejó abierto (*Consecuencias*, "Comportamiento actual fijado"): el entorno puede sobrescribir las claves `*.expected*` (D1 a D4);
  - por decisión del usuario, que tampoco puedan sobrescribirse desde el entorno los destinos de red `base.url` y `remote.url` (D5).

  Cambia la precedencia de `ConfigResolver` (ADR-001, D2 y D3) solo para esas dos clases de clave.

## Contexto

**Por qué importa.**
- Cada `Then` compara lo observado contra una clave `*.expected*` independiente de la entrada, y CHK-10 la sobrescribe con `-D` para demostrar que la aserción puede fallar. Si una fuente no versionada puede cambiar esa clave, el valor esperado de la spec cambia sin que nadie edite la spec ni `config.properties`: la suite compara contra otra cosa y puede quedar en verde.
- `base.url` decide adónde se escriben las credenciales, y `remote.url` adónde va la sesión del navegador. Si una fuente no versionada los cambia, cambia el destino.

Las citas `archivo:línea` son de `afb6693`. Los archivos citados no cambian en `8fa950a`, salvo `README.md`, cuyas líneas citadas siguen iguales. La CI se cita por el nombre del job, del paso o de la etapa.

| Hecho | Evidencia | Consecuencia |
|---|---|---|
| Hay una sola precedencia para todas las claves | `ConfigReader.java:16-17` construye `ConfigResolver(System::getProperty, System::getenv, PROPERTIES)`. `ConfigResolver.java:89-103` aplica: propiedad del sistema > entorno con el nombre exacto > entorno con el nombre normalizado (`:105-118`, `a.b-c` → `A_B_C`) > `config.properties` | Una variable de entorno sustituye cualquier clave, incluidos los esperados y los destinos de red |
| `.env` no es fuente de configuración | Solo `SecretReader` lo lee (`SecretReader.java:15-17`, `:26-37`), y solo para los nombres explícitos de `CredentialsProvider`. `ConfigReader` nunca lo abre (`README.md:301`) | `.env` no puede cambiar una clave por sí mismo. Pero si alguien lo exporta al shell (`set -a; . ./.env`, direnv), sus entradas llegan como entorno |
| Los esperados solo se leen en los steps | 28 claves en `config.properties:18`, `:20-39`, `:42-43` y `:45-49`. Se leen en `CompraSteps.java:39`, `:105`, `:113`, `:122`, `:126`, `:134`, `:142`, `:159`, `:170`, `:178` y `:194`, y en `LoginSteps.java:50` y `:96`. CHK-17 (R4) ya rechaza `\.expected` en `transport`, `pages` y `actions` | El cambio no toca ninguna capa de interfaz |
| Los nombres normalizados chocan con los de los secrets | `test.login.cases.locked-user.expected-error` se normaliza como `TEST_LOGIN_CASES_LOCKED_USER_EXPECTED_ERROR`. Tiene el mismo prefijo que los secrets `TEST_LOGIN_CASES_LOCKED_USER_USERNAME` y `…_PASSWORD` (`.env.example:4-5`). Esos secrets entran en el `env` de los jobs `test`, `e2e-firefox`, `e2e-grid` y `quarantine` de `ci.yml`, y en las etapas `Test` y `Cuarentena (CHK-14)` del `Jenkinsfile` | Un secret o una variable de CI con ese nombre cambiaría el esperado sin dejar rastro en el repositorio. Además, GitHub y Jenkins enmascaran el valor de un secret en los logs, así que tampoco se vería en el mensaje de la aserción |
| Los destinos de red se leen en dos sitios | `base.url` (`config.properties:2`): `LoginPage.java:24` y `InventoryPage.java:35`. `remote.url` (`:5`, vacío = ejecución local): `DriverFactory.java:22`, con `getOptional` | `BASE_URL` y `REMOTE_URL` son nombres comunes en otros proyectos. Si existen en un agente compartido o en la máquina de un desarrollador, cambian el destino de las credenciales o de la sesión (P-07, PI-08) |
| La CI ya fija `remote.url` con `-D` | Job `e2e-grid`, paso *Run E2E (Selenium Grid, Chrome)*: `-Dremote.url=http://localhost:4444`. También lo usan `AGENTS.md:20` y `README.md:486`. `git grep -n -e REMOTE_URL -e BASE_URL -- ':!docs/adr'` solo encuentra `README.md:307` | Quitar el entorno a los destinos no cambia la CI ni el `Jenkinsfile` |
| CHK-10 necesita sobrescribir los esperados | La Regla 04 usa `-D<clave.esperada>=__CONTROL_NEGATIVO__`. Surefire pasa las propiedades `-D` de Maven al JVM de las pruebas: así funciona hoy CHK-10, sin esperados en `systemPropertyVariables` (`pom.xml:191-194`). Lo fija `ConfigResolverTest.java:138-144` | La propiedad del sistema debe seguir ganando |
| Una prueba fija el comportamiento actual | `ConfigResolverTest.java:128-136` (`environmentCanOverrideExpectedKeysTodayP2`). El ADR-001 exige: "si cambian, primero cambian sus pruebas" | La migración empieza por esa prueba |
| El entorno también llega a las propiedades del sistema | Según la documentación de Maven 3.9 y del JDK, sin ejecutar aquí (B-01): `MAVEN_ARGS` (Maven 3.9.9, `.mvn/wrapper/maven-wrapper.properties:3`), `.mvn/maven.config` (no existe: `git ls-files .mvn` solo lista el wrapper), y `JAVA_TOOL_OPTIONS` y `JDK_JAVA_OPTIONS`, que lee el JVM de Surefire | Dentro del JVM no se distingue un `-D` escrito en el comando de uno que vino del entorno. Para los esperados, hay que hacerlo visible (D3) |
| El entorno se usa en otras claves | `README.md:297` y `:307` (`REMOTE_URL` sobrescribe `remote.url`). `headless` se lee con `getBoolean` (`DriverFactory.java:23`) | Quitar el entorno de todas las claves rompería una función documentada. Para `remote.url`, el usuario decidió quitarlo (D5) |

## Decisión

### D1. Qué es una clave de esperado

- Es una clave en la que algún segmento (separado por `.`) empieza por `expected`, sin distinguir mayúsculas. La expresión es `(?i)(^|\.)expected`, evaluada con `find()`.
- Cubre las 28 claves actuales: las de la forma `*.expected.*` (`inventory`, `catalog`, `checkout`, `cart`) y las de la forma `*.expected-error` (`test.login.cases.*`).
- Usa la misma marca que R4 de CHK-17 (`\.expected`), pero anclada al inicio de un segmento: `a.unexpected.b` no es un esperado.
- **Falla cerrado:** en la duda, como con `a.expectedValue`, la clave se trata como esperado. El coste es solo que esa clave pierde el entorno como fuente.
- Vive en `ConfigResolver` (`src/main`, pura y con PIT), la capa más baja que puede absorberlo. La API de `ConfigReader` no cambia.

### D2. Fuentes permitidas por clase de clave

| Clase | Propiedad del sistema (`-D`) | Entorno, nombre exacto | Entorno, nombre normalizado | `config.properties` | `.env` | Aviso si gana `-D` |
|---|---|---|---|---|---|---|
| Esperado (D1) | **Sí**, y gana (CHK-10) | **No** | **No** | Sí | No | Sí (D3) |
| Destino de red (D5) | **Sí**, y gana | **No** | **No** | Sí | No | No (D5) |
| Resto | Sí, y gana | Sí | Sí | Sí | No | No |

- **Precedencia.** Para un esperado o un destino de red, la precedencia es: propiedad del sistema > archivo.
  - Un valor en blanco en la propiedad del sistema sigue ganando, como hoy (ADR-001, D3). `getRequired` lo rechaza, y `getOptional("remote.url")` lo devuelve como ejecución local.
- **Si solo está en el entorno,** la clave se trata como ausente: falla cerrado.
  - Un esperado falla con `La configuración obligatoria '<clave>' no tiene valor`.
  - Un `REMOTE_URL` solo en el entorno no tiene efecto: la ejecución es local, como con `remote.url=` en el archivo.
  - `base.url` siempre está en el archivo.
- `.env` sigue sin ser fuente de `ConfigReader`.
- **Regla única en `ConfigResolver`:** `private static boolean acceptsEnvironment(String key)`, pura.
  - Devuelve `false` si la clave es un esperado (`EXPECTED_KEY`, D1) o un destino de red (`NETWORK_DESTINATION_KEY`, D5). Si no, devuelve `true`.
  - `resolve` la consulta después de la propiedad del sistema. Si da `false`, devuelve directamente el valor del archivo.
  - Es el único punto que decide el entorno. El aviso de D3 usa solo `EXPECTED_KEY`.
- **Motivo:** los secrets y las variables de CI solo llegan al JVM como variables de entorno. En cambio, el `-D` es explícito: está versionado en `ci.yml` y en el `Jenkinsfile`, o lo escribe quien ejecuta el comando.
- **Comprobación:** `git grep -n -i -P '^[^#=]*((^|\.)expected|(^|[.-])url=)' -- src/test/resources/config.properties` lista las 30 claves sin entorno de hoy: las 28 de esperados, `base.url` y `remote.url`.

### D3. Una sobrescritura por `-D` de un esperado queda visible

- `ConfigResolver` expone una consulta pura, `boolean overridesExpectedValue(String key)`.
  - Devuelve `true` si la clave es un esperado (D1) y la propiedad del sistema la define, aunque esté en blanco.
  - Devuelve `false` con los destinos de red (D5) y con el resto de las claves.
  - Con una clave `null` lanza la misma NPE que hoy: `La clave de configuración no puede ser null`.
- `ConfigReader` registra un `WARN` antes de resolver la clave, una vez por clave y por JVM (con un conjunto concurrente, porque hay 2 hilos):
  - Texto: `La clave de esperado '<clave>' viene de una propiedad del sistema (-D): solo es válido en el control negativo (CHK-10)`.
  - **Nunca registra el valor**, que puede venir de `MAVEN_ARGS`.
  - Usa SLF4J, que ya está en el classpath de pruebas (`pom.xml:90-93`) y que `Navegador.java:19-20` ya usa.
- **Motivo:**
  - D2 no puede distinguir dentro del JVM un `-D` que llegó desde el entorno (*Contexto*). D3 lo hace visible.
  - En cada control negativo, el aviso da al verifier una prueba positiva de que la sobrescritura tocó la clave.
- En la suite normal (CHK-08), el log no contiene el aviso. Convertir el aviso en un fallo de CI es P2 (R-2), no parte de esta decisión.

### D4. Lo que no cambia

- La API pública de `ConfigReader`. `ConfigResolver` suma un solo método público (D3).
- Los textos de los steps, las features, `config.properties`, el POM, la CI, el `Jenkinsfile` y el comando de CHK-10 (Regla 04 y tabla de CHK-10 del ADR-002).
- La precedencia de las claves que no son esperados ni destinos de red, incluidos los datos de entrada (`test.purchase.*`, `test.checkout.*`) y las opciones de ejecución (`browser`, `headless`). Cambiar un dato de entrada no produce un verde falso, porque cada `Then` compara contra un esperado independiente.

### D5. Destinos de red: `base.url` y `remote.url` (decisión del usuario, 2026-10-13)

- **Decisión del usuario,** tomada en la conversación el 2026-10-13 y transmitida por el coordinador: `base.url` y `remote.url` dejan de aceptar variables de entorno, igual que los esperados. Solo admiten `-D` y `config.properties` (PI-08). Cierra R-3.
- **Qué es un destino de red:** una clave cuyo último segmento es `url` o termina en `-url`, sin distinguir mayúsculas. La expresión es `(?i)(^|[.-])url$`, evaluada con `find()`.
  - Hoy son exactamente `base.url` y `remote.url` (comando de D2).
  - Falla cerrado: una clave de URL nueva nace sin entorno. Se prefiere a la lista exacta por el mismo motivo que en D1: una lista falla abierto.
  - No son destinos `a.url.b` (`url` no es el último segmento) ni `a.curl` (el segmento no es `url` ni termina en `-url`).
- **Sin aviso cuando gana `-D`:**
  - `-Dremote.url` es el uso normal de la CI (job `e2e-grid`) y de la ejecución contra el Grid local (`AGENTS.md:20`, `README.md:486`).
  - Un aviso en cada run sería ruido y además impediría convertir el aviso de D3 en un fallo de CI (R-2).
  - El destino ya queda a la vista: el mensaje de error de `abrir` incluye la URL (ADR-002, D1).
- `remote.url` sigue admitiendo el valor vacío, que significa ejecución local, por `-D` o por el archivo (`README.md:303`).
- **Motivo:** `base.url` decide adónde se escriben las credenciales, y `remote.url` adónde va la sesión del navegador, con lo que se escribe en ella. Una variable de entorno ajena al proyecto no debe cambiar ninguno de los dos.

## Alternativas consideradas

| Alternativa | Motivo del descarte |
|---|---|
| No cambiar nada y documentar el riesgo | El choque con los nombres `TEST_LOGIN_CASES_*` de los secrets es plausible, y un secret enmascarado no deja rastro ni en el mensaje de la aserción |
| Quitar el entorno de todas las claves | Rompe una función documentada (`README.md:307`) y no hace falta: cambiar un dato de entrada o una opción de ejecución no puede producir un verde falso ni cambiar un destino. Los destinos sí lo pierden (D5) |
| Quitar también la propiedad del sistema para los esperados | Rompe CHK-10, que es la validación de toda la E2E (ADR-001: el SUT no se puede mutar) |
| Control negativo por otro canal (un archivo `config-negative.properties` o un perfil Maven) | Más superficie, y cambia el comando de CHK-10 en la Regla 04 y en el ADR-002 sin ganancia: `-D` ya es explícito |
| Mover los esperados a un archivo aparte (`expected.properties`), leído solo del classpath | Separa más, pero mueve 28 claves, cambia la convención de los steps y la de R4, y CHK-10 sigue necesitando `-D`. Es desproporcionado para cerrar un canal |
| Clasificar con una lista explícita de claves, para esperados o destinos | Falla abierto: una clave nueva quedaría expuesta al entorno hasta que alguien actualizara la lista |
| Solo avisar cuando el entorno define un esperado o un destino, sin bloquearlo | Nadie lee un aviso en un run en verde. El objetivo es que el valor no cambie |
| Rechazar un `-D` de esperado cuando `CI=true` | Depende de una variable que el mismo canal puede quitar. El riesgo que se cubre es un choque accidental de nombres, no un adversario con acceso a la configuración de la CI (Regla 02, *Límite honesto*). Queda como P2 (R-2) |
| Avisar también cuando `-D` define un destino | `-Dremote.url` es el uso normal de la CI. El aviso sería ruido en cada run de `e2e-grid` y bloquearía el P2 de R-2 |
| Quitar el entorno solo a `base.url` | `remote.url` también es un destino: la sesión del navegador y lo que se escribe en ella van a ese host. El usuario decidió los dos |

## Consecuencias

- **Positivas:**
  - Ningún secret ni variable de entorno puede cambiar un esperado ni un destino de red.
  - Los esperados tienen dos fuentes, y las dos se ven: el archivo versionado y el `-D`, que además deja un aviso.
  - Las credenciales y la sesión solo van a destinos escritos en el repositorio o en el comando.
  - CHK-10 queda intacto, y la CI no cambia.
  - La regla vive en `src/main`, y PIT la cubre.
- **Costes:**
  - `ConfigResolver` suma dos patrones, una regla privada y un método público, con unas 15 pruebas unitarias nuevas.
  - `ConfigReader` suma unas 10 líneas. El aviso vive en una fachada que PIT no muta: si se rompe, solo se pierde la visibilidad (R-5).
- **Comportamiento que cambia:**
  - `CART_EXPECTED_COUNT=9 ./mvnw …` deja de cambiar el esperado. Hoy nadie lo usa: `git grep -n "_EXPECTED" -- ':!docs/adr'` solo lo encuentra en `ConfigResolverTest.java:133`.
  - `REMOTE_URL=… ./mvnw …` y `BASE_URL=… ./mvnw …` dejan de tener efecto; se usa `-Dremote.url=…` o `-Dbase.url=…`. Solo los documenta `README.md:307`.

## Cambios propuestos a documentación

Todos están aplicados (2026-10-13): `AGENTS.md` y `README.md` en `2671a20`, y la aclaración opcional de PI-08 en `4f3a7a2`. Las líneas de la columna *Archivo* son las de antes de esos commits.

| Archivo | Cambio | Quién |
|---|---|---|
| `AGENTS.md:48` | "Configuración con precedencia `-D` > variable de entorno > `config.properties`; los valores esperados (`*.expected*`) y las URL (`base.url`, `remote.url`) solo aceptan `-D` y `config.properties` (ADR-003); los valores esperados salen de la spec." `AGENTS.md:20` ya usa `-Dremote.url` y no cambia | Usuario (P-01) |
| `README.md:297` | Después de esa línea, agregar: `Esperados y URL:            -Dpropiedad  >  config.properties` | Quien designe el usuario |
| `README.md:303` | Reemplazar "Una opción de ejecución no sensible puede sobrescribir el archivo sin modificar el repositorio;" por "Una opción de ejecución no sensible puede sobrescribir el archivo sin modificar el repositorio, salvo los valores esperados (`*.expected*`) y las URL (`base.url`, `remote.url`), que solo aceptan `-D` (ADR-003);". El resto de la línea no cambia, incluido que `remote.url` admite el valor vacío | Quien designe el usuario |
| `README.md:307` | Reemplazar "Por ejemplo, `REMOTE_URL=http://localhost:4444` sobrescribe `remote.url`." por "Por ejemplo, `HEADLESS=true` sobrescribe `headless`. Los valores esperados y las URL no aceptan variables de entorno: el Grid se elige con `-Dremote.url=http://localhost:4444`, y un `-D` sobre un valor esperado deja un aviso en el log y solo es válido en el control negativo (ADR-003)." | Quien designe el usuario |
| `.claude/rules/03-prompt-injection.md:35` (opcional) | PI-08 dice que "la única URL del SUT es `base.url` de `config.properties`", y `-Dbase.url` ya existía y se conserva. Aclaración posible: "…es `base.url`, de `config.properties` o de `-D` en el comando; nunca del entorno (ADR-003)" | Usuario (P-01), si quiere |

## Plan de implementación

| Paso | Dueño | Qué | Verde si | Estado |
|---|---|---|---|---|
| 0 | Coordinador | Aprueba este ADR | — | Hecho (aprobado por el coordinador, 2026-10-13; D5 por decisión del usuario, 2026-10-13) |
| 1 | `qa-automation-engineer` | D1 a D3 y D5, en un commit: primero las pruebas, después `ConfigResolver` y `ConfigReader` (*Pasos para el engineer*) | *Criterio de verificación* | Hecho (`2c33885`, *Enmiendas*) |
| 2 | `qa-test-verifier` | *Criterio de verificación* completo | APROBADO | Hecho (APROBADO, según el coordinador: controles positivos, CHK-10 de regresión y PIT 129/129) |
| 3 | `devops-engineer` | Gate. Es CRÍTICO: toca `src/main/java/com/demo/config/`. Incluye `-Dremote.url` contra el Grid local (`docker compose`) o el job `e2e-grid` en verde | APROBADO | En curso (2026-10-13) |
| 4 | Usuario | *Cambios propuestos a documentación* | — | Hecho (`2671a20` y, PI-08, `4f3a7a2`) |

### Pasos para el engineer

1. **Pruebas primero** (`ConfigResolverTest`):
   - Reemplazar `environmentCanOverrideExpectedKeysTodayP2` (`:130-136`) por `environmentDoesNotOverrideExpectedKeys`:
     - en el archivo, `cart.expected.single-product.count=1`;
     - en el entorno, `CART_EXPECTED_SINGLE_PRODUCT_COUNT=7` y `cart.expected.single-product.count=7`;
     - `getPositiveInt` devuelve `1`.
   - Conservar `systemOverridesExpectedKeysSoTheNegativeControlWorks` (`:138-144`).
   - Agregar, cada uno con valores concretos. Esperados (D1):
     - a. El sufijo `expected-error`: `test.login.cases.locked-user.expected-error`, con `TEST_LOGIN_CASES_LOCKED_USER_EXPECTED_ERROR=entorno` y `archivo` en el archivo, devuelve `archivo`.
     - b. Un esperado que solo está en el entorno es ausente. Con `INVENTORY_EXPECTED_TITLE=entorno`:
       - `getOptional("inventory.expected.title")` devuelve `""`;
       - `getRequired` lanza `IllegalStateException` con `La configuración obligatoria 'inventory.expected.title' no tiene valor`.
     - c. Primer segmento: `expected.x`, con `EXPECTED_X=entorno` y `archivo` en el archivo, devuelve `archivo`.
     - d. Sin distinguir mayúsculas: `a.Expected.b`, con el entorno exacto `a.Expected.b=entorno` y `archivo` en el archivo, devuelve `archivo`.
     - e. Prefijo de segmento: `a.expectedValue`, con `A_EXPECTEDVALUE=entorno` y `archivo` en el archivo, devuelve `archivo`.
     - g. Un blanco en la propiedad del sistema gana: `cart.expected.count`, con `" "` en el sistema y `2` en el archivo, `getOptional` devuelve `" "`.
   - Destinos de red (D5):
     - i. `remote.url` con `remote.url=` vacío en el archivo, y en el entorno `REMOTE_URL=http://localhost:9` y `remote.url=http://localhost:9`: `getOptional` devuelve `""`.
     - j. `base.url` con `https://www.saucedemo.com` en el archivo, y en el entorno `BASE_URL=http://otro-host.invalid` y `base.url=http://otro-host.invalid`: `getRequired` devuelve `https://www.saucedemo.com`.
     - k. `-D` gana para un destino. `remote.url=http://localhost:4444` en el sistema, `REMOTE_URL=http://localhost:9` en el entorno y `""` en el archivo devuelven `http://localhost:4444`. Con `remote.url=""` en el sistema y el mismo entorno devuelve `""`.
     - l. El patrón: `a.Base.URL` (entorno exacto) y `grid-url` (`GRID_URL`), los dos con `entorno` en el entorno y `archivo` en el archivo, devuelven `archivo`.
   - Claves que conservan el entorno:
     - f. `a.unexpected.b` con `A_UNEXPECTED_B=entorno`, `a.url.b` con `A_URL_B=entorno` y `a.curl` con `A_CURL=entorno` devuelven `entorno`.
     - m. `headless` con `HEADLESS=true` en el entorno y `false` en el archivo: `getBoolean` devuelve `true`. Es la regresión de lo documentado en `README.md:307`.
   - h. `overridesExpectedValue`:
     - devuelve `true` con un esperado en el sistema, también con `""`;
     - devuelve `false` con un esperado que solo está en el entorno y en el archivo;
     - devuelve `false` con `remote.url` y con `base.url` en el sistema (D5: sin aviso);
     - devuelve `false` con `headless` en el sistema;
     - con `null` lanza NPE con `La clave de configuración no puede ser null`.
   - **Control negativo de las pruebas:** antes de tocar `ConfigResolver`, con las pruebas nuevas que no llaman a `overridesExpectedValue` (es decir, todas menos la h), fallan:
     - `environmentDoesNotOverrideExpectedKeys`;
     - a, b, c, d y e;
     - i, j y l.

     f, g, k y m pasan antes y después. Se adjunta la salida.
2. **`ConfigResolver`:**
   - `private static final Pattern EXPECTED_KEY = Pattern.compile("(^|\\.)expected", Pattern.CASE_INSENSITIVE)`.
   - `private static final Pattern NETWORK_DESTINATION_KEY = Pattern.compile("(^|[.-])url$", Pattern.CASE_INSENSITIVE)`.
   - La regla única `acceptsEnvironment(key)` (D2): `!(EXPECTED_KEY.matcher(key).find() || NETWORK_DESTINATION_KEY.matcher(key).find())`.
   - En `resolve`, después de la propiedad del sistema: si `!acceptsEnvironment(key)`, devuelve `fileProperties.getProperty(key)`. Para el resto de las claves, sin cambios.
   - `overridesExpectedValue` (D3) usa solo `EXPECTED_KEY`.
   - Actualizar el Javadoc de la clase (`:10-17`) con D2 y D5 y una cita a este ADR.
3. **`ConfigReader`:**
   - Antes de delegar, cada getter público llama a un método privado que avisa una vez por clave, en `WARN`, si `RESOLVER.overridesExpectedValue(key)`.
   - El conjunto de claves avisadas es `ConcurrentHashMap.newKeySet()`.
   - El texto es el de D3, sin el valor.

## Criterio de verificación

```bash
# Pureza, aislamiento y capas (sin salida o exit 0)
bash scripts/check-unit-purity.sh
bash scripts/check-layers.sh
# CHK-07 y CHK-08 dos veces: Tests run = el anterior + las pruebas nuevas; el log no contiene "La clave de esperado"
./mvnw -B -ntp clean test -Dheadless=true -Dcucumber.filter.tags="not @quarantine"
# CHK-11: >= 80 % y guarda en 0; cada mutante nuevo de ConfigResolver, muerto o justificado
rm -rf target/pit-reports
bash -c 'set -o pipefail; ./mvnw -B -ntp test-compile org.pitest:pitest-maven:mutationCoverage 2>&1 | tee pit.log' && bash scripts/check-mutation-report.sh pit.log
# D6 del ADR-001: sigue en BUILD FAILURE
./mvnw -B -ntp test-compile org.pitest:pitest-maven:mutationCoverage -Dpit.targetTests='com.demo.data.*Test'
# D2, control positivo: el entorno ya no cambia el esperado -> BUILD SUCCESS, sin el aviso de D3.
# Con el ConfigResolver de afb6693 (igual en 8fa950a), el mismo comando falla en el Then: eso prueba que la variable llegaba.
CART_EXPECTED_SINGLE_PRODUCT_COUNT=9 ./mvnw -B -ntp test -Dheadless=true -Dcucumber.filter.tags="@AC-COMPRA-04"
# D5, control positivo: REMOTE_URL y BASE_URL en el entorno no tienen efecto -> BUILD SUCCESS
# con Chrome local contra SauceDemo, sin aviso. localhost:9 es un puerto local cerrado: no sale tráfico (P-07).
# Con el código anterior, el primero falla al crear el driver remoto en @Before, y el segundo en abrir
# (página de error de red, ADR-002, D1).
REMOTE_URL=http://localhost:9 ./mvnw -B -ntp test -Dheadless=true -Dcucumber.filter.tags="@AC-LOGIN-01"
BASE_URL=http://localhost:9 ./mvnw -B -ntp test -Dheadless=true -Dcucumber.filter.tags="@AC-LOGIN-01"
```

Estos controles solo fijan variables que no son secretas para el proceso de Maven: no leen ni imprimen el entorno (P-02).

**CHK-10 de regresión.** Cubre cada getter y las dos formas de clave. Cada ejecución debe fallar con `AssertionFailedError` en el `Then`, y su log debe contener el aviso de D3 con la clave:

| AC | `-D` | Getter |
|---|---|---|
| AC-LOGIN-01 | `inventory.expected.title=__CONTROL_NEGATIVO__` | `getRequired` |
| AC-LOGIN-02 | `test.login.cases.locked-user.expected-error=__CONTROL_NEGATIVO__` | `getRequired` (forma `expected-error`) |
| AC-COMPRA-04 | `cart.expected.single-product.count=9` | `getPositiveInt` |
| AC-COMPRA-05 | `cart.expected.empty.counter-displayed=true` y, aparte, `cart.expected.empty.count=9` | `getBoolean` y `getNonNegativeInt` |
| AC-COMPRA-06 | `catalog.expected.products=__CONTROL_NEGATIVO__` | `getList` |

**`-Dremote.url` sigue funcionando** (gate de devops): el job `e2e-grid`, o `docker compose up -d` con `-Dremote.url=http://localhost:4444`, queda en verde y sin el aviso de D3.

**Efecto en las CHK:**
- CHK-15 sigue sin salida: `ConfigResolver` solo usa `java.util.regex`, sin `System`.
- CHK-16 sigue sin salida: las pruebas nuevas construyen sus fuentes en memoria.
- CHK-17 no cambia ni su script ni su autoprueba. `utils` → `config` ya está permitido (D4 del ADR-002), y SLF4J no es Selenium.
- CHK-10 conserva su comando. CHK-11 suma los mutantes de `ConfigResolver`, incluidos los dos lados del `||` de la regla única, que las pruebas i, j, l, f y a cubren por separado.

## Riesgos

Este ADR se escribió sin ejecutar nada: solo se leyeron archivos y se buscó con `git grep` (B-01).

| # | Supuesto | Lo confirma | Si es falso |
|---|---|---|---|
| R-1 | Surefire pasa al JVM de las pruebas las propiedades `-D` de la línea de comandos | Hoy CHK-10 funciona en cada AC (`MEMORY.md`), y el job `e2e-grid` usa `-Dremote.url`. El paso 1 lo vuelve a demostrar | CHK-10 dejaría de fallar en el `Then`. El verifier lo rechaza |
| R-2 | Un `-D` que llega desde el entorno (`MAVEN_ARGS`, `JAVA_TOOL_OPTIONS`, `JDK_JAVA_OPTIONS`) es deliberado, no un choque accidental de nombres | Documentación de Maven y del JDK. No se ejecutó (B-01) | Para los esperados, D3 lo deja en el log. **P2 (`devops-engineer`):** que los jobs E2E fallen si su log contiene el aviso de D3; exige `tee` en `test`, `e2e-firefox` y `e2e-grid`. Para los destinos no hay aviso (D5): es un riesgo residual aceptado |
| R-3 | `base.url` y `remote.url` siguen aceptando el entorno (`BASE_URL`, `REMOTE_URL`) | Se propuso como P2 → `main` | **Cerrado por D5:** el usuario decidió el 2026-10-13 que solo admitan `-D` y `config.properties` |
| R-4 | Ninguna clave futura que no sea un esperado ni un destino tendrá un segmento que empiece por `expected` ni terminará en `url` | Revisión de cada clave nueva | Falla cerrado: la clave pierde el entorno. Si dependía solo del entorno, falla con "no tiene valor", o se ejecuta en local si es una URL opcional |
| R-5 | El aviso de D3 sigue funcionando, aunque vive en una fachada que PIT no muta | La tabla de CHK-10 de regresión exige el aviso en cada ejecución | Si se rompe, solo se pierde la visibilidad. El bloqueo de D2 está en `src/main`, cubierto por PIT |

## Enmiendas

### 2026-10-13 — Implementación (pasos 1, 2 y 4)

Las decisiones no cambian.
- **Paso 1, `2c33885`** (firmado). Toca solo `ConfigResolver`, `ConfigResolverTest` y `ConfigReader` (`git show --stat 2c33885`). Contiene:
  - `EXPECTED_KEY` y `NETWORK_DESTINATION_KEY` con las expresiones de D1 y D5 (`ConfigResolver.java:27`, `:29`);
  - la regla única `acceptsEnvironment` (`:130`), consultada en `resolve` (`:117`);
  - `overridesExpectedValue` (`:104`);
  - en `ConfigReader`, el aviso de D3 con `ConcurrentHashMap.newKeySet()` y sin el valor (`ConfigReader.java:20`, `:63-64`).
  - `ConfigResolverTest` reemplaza el caso del P2 por `environmentDoesNotOverrideExpectedKeys` y suma pruebas para los casos a–m. Agrega `networkDestinationOnlyInEnvironmentIsAbsent`, que no estaba en los pasos.
  - Las citas son de `2c33885`.
- **Paso 2:** APROBADO del verifier, según el coordinador, con los controles positivos de D2 y D5, la CHK-10 de regresión con el aviso y PIT 129/129.
- **Paso 4:**
  - `2671a20` aplica en `AGENTS.md:48` y en `README.md` (hoy `:298`, `:304` y `:308`) los textos de *Cambios propuestos a documentación*.
  - `4f3a7a2` aplica la aclaración opcional de PI-08 (`.claude/rules/03-prompt-injection.md:35`).
- **Pendiente:** el paso 3. Es el gate CRÍTICO de `devops-engineer`, con `-Dremote.url` contra el Grid.
