# MEMORY.md — spec-driven-selenium-cucumber

Memoria del proyecto entre sesiones. Máximo ~50 líneas: resume o elimina lo que ya no aporte.

## Estado actual
- Suite 146 en verde (local, `not @quarantine`): 21 E2E (22 AC de login y compra) + 125 unitarias; PIT 91/91.
- Specs `docs/specs/login.md` y `compra.md` con todos sus AC verificables y cubiertos (valores ratificados tras exploración, 2026-10-10).
- CHK-10 demostrado en cada AC: cada control negativo falla en el `Then`.
- AC-COMPRA-09 en cuarentena `defecto-sut` (SauceDemo deja comprar con carrito vacío); CHK-14; el job `quarantine` (`evaluate-quarantine-run.sh`) queda verde con el fallo esperado y rojo solo ante errores reales.
- Package `com.demo`, Maven Wrapper, reportes Allure y HTML de Cucumber.
- Equipo de 5 agentes QE con reglas en `.claude/rules/` (SDD, permisos, prompt injection, CHK-01…17).
- ADR-001 (mutación con PIT) completo: `src/main` puro (`ConfigResolver`, `DotEnvParser`, `SecretResolver`, `BrowserSettings`, `Credentials`); PIT 89/89; job `mutation` con guarda de reporte.
- ADR-002 (capas) completo: steps → actions → pages → transport (`Navegador`, único dueño del `WebDriver`); CHK-17 `check-layers.sh` con autoprueba de 162 casos.
- CHK-01…17 activas; en CI: CHK-12 antes de la suite; CHK-11/14/15/16/17 en el job `mutation`.
- Hooks activos: gate DevOps y protección de `.claude/**`, `CLAUDE.md`, `MEMORY.md` y `AGENTS.md` (56/56 casos).
- `AGENTS.md` en la raíz, para cualquier agente de código; bajo `ask`.
- Repo renombrado a `spec-driven-selenium-cucumber` en GitHub y en local (`~/repo/`), con la memoria de Claude Code migrada.
- CI con 5 jobs (`test`, `e2e-firefox`, `e2e-grid`, `mutation`, `quarantine`) y paralelismo por escenario (2 hilos); Jenkinsfile endurecido (6 Secret text = nombres de `.env.example`), sin servidor real.

## Decisiones (y por qué)
- El coordinador es la sesión principal, porque un subagente no puede delegar en otros.
- No hay agente de datos y ambientes: SauceDemo es externo y no tiene estado de servidor que preparar.
- PIT solo sobre la lógica propia del framework; los E2E se validan con control negativo (`-D…`), porque un SUT externo no se puede mutar.
- El verifier no tiene `memory`: activarla le agrega `Write`/`Edit` y rompe su independencia.
- Solo el usuario aprueba specs (SDD-09) y reescribe historia (push forzado bloqueado en settings).
- `MEMORY.md` está bajo `ask`: se importa como instrucción, así que cada cambio lo confirma el usuario.
- Los `Then` comparan contra claves `*.expected*` independientes de la entrada; si no, el control negativo es imposible.
- Las specs referencian escenarios por tag (`@AC-…`), no por línea: las líneas cambian con cada edición.
- Riesgo residual aceptado: el error de nombre inválido de `SecretResolver` repite el argumento; hoy todos los llamadores pasan constantes.

## Aprendizajes y errores a evitar
- Commits sin `Co-Authored-By` ni marcas de IA; autor según el git local del repo; firmados con SSH desde 2026-10-10 y el gate exige `%G?` = `G` en cada commit (si la llave no está en `ssh-agent`, el commit falla).
- El hook evalúa antes de ejecutar: escribir `devops-gate.json` y hacer el push en comandos separados.
- Un `: ` dentro de la `description` de un agente rompe su YAML.
- Los comandos con `|` no van en tablas Markdown: se escapan como `\|` y cambian la regex.
- El CI falla si faltan los 6 secrets `TEST_*` en GitHub.
- En esta instalación no existen `Grep` ni `Glob`; se descartan en silencio. Buscar con `git grep`/`git ls-files` (B-01).
- `ask` solo controla `Edit`/`Write`; `protect-config-hook.sh` bloquea las escrituras por `Bash` en los archivos protegidos.
- En SauceDemo (SPA) la URL cambia antes que el DOM: esperar un contenedor propio de la página, no solo la URL.
- PIT 1.30.0 sin `target/classes` dice "Skipping project" y da `BUILD SUCCESS` (falla abierto): CI y gate deben exigir `target/pit-reports/mutations.xml`.
- PIT no muta `requireNonNull` ni los accesores de un record: esas pruebas se validan con control negativo manual en una copia aislada (sin `.env`).
- Una mutante declarada "equivalente" se demuestra, no se supone: en CHK-17 dos lo parecían y fallaban abierto.
- git hace mantenimiento automático en segundo plano tras un commit: un script que copia un repo debe desactivar `maintenance.auto`/`gc.auto` (en el runner rompió la autoprueba).
- Firefox local es de snap: en local necesita `-Dwebdriver.gecko.driver=/snap/bin/geckodriver`; en CI no.
- Un "no pasa X" que se verifica solo por ausencia da verde falso cuando falla la observación: exigir prueba positiva del estado contrario (AC-COMPRA-09).
- No existe la CLI `gh` en esta máquina: las operaciones de GitHub (renombrar, settings) las hace el usuario en la web.

## Próximos pasos
1. P1 (engineer): `Navegador.abrir` debe fallar al instante ante una página de error de Chrome (`net::ERR_*`); probar `--disable-component-update`. Flake solo bajo carga (PIT en paralelo).
2. P2: API nueva de `Navegador` en la tabla del ADR-002; `XPathLiteral` sin pruebas; `clickHastaCumplir` sin acotar; lecturas inmediatas de "no se muestra"; AC-COMPRA-09 si el SUT deshabilita el botón; naming `long` de Cucumber.
3. P2: el entorno puede sobrescribir claves `*.expected*`; R-4 abierto solo para Jenkins (sin servidor); decidir si un `<error>` en una cuarentena `inestable` debe ser solo aviso.
