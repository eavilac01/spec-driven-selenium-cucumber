# MEMORY.md — spec-driven-selenium-cucumber

Memoria del proyecto entre sesiones. Máximo ~50 líneas: resume o elimina lo que ya no aporte.

## Estado actual
- Suite 186 en verde (local, `not @quarantine`, 1 omitido = AC-COMPRA-09): 21 E2E (22 AC) + 165 unitarias; PIT 129/129. Subido en `5329cf1` (2026-10-13).
- Specs `docs/specs/login.md` y `compra.md` aprobadas, con todos sus AC verificables cubiertos y CHK-10 demostrado en cada uno.
- AC-COMPRA-09 en cuarentena `defecto-sut`; acepta "no se puede tramitar" solo con el botón presente y deshabilitado u oculto; si no existe, error.
- Job `quarantine`: `defecto-sut` que falla por aserción = verde; `inestable` con error = verde con aviso (decisión del usuario); errores reales e infraestructura = rojo.
- `Navegador`: `abrir` falla al instante ante `net::ERR_*`; tope de 3 clics por acción (1 nativo + 2 JS, con log INFO); `contarEstable`/`esVisibleEstable` (2 sondeos); `existeEnTiempoMaximo`.
- ADR-001 (PIT) y ADR-002 (capas; CHK-17 con autoprueba de 184 casos, incluida la regla de `ResultadoClic`) completos.
- ADR-003: las claves `*.expected*`, `base.url` y `remote.url` solo aceptan `-D` y `config.properties`; un `-D` sobre un esperado deja WARN con la clave. PI-08 alineada.
- CHK-01…17 activas; en CI: CHK-12 antes de la suite; CHK-11/14/15/16/17 en el job `mutation`.
- Hooks activos: gate DevOps y protección de `.claude/**`, `CLAUDE.md`, `MEMORY.md` y `AGENTS.md`.
- CI con 5 jobs (`test`, `e2e-firefox`, `e2e-grid`, `mutation`, `quarantine`), 2 hilos; Jenkinsfile sin servidor real (R-4).

## Decisiones (y por qué)
- El coordinador es la sesión principal, porque un subagente no puede delegar en otros.
- PIT solo sobre la lógica propia del framework; los E2E se validan con control negativo (`-D…`), porque un SUT externo no se puede mutar.
- El verifier no tiene `memory`: activarla le agrega `Write`/`Edit` y rompe su independencia.
- Solo el usuario aprueba specs (SDD-09) y reescribe historia; los ADR los aprueba el coordinador.
- `MEMORY.md` está bajo `ask`: se importa como instrucción, así que cada cambio lo confirma el usuario.
- Los `Then` comparan contra claves `*.expected*` independientes de la entrada; si no, el control negativo es imposible.
- Las specs y los ADR citan por tag o por nombre de job/paso, no por línea.
- `XPathLiteral` se queda en `pages` sin ramas de comillas (falla ante `'`); se reabre si un dato las necesita.
- Naming de Cucumber se queda en `short` (el usuario): `long` rompe el evaluador de cuarentena y el efecto es solo cosmético.

## Aprendizajes y errores a evitar
- Commits sin `Co-Authored-By` ni marcas de IA; firmados con SSH; el gate exige `%G?` = `G` en cada commit.
- El hook evalúa antes de ejecutar: escribir `devops-gate.json` y hacer el push en comandos separados.
- Un `: ` dentro de la `description` de un agente rompe su YAML; los `|` en tablas Markdown se escapan y cambian la regex.
- En esta instalación no existen `Grep` ni `Glob`: buscar con `git grep`/`git ls-files` (B-01).
- `ask` solo controla `Edit`/`Write`; `protect-config-hook.sh` bloquea las escrituras por `Bash` en los archivos protegidos.
- En SauceDemo (SPA) la URL cambia antes que el DOM: esperar un contenedor propio de la página.
- PIT sin `target/classes` da `BUILD SUCCESS` sin mutar (falla abierto): exigir `mutations.xml`. PIT no muta regex, `requireNonNull` ni accesores de record: control negativo manual.
- Una mutante "equivalente" se demuestra, no se supone.
- Un "no pasa X" verificado solo por ausencia da verde falso: exigir prueba positiva (AC-COMPRA-09 se rechazó dos veces por esto).
- `if script | grep -q` con `pipefail` nunca falla si el script sale con rc ≠ 0: capturar la salida antes.
- Con la máquina cargada, Chrome pierde clics y escrituras nativas (respaldo JS frecuente); con el equipo tranquilo, 0. No correr dos Maven a la vez.
- Firefox local es de snap: necesita `-Dwebdriver.gecko.driver=/snap/bin/geckodriver`; en CI no.
- No existe la CLI `gh`: las operaciones de GitHub las hace el usuario en la web.

## Próximos pasos
1. Usuario: confirmar el run de CI de `5329cf1` (en especial `mutation` con la autoprueba de 184 casos).
2. P2 (architect): marcar "Hecho" el paso 3 del ADR-003 (Grid con `-Dremote.url` en verde, 2026-10-13).
3. P2 (devops/architect): CHK-17 no ve `@Anot public …`, `static public`, interfaces públicas ni `protected` en `pages` (mismo hueco en R1/R3); falta caso de columna 0 (mutante `^\s+public` sobrevive).
4. P2: `inventory.remove-button.text` está en la sección de esperados de `config.properties` sin serlo; causa del respaldo JS bajo carga sin aislar (Firefox/Grid sin medir).
