# ADR-003 — Fuentes de configuración de los valores esperados y de los destinos de red

- **Estado:** Aceptado (aprobado por el coordinador, 2026-10-13). Se propuso el mismo día con D1 a D4; D5 incorpora la decisión del usuario sobre R-3, tomada en la conversación el 2026-10-13. Está completamente implementado desde el 2026-10-13 (*Enmiendas*, paso 3). Su último P2, R-2, está implementado en `3be5956` como CHK-19 y cerrado con el control real con Maven del gate de `3bab4b2` (*Enmiendas*, *R-2 implementado*). *(Enmienda 2026-10-13, D6, aprobada por el coordinador: cada destino de red deja en el log su fuente y su host, y CHK-19 exige la fuente esperada en cada job. Paso 1 en `02cf8fe` y paso 3 en `ec18ce3`; G8 pendiente del run remoto. Ver *Enmiendas*, *D6*, *Estado*.)*
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

- La API pública de `ConfigReader`. `ConfigResolver` suma un solo método público (D3). *(D6, enmienda 2026-10-13: suma un segundo, `describeNetworkDestination`, y un tercero, estático, `describeHost(String)`: la regla única para nombrar una URL de configuración en un log o en un error (PI-09). Ver D6, *Dónde vive*.)*
- Los textos de los steps, las features, `config.properties`, el POM, la CI, el `Jenkinsfile` y el comando de CHK-10 (Regla 04 y tabla de CHK-10 del ADR-002). *(D6 cambia el argumento de CHK-19 en el job `e2e-grid`; el `Jenkinsfile` sigue igual.)*
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
  - El destino ya queda a la vista: el mensaje de error de `abrir` incluye la URL (ADR-002, D1). *(Enmienda 2026-10-13: solo su host, con `describeHost` (D6) y PI-09.)*
  - *(Enmienda 2026-10-13, D6: sigue sin aviso, pero cada destino deja una línea INFO con su fuente y su host, y CHK-19 exige la fuente esperada en cada job.)*
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
| 3 | `devops-engineer` | Gate. Es CRÍTICO: toca `src/main/java/com/demo/config/`. Incluye `-Dremote.url` contra el Grid local (`docker compose`) o el job `e2e-grid` en verde | APROBADO | Hecho (2026-10-13, sobre `2c33885` y `2671a20`; según el coordinador, la suite contra el Grid local con `-Dremote.url=http://localhost:4444` quedó en verde y sin el aviso de D3; *Enmiendas*) |
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
| R-2 | Un `-D` que llega desde el entorno (`MAVEN_ARGS`, `JAVA_TOOL_OPTIONS`, `JDK_JAVA_OPTIONS`) es deliberado, no un choque accidental de nombres | Documentación de Maven y del JDK. No se ejecutó (B-01) | Para los esperados, D3 lo deja en el log. **P2 (`devops-engineer`):** que los jobs E2E fallen si su log contiene el aviso de D3; exige `tee` en `test`, `e2e-firefox` y `e2e-grid`. Para los destinos no hay aviso (D5): es un riesgo residual aceptado. *(Para los destinos, lo aborda D6, enmienda 2026-10-13.)* **Cerrado:** implementado en `3be5956` (CHK-19), con el control real con Maven hecho en el gate de `3bab4b2` (*Enmiendas*, *R-2 implementado*) |
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
- **Pendiente:** el paso 3. Es el gate CRÍTICO de `devops-engineer`, con `-Dremote.url` contra el Grid. *(Hecho el 2026-10-13: enmienda siguiente.)*

### 2026-10-13 — Paso 3 (gate con `-Dremote.url` contra el Grid) y cierre

Las decisiones no cambian. Con este paso, el ADR queda **completamente implementado** (pasos 0 a 4).
- **Paso 3: Hecho.** Lo registra el coordinador. El 2026-10-13, la suite corrió contra el Grid local (`docker compose`) con `-Dremote.url=http://localhost:4444`.
  - Terminó en verde.
  - El log no contiene el aviso de D3 (`La clave de esperado`): un `-D` sobre un destino de red no avisa (D5).
  - Cubre la implementación de `2c33885` y la documentación de `2671a20`, los dos firmados (`git log --format='%h %G?'`). Los dos son anteriores a `5329cf1` en `main`.
- **La CI usa el mismo canal.** El job `e2e-grid`, paso *Run E2E (Selenium Grid, Chrome)*, pasa `-Dheadless=true -Dremote.url=http://localhost:4444`. El `Jenkinsfile` no usa `remote.url` (`git grep -n remote.url -- .github Jenkinsfile`).
- **Sin confirmar desde aquí:** el run remoto de `e2e-grid` sobre `5329cf1`. No hay `gh` ni red (B-01), así que lo confirma el usuario. No hace falta para cerrar el paso: su criterio admite el Grid local o el job `e2e-grid`.
- **Sigue abierto (P2):** R-2. Es de `devops-engineer`: que los jobs E2E fallen si su log contiene el aviso de D3. *(Implementado en `3be5956`: enmienda siguiente.)*

### 2026-10-13 — R-2 implementado (CHK-19)

Las decisiones no cambian: D3 sigue siendo un aviso en el log, y R-2 lo convierte en un fallo de la CI, como pedía su P2.
- **Implementación: `3be5956`** (`devops-engineer`, firmado; `git show --stat 3be5956`).
  - `scripts/check-no-expected-override.sh` lee el log de Maven de una ejecución E2E y falla si contiene el aviso de D3. Imprime el log, la línea y la clave, nunca el valor (D3).
  - Falla cerrado si el log falta, está vacío o no tiene la línea `Tests run:` de `RunnerTest` (Regla 04, CHK-19).
- **Dónde corre:**
  - En GitHub Actions, en el paso *Sin esperados sobrescritos por -D (ADR-003, R-2)*, después de Maven, en los jobs `test`, `e2e-firefox`, `e2e-grid` y `quarantine`.
  - En Jenkins, en las etapas `Test` y `Cuarentena (CHK-14)`, después de Maven. Según el *Estado actual* de la Regla 04, corre aunque Maven falle y sin tapar su rc.
  - La autoprueba (`scripts/tests/check-no-expected-override-test.sh`) corre en el paso *Esperados sobrescritos por -D, autoprueba (ADR-003, R-2)* del job `mutation` y en la etapa `Esperados por -D (ADR-003, R-2)` de Jenkins. Según devops, tiene 32 casos en verde y su sabotaje no deja vivo ninguno de 17 mutantes.
- **Va más allá de R-2:** R-2 pedía `test`, `e2e-firefox` y `e2e-grid`, y también se cubrieron el job `quarantine` y Jenkins.
- **Catálogo:** el usuario lo registró como **CHK-19** en la Regla 04 (`cc674a8`). En CHK-10 local el aviso es esperado, así que allí CHK-19 no aplica.
- **Control real con Maven: hecho** en el gate de devops sobre `3bab4b2`, según el coordinador. *(En `7d9477f` figuraba como pendiente.)*
  - **Con el `-D`:** equivale al comando de CHK-19 de la Regla 04 (con `tee` y `pipefail`), limitado al runner de Cucumber y a un AC:

    ```bash
    bash -c 'set -o pipefail; ./mvnw -B -ntp clean test -Dheadless=true -Dtest=RunnerTest -Dcucumber.filter.tags="@AC-LOGIN-01" -Dinventory.expected.title=__CONTROL_NEGATIVO__ 2>&1 | tee test.log'; bash scripts/check-no-expected-override.sh test.log
    ```

    Las propiedades `-Dtest`, `-Dcucumber.filter.tags` y `-Dinventory.expected.title` son las que informó el coordinador. El resto del comando está reconstruido a partir del de la Regla 04, no copiado del gate.
    - Maven dio rc 1 con `AssertionFailedError` en el `Then` (CHK-10).
    - CHK-19 dio rc 1 y nombró `inventory.expected.title`, sin el valor.
  - **Sin el `-D`:** el run de GitHub Actions sobre `3bab4b2` terminó en verde en sus 5 jobs (según el usuario). CHK-19 corre en cuatro de ellos (`test`, `e2e-firefox`, `e2e-grid` y `quarantine`), así que dio rc 0.
  - Con esto, **R-2 queda cerrado**.
- **Sin cambios:** los destinos de red siguen sin aviso (D5), y eso sigue siendo un riesgo residual aceptado de R-2. R-2 era el único P2 abierto de este ADR (enmienda anterior). *(Lo aborda D6, enmienda siguiente.)*
- Esta enmienda se escribió sin ejecutar nada (B-01): se comprobaron los nombres de los pasos, los jobs y las etapas con `git grep` sobre `cc674a8`, y los commits con `git show --stat`. Los resultados del control real son del gate y del usuario, no se ejecutaron aquí.

### 2026-10-13 — D6: fuente y host de los destinos de red, comprobados por job (CHK-19)

**Propuesta** del `qa-automation-architect` el 2026-10-13, a petición del coordinador (P1: el usuario pide cerrar todos los pendientes). La aprueba el coordinador (Regla 01, nivel 2). Suma una decisión, D6, y amplía CHK-19. D1 a D5 no cambian. Las citas son de `4b91990`.

*Hueco.*
- D5 deja los destinos de red sin aviso cuando gana `-D`: `-Dremote.url` es el uso normal del job `e2e-grid`, y PI-08 admite `-Dbase.url` en el comando.
- Dentro del JVM no se distingue un `-D` escrito en el comando de uno que llegó por `MAVEN_ARGS`, `JAVA_TOOL_OPTIONS`, `_JAVA_OPTIONS` o `JDK_JAVA_OPTIONS` (*Contexto*).
- Por eso, una variable de entorno de un agente puede llevar la suite a otro host, con las credenciales y la sesión, y el run queda en verde sin rastro. CHK-19 solo mira los esperados.
- **Hallazgo: CHK-19 tampoco es robusto para los esperados.** Exige la *ausencia* de un WARN, y el mismo canal puede quitarlo sin quitar la línea `Tests run` de `RunnerTest`, que escribe Maven y no el fork. El control G7 (gate de devops del paso 3, `ec18ce3`) lo confirma en dos formas y lo descarta en una. En cada una se sobrescribió un esperado con su mismo valor (`-Dinventory.expected.title=Products`):
  - **G7b, lo reproduce.** `-Dmaven.test.redirectTestOutputToFile=true`: Surefire manda la salida del fork a `target/surefire-reports`, así que el WARN no llega al log y `Tests run` sí. El script de `4b91990` da 0.
  - **G7c, lo reproduce.** El nivel `error` solo para el logger `com.demo.utils.ConfigReader` (propiedad `org.slf4j.simpleLogger.log.<logger>` de slf4j-simple) quita el WARN y deja el resto del log. El script de `4b91990` da 0.
  - **G7a, no lo reproduce.** `-Dorg.slf4j.simpleLogger.defaultLogLevel=error` también baja el nivel del slf4j-simple del propio Maven, y desaparece su línea INFO `Tests run … RunnerTest`. El script de `4b91990` ya daba 2: falla cerrado.
  - Con el script de D6, los tres dan 2, porque faltan las líneas de destino (presencia).

  *(Redacción corregida el 2026-10-13 con los resultados de G7. La propuesta decía, según la documentación y sin ejecutar nada (B-01), que el nivel general y la salida redirigida conservaban los dos la línea `Tests run`. Lo segundo es cierto, lo primero no. El nivel solo para `ConfigReader` no estaba en la lista.)*

*Decisión: la opción (a), con el host y con presencia obligatoria.*

| Opción | Veredicto | Motivo |
|---|---|---|
| (a) `ConfigReader` registra en INFO la fuente de cada destino, y CHK-19 exige la fuente esperada en cada job | **Elegida, ampliada** | Observa el efecto en el único punto donde convergen todos los canales: el JVM de las pruebas. No hay que enumerar canales (`MAVEN_ARGS`, `MAVEN_OPTS`, `.mvn/maven.config`, `.mvn/jvm.config`, las tres variables del JVM o uno futuro). No lee el entorno (P-02) ni mira otras propiedades, así que el `JAVA_TOOL_OPTIONS` legítimo de un agente de Jenkins no da falso positivo. Se amplía con el host validado y con la presencia obligatoria de las dos líneas (ver D6) |
| (b) Fallar si el log contiene `Picked up JAVA_TOOL_OPTIONS`, `Picked up _JAVA_OPTIONS` o `NOTE: Picked up JDK_JAVA_OPTIONS` | Descartada | Rechaza el canal, no el efecto: un agente con `JAVA_TOOL_OPTIONS` para memoria, codificación o certificados daría rojo sin tocar ningún destino. Además es incompleta: `MAVEN_ARGS`, `MAVEN_OPTS` y `.mvn/maven.config` no imprimen nada. Y la JVM escribe en esa línea el contenido completo de la variable, que puede llevar un secreto, así que el control tendría que citarla sin repetirla (PI-09). Lo único que (b) añadiría, detectar un canal que oculta el log, ya lo da la presencia de (a) |
| (c) Un paso de CI que valida que `MAVEN_ARGS` no contiene `-D` | Descartada | Mira un solo canal, y por texto: no ve `--define`, `-D clave=valor` separado, `MAVEN_OPTS`, `.mvn/maven.config` ni las variables del JVM. Habría que repetirlo en el `Jenkinsfile`, y leer la variable en un paso abre otra vía para imprimir su contenido (PI-09). Según el coordinador, hoy `setup-java` deja `MAVEN_ARGS` en `-ntp`, así que un control por igualdad se rompería con cualquier cambio de la acción |
| (a) con (b) o con (c) | Descartadas | Lo que suman sobre (a) ya lo cubre la presencia, y heredan los falsos positivos de (b) o la fragilidad de (c) |
| (d) Distinguir dentro del JVM un `-D` del comando de uno del entorno (`RuntimeMXBean.getInputArguments()`) | Descartada | Depende de cómo pasa Surefire las propiedades al fork (por su archivo de arranque, no por la línea de comandos del JVM), que puede cambiar entre versiones. Y no hace falta: con la expectativa declarada en cada job, el canal da igual |
| (e) Que los destinos dejen de aceptar `-D`, y el Grid se elija por archivo o por perfil | Descartada | Cambia D5, que decidió el usuario, el comando del Grid local (`AGENTS.md:20`) y PI-08. Es la alternativa "control negativo por otro canal" de este ADR, con otra clave |
| (f) Registrar solo la fuente, sin el host | Descartada | En `e2e-grid`, la fuente `sistema` es legítima, así que no distingue un `-D` inyectado que gane al del comando. El host sí, y además prueba que `e2e-grid` usó el Grid (prueba positiva): sin `-Dremote.url`, el job correría con el Chrome local y quedaría en verde |

*D6. Los destinos de red dejan su fuente y su host en el log, y CHK-19 exige la fuente esperada en cada job.*

- **Línea de destino.** Para cada clave que sea un destino de red (D5), `ConfigReader` registra una línea en INFO:
  - una vez por clave y por JVM, antes de resolverla;
  - con el mismo mecanismo que el aviso de D3 (`ConcurrentHashMap.newKeySet()`);
  - con este texto:

  ```text
  Destino de red '<clave>': fuente=<fuente>, host=<host>
  ```

  - `<fuente>` es `sistema` (cualquier propiedad del sistema: `-D`, `MAVEN_ARGS`, `JAVA_TOOL_OPTIONS`…), `entorno`, `archivo` o `ausente`.
    - Sale del mismo punto de precedencia que `resolve`, no de una copia.
    - Por D5, un destino nunca da `entorno`. Si una regresión lo produjera, CHK-19 lo rechaza.
  - `<host>` es `host[:puerto]` en minúsculas. Se obtiene del valor resuelto, sin espacios en los extremos (como `BrowserSettings`), analizado como `java.net.URI`.
    - Debe cumplir `HOST`. Si no lo cumple, si el URI no tiene host o si no se puede analizar, es `(invalido)`.
    - Un valor ausente o en blanco es `(ninguno)`. En `remote.url`, eso es la ejecución local.
  - **Nunca** lleva el esquema, el usuario ni la contraseña (`usuario:clave@`), la ruta, la consulta ni el fragmento. Una URL de Grid en la nube puede llevar su clave de acceso en el usuario o en la consulta (PI-09).
  - El host analizado es el destino real: con `http://localhost:4444@otro.example`, el host es `otro.example`.
  - Es ASCII, sin tildes, para que el control no dependa de la codificación (como CHK-19).

  ```text
  HOST  = [a-z0-9.-]{1,253}(:[0-9]{1,5})?
  LINEA = Destino de red '([A-Za-z0-9._-]{1,200})': fuente=(sistema|entorno|archivo|ausente), host=(HOST|\(ninguno\)|\(invalido\))$
  ```

  `(ninguno)` e `(invalido)` llevan paréntesis porque así no pueden ser un nombre de host: `http://ninguno/` da `host=ninguno`.
- **Host sí, valor no.** El host de una URL no es secreto, y es justo lo que decide adónde van las credenciales y la sesión. Se registra porque es lo único que distingue, en `e2e-grid`, un `-D` legítimo de uno inyectado (opción (f)). El resto de la URL no se registra.
- **Dónde vive.**
  - Componer la línea es lógica pura. Vive en `ConfigResolver` (`src/main`, con pruebas unitarias y PIT), que expone `Optional<String> describeNetworkDestination(String key)`:
    - devuelve vacío si la clave no es un destino (`NETWORK_DESTINATION_KEY`);
    - con `null`, lanza la NPE de siempre.
  - Es la capa más baja que puede absorberlo, porque ya tiene la expresión de D5 y las tres fuentes.
  - **`describeHost(String)` es `public static`** (decisión del coordinador, 2026-10-13, P2). Calcula `<host>` con la regla de arriba y es la **regla única** para nombrar una URL de configuración en un log o en un error (PI-09): ningún otro código compone su propia versión. Lo usan `describeNetworkDestination`, `BrowserErrorPage.describe` y `BrowserSettings.toUrl` (`src/main`), y `Navegador.abrir`, `Navegador.esperarUrlContiene` y `DriverFactory` (`transport`, que ya puede nombrar `config`: D4 del ADR-002). Los mensajes del transporte que cambian están en el ADR-002, D1 (enmienda 2026-10-13, parte 6). Aplicado en `02cf8fe`.
  - `ConfigReader` solo registra la línea. Como en D3, nunca registra el valor.
  - `java.net.URI` no hace E/S, así que CHK-15 no cambia.
- **Control: se amplía CHK-19.** `scripts/check-no-expected-override.sh` lee el mismo log, en los mismos pasos y etapas, y además comprueba:
  1. **Validez.** Cada línea que contiene la marca `Destino de red '` debe cumplir `LINEA` desde la marca hasta el final, después de quitar un `\r` final. Si no, es una violación (1), y se informa sin repetir el contenido.
  2. **Fuente esperada en el job.**
     - Sin bandera, cada destino debe tener `fuente=archivo` o `fuente=ausente`. Un destino ausente no puede llevar la suite a ningún sitio.
     - Con `--destino-d <clave>=<host>`, esa clave debe tener `fuente=sistema` y exactamente ese host. Las demás claves siguen la regla sin bandera.
     - Deben cumplir todas las líneas de una clave, no solo la primera: con más de un fork hay más de una.
  3. **Presencia.** El log debe tener al menos una línea válida de `base.url` y otra de `remote.url`. Si falta alguna, no se puede evaluar el destino (2).
  4. **Orden**, como hoy: primero las violaciones (el aviso de D3 y las de los destinos, 1), después la línea `Tests run` de `RunnerTest` (2) y al final la presencia de los destinos (2). Así, los casos vigentes sin `Tests run` conservan su mensaje.
- **Por qué la presencia.** Falla cerrado, y además cierra el hallazgo de *Hueco*. Cualquier canal que oculte el log de las pruebas también quita las dos líneas, y CHK-19 da 2:
  - un nivel de slf4j-simple por encima de INFO, general o solo para `ConfigReader`;
  - su `logFile`;
  - la salida del fork redirigida a un archivo.

  Por eso la línea va en INFO, el nivel por defecto de slf4j-simple. Un WARN sobreviviría a un nivel `warn`, y el hueco seguiría abierto para los avisos de D3.
- **Expectativa en cada job.** Está versionada en el comando de cada paso:

  | Dónde | Comando de CHK-19 | `base.url` | `remote.url` |
  |---|---|---|---|
  | Jobs `test`, `e2e-firefox` y `quarantine`, y etapas `Test` y `Cuarentena (CHK-14)` del `Jenkinsfile` | Sin cambios: `bash scripts/check-no-expected-override.sh <log>` | `archivo` o `ausente` | `archivo` o `ausente` |
  | Job `e2e-grid` | `bash scripts/check-no-expected-override.sh --destino-d remote.url=localhost:4444 e2e-grid.log` | `archivo` o `ausente` | `sistema`, con host `localhost:4444` |

  - La bandera está en el mismo job que el `-Dremote.url=http://localhost:4444` de Maven (paso *Run E2E (Selenium Grid, Chrome)*). Un `-D` legítimo nuevo sobre un destino exige su bandera en el mismo cambio.
  - Los pasos y las etapas conservan su nombre (*Sin esperados sobrescritos por -D (ADR-003, R-2)*), porque los citan este ADR, la Regla 04 y el `README.md`.
- **Mensajes del control.** Los compara la autoprueba:
  - **violación:** `<log>:<línea>: D6: el destino de red '<clave>' tiene fuente=<fuente> y host=<host>; en este job se espera <esperado> (ADR-003, D6)`. `<esperado>` es `fuente=archivo o ausente`, o `fuente=sistema y host=<host de la bandera>`;
  - **línea no válida:** `<log>:<línea>: D6: línea de destino de red no válida (ADR-003, D6)`, sin el contenido;
  - **ausencia:** `check-no-expected-override: el log '<log>' no registra el destino de red '<clave>' (ADR-003, D6): no prueba adónde fue la suite`. Es una línea por clave, primero `base.url`;
  - **uso:** `check-no-expected-override: uso: bash scripts/check-no-expected-override.sh [--destino-d <clave>=<host>]... <log de Maven>`. Las banderas van antes del log. En cada una, la clave cumple `[A-Za-z0-9._-]{1,200}` y el host cumple `HOST` (sin `(ninguno)` ni `(invalido)`), y cada clave aparece una sola vez. Si no, da 2;
  - **éxito:** `check-no-expected-override: ok: sin esperados sobrescritos por -D y con los destinos de red esperados en '<log>' (ADR-003, R-2 y D6)`.
- **Falsos positivos.** No se esperan:
  - En Jenkins: no pasa `base.url` ni `remote.url` por `-D`, y un `JAVA_TOOL_OPTIONS` del agente con otras propiedades no cambia ninguna línea.
  - En local: CHK-19 no forma parte de CHK-08 ni de CHK-10 (Regla 04). Con el Grid local, quien ejecute CHK-19 pasa la misma bandera que `e2e-grid`.
  - En CHK-10: sobrescribe esperados, nunca destinos.
- **Lo que no cambia:** D1 a D5, la API pública de `ConfigReader`, el comando de CHK-10, el `Jenkinsfile`, los nombres de los pasos y las etapas, y el aviso de D3 con su texto.

*Supuestos* (no se ejecutó nada aquí, B-01):

| # | Supuesto | Lo confirma | Si es falso |
|---|---|---|---|
| S-1 | El INFO de `ConfigReader` en el fork llega al log de Maven por el mismo camino que el WARN de D3 | El control real de R-2 (gate de `3bab4b2`): CHK-19 nombró la clave a partir de ese WARN. Mismo logger y mismo flujo | CHK-19 da 2 en todos los jobs (falla cerrado). Se revisa el destino de slf4j-simple |
| S-2 | `MAVEN_ARGS`, `JAVA_TOOL_OPTIONS`, `JDK_JAVA_OPTIONS` y `_JAVA_OPTIONS` llegan al fork como propiedades del sistema | Documentación de Maven 3.9 y del JDK. Lo demuestran por primera vez los controles G3 a G5 | Si un canal no llega al fork, no puede cambiar el destino. G3 a G5 lo dejan escrito |
| S-3 | Un nivel de log o una salida redirigida ocultan hoy el aviso de D3 sin quitar `Tests run` (*Hueco*) | Control G7, con el script de `4b91990` y con el nuevo. **Confirmado en parte** (`ec18ce3`): lo reproducen G7b (salida del fork redirigida) y G7c (nivel `error` solo para `ConfigReader`), con el script de `4b91990` en 0 y el nuevo en 2. G7a (nivel general `error`) no lo reproduce: también quita la línea `Tests run` de Maven, y el script de `4b91990` ya daba 2 | Si no lo ocultan, el hallazgo era falso, pero la presencia sigue siendo necesaria para fallar cerrado. *(No aplica: el hallazgo se confirmó con G7b y G7c, y D6 no cambia.)* |

*Riesgo residual aceptado:*
- Un cambio versionado de la bandera, de `config.properties` o del código. Lo ve la revisión (Regla 02, *Límite honesto*).
- La ruta de red, que no es el destino declarado: los proxies del JVM (`https.proxyHost`) o del sistema (`HTTPS_PROXY`) y la resolución de nombres. D6 registra adónde se pide ir, no por dónde pasa el tráfico. Ninguna de las opciones (a) a (c) lo vería.
- Un nivel de log por encima de INFO puesto a propósito y versionado (por ejemplo, con un `simplelogger.properties`). CHK-19 da 2 y hay que enmendar D6. Es un falso positivo que falla cerrado.

*P2 relacionado, fuera de D6 (`qa-automation-engineer`):* `BrowserSettings.toUrl` compone su error con la `remote.url` completa (`'%s'`). Con una URL de Grid que llevara la clave en el usuario y fuera inválida, el mensaje la imprimiría (PI-09). Hoy ninguna URL lleva usuario, así que no se explota. Se podría usar la misma descripción del host. *(Cerrado en `02cf8fe`: `toUrl` usa `describeHost`. Ver D6, *Dónde vive*.)*

*Migración* (cada paso deja la suite en verde):

| Paso | Dueño | Qué | Verde si |
|---|---|---|---|
| 0 | Coordinador | Aprueba esta enmienda | — |
| 1 | `qa-automation-engineer` (gate CRÍTICO: toca `src/main/java/com/demo/config/`) | Primero las pruebas n1 a n12 en `ConfigResolverTest`. Después `describeNetworkDestination` en `ConfigResolver` y el registro en `ConfigReader` | *Verificación del paso 1* |
| 2 | `qa-test-verifier` | La verificación del paso 1, más PIT y n7 (PI-09) | APROBADO |
| 3 | `devops-engineer` (gate), **después** del paso 1 en `main` | El script, su autoprueba y el argumento de `e2e-grid`, en un solo commit. Antes del paso 1, el control daría 2 en todos los jobs E2E, porque el log aún no tendría líneas de destino | *Autoprueba del control*, *Mutantes del control* y *Controles con Maven* |
| 4 | Usuario | Los textos de la Regla 04; el `README.md` y `AGENTS.md`, quien designe el usuario (*Textos*) | — |

*Contrato para el engineer (paso 1):*
- **`ConfigResolver`:**
  - `describeNetworkDestination(key)` toma la fuente del mismo punto de precedencia que `resolve`. Por ejemplo, un `resolveWithSource` privado, del que `resolve` toma el valor; así no hay una segunda copia de la precedencia.
  - Valida el host con el mismo `HOST` que el control.
  - El Javadoc de la clase cita D6.
- **`ConfigReader`:**
  - Suma un conjunto `DESTINOS_REGISTRADOS` (`ConcurrentHashMap.newKeySet()`), declarado antes de `RESOLVER`, como `ESPERADOS_AVISADOS`.
  - En cada getter, junto al aviso de D3, registra la línea con `LOGGER.info("{}", linea)` la primera vez para esa clave. La línea va como argumento, nunca como formato.
- **TDD:** con un esqueleto que solo valida `null` y devuelve `Optional.empty()`, fallan todas las pruebas nuevas salvo n9 y n10. Se adjunta la salida.

*Pruebas unitarias (`ConfigResolverTest`)*, con valores concretos:
- n1. `base.url=https://www.saucedemo.com`, solo en el archivo → `Destino de red 'base.url': fuente=archivo, host=www.saucedemo.com`.
- n2. `remote.url=` vacío en el archivo → `Destino de red 'remote.url': fuente=archivo, host=(ninguno)`.
- n3. `remote.url=http://localhost:4444` en el sistema y `""` en el archivo → `…: fuente=sistema, host=localhost:4444`.
- n4. `remote.url=" "` en el sistema → `…: fuente=sistema, host=(ninguno)`. El blanco del sistema gana (D2).
- n5. En el entorno, `REMOTE_URL=http://localhost:9` y `remote.url=http://localhost:9`, con el archivo vacío → `…: fuente=archivo, host=(ninguno)`. El entorno no es fuente (D5).
- n6. `grid-url`, que no está en ninguna fuente → `Destino de red 'grid-url': fuente=ausente, host=(ninguno)`.
- n7. En el sistema, `https://usuario:clave@Hub.Example.COM:443/wd/hub?token=secreto#frag` → exactamente `…: fuente=sistema, host=hub.example.com:443`. La línea no contiene `usuario`, `clave`, `secreto`, `wd`, `frag` ni `https` (PI-09).
- n8. Dan `host=(invalido)`:
  - `localhost:4444`, sin esquema: `URI` lo lee como el esquema `localhost`;
  - `http://[::1]:4444`;
  - `http://mi_host:4444`;
  - `http://exa mple.com`, que lanza `URISyntaxException`;
  - `file:///tmp/x`;
  - `http://h:123456`, porque un puerto de seis cifras no cumple `HOST`.
- n9. `headless`, `inventory.expected.title` y `a.url.b` → `Optional.empty()`.
- n10. `null` → NPE con `La clave de configuración no puede ser null`.
- n11. `a.Base.URL` con `http://x.example` en el archivo → `Destino de red 'a.Base.URL': fuente=archivo, host=x.example`. La clave se registra tal como llega.
- n12. En el sistema, `"  http://localhost:4444  "` → `host=localhost:4444`, porque se quitan los espacios; y `http://localhost:4444@otro.example` → `host=otro.example`.

*Verificación del paso 1:*
- CHK-07, CHK-15, CHK-16 y CHK-17.
- CHK-08 ×2, con `Tests run` igual al anterior más las pruebas nuevas. Su log contiene exactamente una línea `Destino de red 'base.url': fuente=archivo, host=www.saucedemo.com` y una `Destino de red 'remote.url': fuente=archivo, host=(ninguno)`, y no contiene el aviso de D3.
- CHK-11 ≥ 80 %, con la guarda en 0. Cada mutante nuevo de `ConfigResolver`, muerto o justificado.
- Con el Grid local y `-Dremote.url=http://localhost:4444`, el log tiene `fuente=sistema, host=localhost:4444`.
- El CHK-19 de `4b91990` sigue en 0 sobre el log de CHK-08, porque ignora las líneas nuevas: este paso no rompe la CI.

*Autoprueba del control* (`scripts/tests/check-no-expected-override-test.sh`, devops).
- **Pieza de log nueva**, con el formato de slf4j-simple:

  ```text
  [ForkJoinPool-1-worker-1] INFO com.demo.utils.ConfigReader - Destino de red '<clave>': fuente=<fuente>, host=<host>
  ```

  `base_ok` es `base.url` con `archivo` y `www.saucedemo.com`; `remote_ok`, `remote.url` con `archivo` y `(ninguno)`; `remote_grid`, `remote.url` con `sistema` y `localhost:4444`.
- **Casos vigentes que cambian:**
  - `verde sin aviso`, `escenario en rojo sin aviso`, `verde sin aviso con CRLF` y `casi-coincidencias del mensaje (sin -D)` suman `base_ok` y `remote_ok`, y esperan el nuevo mensaje de éxito. Sin esas líneas darían 2.
  - `sin argumentos` y `argumentos de más` esperan el nuevo mensaje de uso.
  - El resto de los 32 no cambia.
- **Casos nuevos.** Sin bandera salvo que se indique:

  | Caso | Log | rc | Comprueba |
  |---|---|---|---|
  | `D6-ok-ausente` | `base_ok` y `remote.url` con `ausente` y `(ninguno)` | 0 | `ausente` está permitido |
  | `D6-ok-grid` | `base_ok` y `remote_grid`, con `--destino-d remote.url=localhost:4444` | 0 | la expectativa de `e2e-grid` |
  | `D6-ok-jenkins` | `base_ok` y `remote_ok` con el prefijo `12:01:02  ` | 0 | marca sin ancla de inicio |
  | `D6-ok-dos-jvm` | `base_ok` y `remote_ok`, dos veces cada una | 0 | varias líneas por clave |
  | `D6-ok-casi` | `base_ok`, `remote_ok` y dos casi-marcas con `fuente=sistema`: sin comilla (`Destino de red base.url:`) y en minúscula (`destino de red 'base.url'`) | 0 | la marca es exacta y distingue mayúsculas |
  | `D6-ok-nul` | un byte NUL antes de `base_ok` y `remote_ok` | 0 | la búsqueda nueva usa `grep -a` |
  | `D6-base-sistema` | `base.url` con `sistema` y `www.saucedemo.com`, y `remote_ok` | 1 | la línea de violación de `base.url` |
  | `D6-remote-sistema` | `base_ok` y `remote_grid`, sin bandera | 1 | `-D` sin bandera |
  | `D6-entorno` | `base_ok` y `remote.url` con `entorno` y `(ninguno)` | 1 | `entorno` nunca se acepta |
  | `D6-grid-host` | `base_ok` y `remote.url` con `sistema` y `otro.example:4444`, con la bandera de `e2e-grid` | 1 | el host se compara |
  | `D6-grid-prefijo` | igual, con `localhost:44445` | 1 | comparación exacta, no por prefijo |
  | `D6-grid-archivo` | `base_ok` y `remote_ok`, con la bandera | 1 | `e2e-grid` sin Grid es rojo |
  | `D6-grid-base` | `base.url` con `sistema` y `www.saucedemo.com`, y `remote_grid`, con la bandera | 1 | la bandera vale solo para su clave |
  | `D6-mixta` | `base_ok`, `remote_ok` y otra línea de `base.url` con `sistema` y `otro.example` | 1 | se evalúan todas las líneas (violación en la tercera) |
  | `D6-no-valida-fuente` | `base_ok`, `remote_ok` y `Destino de red 'base.url': fuente=desconocida, host=x.example` | 1, más `absent` de `desconocida` | `LINEA` estricta, sin repetir el contenido |
  | `D6-no-valida-secreto` | `base_ok`, `remote_ok` y `Destino de red 'remote.url': fuente=sistema, host=usuario:clave@hub.example` | 1, más `absent` de `clave` | PI-09 |
  | `D6-no-valida-inyeccion` | `base_ok`, `remote_ok` y `Destino de red 'x$(touch PWNED)': fuente=archivo, host=x.example` | 1, más `absent` de `PWNED` | PI-04 |
  | `D6-no-valida-sufijo` | `base_ok`, `remote_ok` y `base.url` con `archivo` y `www.saucedemo.com extra` | 1 | ancla final |
  | `D6-y-D3` | el aviso de D3, `base.url` con `sistema` y `remote_ok` | 1, con dos `expect` (las dos líneas) | se informan juntos |
  | `D6-sin-tests` | `base.url` con `sistema`, `remote_ok` y sin `Tests run` | 1 | las violaciones van antes que la evaluabilidad |
  | `D6-sin-base` | solo `remote_ok` | 2 | mensaje de ausencia de `base.url` |
  | `D6-sin-remote` | solo `base_ok` | 2 | mensaje de ausencia de `remote.url` |
  | `D6-sin-destinos` | ninguna línea de destino (nivel de log o salida redirigida) | 2 | mensaje de ausencia de `base.url` |
  | `D6-error-grep` | `verde` con las dos líneas, y un shim de `grep` que sale con 2 solo si un argumento contiene `Destino de red` (y si no, delega en el real) | 2 | la búsqueda nueva pasa por `grep_log` |
  | `D6-uso-sin-valor` | `--destino-d` sin valor | 2 | mensaje de uso |
  | `D6-uso-sin-igual` | `--destino-d remote.url` | 2 | mensaje de uso |
  | `D6-uso-host` | `--destino-d 'remote.url=localhost:4444;x'` | 2 | mensaje de uso |
  | `D6-uso-token` | `--destino-d 'remote.url=(ninguno)'` | 2 | mensaje de uso |
  | `D6-uso-repetida` | `--destino-d remote.url=localhost:4444 --destino-d remote.url=localhost:4445` | 2 | mensaje de uso |
  | `D6-uso-otra` | `--otra` | 2 | mensaje de uso |
  | `D6-uso-despues` | `<log> --destino-d remote.url=localhost:4444` | 2 | mensaje de uso |

  Son 31 casos y 35 registros (`D6-y-D3` tiene dos `expect`, y tres casos suman un `absent`). La autoprueba pasa de 32 a 67 registros.

*Mutantes del control* (sabotaje de devops). Ninguno debe sobrevivir:

| Mutante | Casos que lo matan |
|---|---|
| C1. Sin la presencia | `D6-sin-base`, `D6-sin-remote` y `D6-sin-destinos` |
| C2. Presencia solo de `base.url` | `D6-sin-remote` |
| C3. Acepta `sistema` sin bandera | `D6-base-sistema` y `D6-remote-sistema` |
| C4. Acepta `entorno` | `D6-entorno` |
| C5. Rechaza `ausente` | `D6-ok-ausente` |
| C6. Con bandera, no compara el host | `D6-grid-host` |
| C7. Compara el host por prefijo | `D6-grid-prefijo` |
| C8. Con bandera, acepta `archivo` | `D6-grid-archivo` |
| C9. La bandera vale para todas las claves | `D6-grid-base` |
| C10. Solo evalúa la primera línea de cada clave | `D6-mixta` |
| C11. Sin el `$` final de `LINEA` | `D6-no-valida-sufijo` |
| C12. No quita el `\r` final | `verde sin aviso con CRLF` (da 1) |
| C13. Marca anclada al inicio de la línea | `verde sin aviso` (da 2) |
| C14. Marca sin la comilla o sin distinguir mayúsculas | `D6-ok-casi` |
| C15. Una línea no válida repite su contenido | `D6-no-valida-fuente`, `-secreto` e `-inyeccion` |
| C16. La presencia se evalúa antes que `Tests run` | `sin Tests run (fallo de compilación)` y los otros casos vigentes sin `Tests run` (cambia el mensaje) |
| C17. Las violaciones de D6 se evalúan después de la evaluabilidad | `D6-sin-tests` (da 2) |
| C18. La bandera acepta un host fuera de `HOST` o un token | `D6-uso-host` y `D6-uso-token` |
| C19. La bandera repetida se acepta | `D6-uso-repetida` |
| C20. La búsqueda nueva no usa `-a` | `D6-ok-nul` |
| C21. La búsqueda nueva no pasa por `grep_log` | `D6-error-grep` |

*Controles con Maven* (gate de devops, paso 3). Solo usan SauceDemo, `localhost` o un puerto local cerrado (P-07). Fijan, para un solo proceso de Maven, variables con valores que no son secretos; no leen ni imprimen el entorno (P-02, PI-09):

| # | Comando (sobre la suite o un AC, con `tee` y `pipefail`) | Esperado |
|---|---|---|
| G1 | Autoprueba del control | 67 registros en verde |
| G2 | CHK-19 sobre un run normal | 0 |
| G3 | `-Dbase.url=https://www.saucedemo.com` (el mismo valor del archivo: no sale tráfico a otro host) | Maven en verde y CHK-19 con 1, que nombra `base.url` con `fuente=sistema`. Con el script de `4b91990`, el mismo log da 0: esa diferencia es la evidencia |
| G4 | `MAVEN_ARGS='-Dbase.url=https://www.saucedemo.com'` | 1 |
| G5 | `JAVA_TOOL_OPTIONS`, `JDK_JAVA_OPTIONS` y `_JAVA_OPTIONS`, cada uno por separado, con `-Dbase.url=https://www.saucedemo.com` | 1 en los tres |
| G6 | Grid local con `-Dremote.url=http://localhost:4444`: con `--destino-d remote.url=localhost:4444`; sin la bandera; con `--destino-d remote.url=localhost:4445` | 0, 1 y 1 |
| G7 | `-Dinventory.expected.title=Products` (el valor del archivo) con `-Dorg.slf4j.simpleLogger.defaultLogLevel=error`; y aparte, con `-Dmaven.test.redirectTestOutputToFile=true` | Maven en verde. El script de `4b91990` da 0 (el hueco); el nuevo, 2 (sin líneas de destino) |
| G8 | Run de GitHub Actions con los cinco jobs que corren CHK-19 o su autoprueba | En verde (según el usuario) |

Si G7 no reproduce el hueco (el script de `4b91990` da 1 o 2), se informa al arquitecto: el hallazgo de *Hueco* era falso, pero D6 no cambia (S-3). *(Resultado en `ec18ce3`: G7a no lo reproduce y G7b y G7c sí; ver *Hueco*, S-3 y *Estado*.)*

*Textos* (usuario, P-01; `README.md` y `AGENTS.md`, quien designe el usuario):
- `.claude/rules/04-quality-checks.md`, fila CHK-19:

  ```markdown
  | CHK-19 | Ningún valor esperado sobrescrito por `-D` en una ejecución E2E (ADR-003, R-2), y cada destino de red con la fuente esperada en su job (ADR-003, D6): el log de Maven no contiene el aviso de D3 de `ConfigReader` (p. ej. un `-D` inyectado con `MAVEN_ARGS`), y registra `base.url` y `remote.url` con `fuente=archivo` o `ausente`, salvo el destino que el job declara con `--destino-d <clave>=<host>` (en `e2e-grid`, `remote.url=localhost:4444`), que llega por `-D` con ese host; falla cerrado si el log falta, está vacío, no tiene la línea `Tests run:` de `RunnerTest` o no registra uno de los dos destinos | Exit 0 en el control y en su autoprueba; con exit 1 imprime `log:línea` y la clave (en D6, también la fuente y el host validados), nunca el valor. En CHK-10 local el aviso es esperado: allí CHK-19 no aplica | devops |
  ```

- La misma regla, comentario del bloque de comandos:

  ```bash
  # CHK-19 (ADR-003, R-2 y D6): autoprueba y control sobre el log de una ejecución E2E (el log, con tee y pipefail; contra el Grid, con --destino-d remote.url=localhost:4444 antes del log)
  ```

- La misma regla, al final de la frase de CHK-19 en *Estado actual*: "Desde la enmienda D6 del ADR-003 también exige la fuente de `base.url` y `remote.url` en cada job; `e2e-grid` pasa `--destino-d remote.url=localhost:4444`."
- `README.md:185`, columna central: "Una ejecución E2E en verde contra un valor esperado inyectado por `-D` (por ejemplo desde `MAVEN_ARGS`), o contra un destino (`base.url`, `remote.url`) que no viene de donde dice el job: si el log trae el aviso de `ConfigReader`, o una línea de destino con otra fuente u otro host, o le falta alguna, el job falla (ADR-003, R-2 y D6)".
- `README.md:484` y `:486`: "control de esperados y destinos por -D" en lugar de "control de esperados por -D", y "que no trae esperados sobrescritos por -D ni destinos de otra fuente" en lugar de "que no trae esperados sobrescritos por -D".
- `AGENTS.md:38`: "(CHK-19, ADR-003 R-2 y D6)" en lugar de "(CHK-19, ADR-003 R-2)".

*Comprobación sobre `4b91990`* (solo `git grep`, B-01; `src`, `scripts` y `.github` sin cambios sin commit):
- `git grep -n -e 'base\.url' -e 'remote\.url' HEAD -- src/test/java ':!src/test/java/com/demo/config' .github Jenkinsfile` (sin las unitarias de `config`, que usan las claves como datos):
  - leen las claves `LoginPage.java:24`, `InventoryPage.java:36` y `DriverFactory.java:22`;
  - solo `ci.yml:236` (job `e2e-grid`) pasa una por `-D`; `:228` es su comentario;
  - el `Jenkinsfile` no las nombra.

  Por eso la tabla de expectativas lleva una sola bandera.
- `git grep -n -F "Destino de red '" HEAD -- src scripts .github Jenkinsfile`: sin salida (rc=1). La marca, con su comilla, no choca con ningún texto vigente. Sin la comilla aparece en el Javadoc de `NETWORK_DESTINATION_KEY` (`ConfigResolver.java:28`), que no llega al log.
- `git grep -n -F 'Sin esperados sobrescritos por -D (ADR-003, R-2)' HEAD -- .github/workflows/ci.yml`: `:95`, `:161`, `:242` y `:434`, en los jobs `test`, `e2e-firefox`, `e2e-grid` y `quarantine`. Las etapas `Test` y `Cuarentena (CHK-14)` del `Jenkinsfile` llaman al control con un solo argumento, el log.

*Estado (2026-10-13; según el coordinador y los mensajes de los commits, no se ejecutó aquí, B-01):*
- **Paso 0:** aprobada por el coordinador.
- **Paso 1: hecho en `02cf8fe`** (`qa-automation-engineer`). Incluye `describeHost` como `public static` y los mensajes del transporte solo con el host (D6, *Dónde vive*; ADR-002, D1, parte 6).
- **Paso 3: hecho en `ec18ce3`** (`devops-engineer`): el script, su autoprueba y `--destino-d remote.url=localhost:4444` en `e2e-grid`. Resultados de los controles:
  - G1: 67 casos en la autoprueba, todos en verde;
  - sabotaje C1–C21 (22 mutantes, con C14a y C14b): ninguno vivo;
  - G2: 0;
  - G3, G4 y G5: 1 con el script nuevo y 0 con el de `4b91990`;
  - G6: 0, 1 y 1;
  - G7: G7b y G7c dan 0 con el script de `4b91990` y 2 con el nuevo; G7a da 2 con los dos (*Hueco* y S-3).
- **G8: pendiente** del run remoto de GitHub Actions (lo confirma el usuario).
- **Paso 4** (textos de la Regla 04, `README.md` y `AGENTS.md`): lo registra el coordinador cuando se apliquen.
