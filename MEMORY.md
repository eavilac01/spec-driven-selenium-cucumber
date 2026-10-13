# MEMORY.md — spec-driven-selenium-cucumber

Memoria del proyecto entre sesiones. Máximo ~50 líneas: resume o elimina lo que ya no aporte.

## Estado actual
- Suite 189 en verde (local, `not @quarantine`, 1 omitido = AC-COMPRA-09): 21 E2E (22 AC) + 168 unitarias; PIT 132/132. CI de `950d6de` en verde (confirmado por el usuario, 2026-10-13).
- Listo para publicar: auditoría de los 87 commits sin secretos ni datos personales (sin reescribir historia); `SECURITY.md`, `CONTRIBUTING.md` y plantillas de issue y PR.
- Specs `login.md` y `compra.md` aprobadas, con todos sus AC verificables cubiertos y CHK-10 demostrado. AC-COMPRA-09 en cuarentena `defecto-sut`.
- `Navegador`: un solo clic y una sola escritura nativos por acción, sin respaldo JS (ADR-002 D1, `d569a34`); solo dos scripts de una lista cerrada (`0a3b6fb`); timeout con la pista de D8; `abrir` falla al instante ante `net::ERR_*`.
- Causa de los clics perdidos: el aviso de contraseñas filtradas de Chrome tras el login (invisible en headless) descarta la entrada nativa; `BrowserSettings.chromePreferences()` lo desactiva (D8, `3bab4b2`).
- ADR-001, ADR-002 (CHK-17: firmas expuestas, Selenium en el transporte, herencia, clic nativo único, scripts cerrados y presencia de la preferencia de Chrome; autoprueba de 414 casos, 66 mutantes muertos) y ADR-003 (R-2 cerrado) completos.
- CHK-01…19 activas. CHK-18: portabilidad de awk (matriz mawk/gawk/`gawk --posix` en CI). CHK-19: el log E2E sin esperados sobrescritos por `-D`.
- Hooks: gate DevOps y protección frente a escrituras por Bash en `.claude/**`, `CLAUDE.md`, `MEMORY.md`, `AGENTS.md` y `.github/**` (75 casos).
- CI con 6 jobs (`test`, `e2e-firefox`, `e2e-grid`, `mutation`, `quarantine`, `fork-pr-notice`), 2 hilos, versión del navegador en el log. En PR de forks se omiten los E2E con aviso; `persist-credentials: false`, `concurrency` y artefactos de 14 días sin logs de Maven. Jenkinsfile sin servidor real (R-4).

## Decisiones (y por qué)
- El coordinador es la sesión principal, porque un subagente no puede delegar en otros.
- PIT solo sobre la lógica pura; los E2E se validan con control negativo (`-D…`), porque un SUT externo no se puede mutar.
- El verifier no tiene `memory`: activarla le agrega `Write`/`Edit` y rompe su independencia.
- Solo el usuario aprueba specs (SDD-09) y cambia `.claude/**`, `CLAUDE.md`, `AGENTS.md`; los ADR los aprueba el coordinador.
- Los `Then` comparan contra claves `*.expected*` independientes de la entrada; solo aceptan `-D` y `config.properties` (ADR-003).
- Sin respaldo JS: un clic por JS se salta el hit-testing del navegador y ocultó la causa real (verde falso).
- Un `inestable` con error deja el job `quarantine` en verde con aviso; un `defecto-sut` con error, en rojo.
- Naming de Cucumber en `short`: `long` rompe el evaluador de cuarentena.
- Mantener `MEMORY.md`, `AGENTS.md` y `README.md` al día en cada tanda, sin faltar nada (el usuario).

## Aprendizajes y errores a evitar
- Commits sin `Co-Authored-By` ni marcas de IA; firmados con SSH (`%G?` = `G`). Gate JSON y push en comandos separados.
- Sin `Grep`/`Glob`: `git grep`/`git ls-files`. Nunca `git grep --no-index`/`--untracked` en la raíz: abre `.env`.
- El runner de GitHub usa gawk y Ubuntu de escritorio mawk: `RT` es reservado en gawk y `gawk --posix` rechaza un parámetro con nombre de función. Probar con `run-with-each-awk.sh` (gawk instalado en local).
- Los workflows se editan solo con `Edit`/`Write`: un `python3` por Bash esquivó el `ask` (ya lo bloquea el hook).
- "Con la máquina cargada Chrome pierde clics" era falso: dependía de si el servicio de Google respondía 200 o 429.
- Un "no pasa X" verificado solo por ausencia da verde falso: exigir prueba positiva. Ojo: un clic perdido también "no avanza" en AC-COMPRA-09; antes de sacarlo de cuarentena, revisar el log (pista de D8).
- PIT sin `target/classes` da `BUILD SUCCESS` sin mutar: exigir `mutations.xml`. PIT no muta literales ni regex: control negativo manual.
- `if script | grep -q` con `pipefail` no falla si el script sale con rc ≠ 0: capturar la salida antes.
- No correr dos Maven a la vez. Firefox local (snap) necesita `-Dwebdriver.gecko.driver=/snap/bin/geckodriver`.
- No existe la CLI `gh`: las operaciones de GitHub las hace el usuario en la web.

## Próximos pasos
1. Usuario: confirmar el CI de la tanda de publicación (6 jobs; duración de `mutation` con 414 casos) y aplicar en GitHub los ajustes de publicación (Actions, protección de `main`, secret scanning, alertas de Dependabot) antes de cambiar la visibilidad.
2. P2: checksum del Maven Wrapper (`distributionSha256Sum`): falta elegir la fuente del hash (el zip no está en local; exige red y la decisión del usuario).
3. P2: la pista de D8 en el clic de tramitar no se observó en vivo (10 intentos con el servicio en 429); cubierta por construcción.
4. P2: R-4 (Jenkins sin servidor); un `-D` sobre `base.url`/`remote.url` por `JAVA_TOOL_OPTIONS`/`MAVEN_ARGS` no deja aviso (CHK-19 solo cubre esperados); acciones fijadas por versión, no por SHA.
