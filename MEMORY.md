# MEMORY.md — spec-driven-selenium-cucumber

Memoria del proyecto entre sesiones. Máximo ~50 líneas: resume o elimina lo que ya no aporte.

## Estado actual
- Suite 122 en verde (local): 5 E2E (login exitoso, 2 rechazos, compra, carrito con 1 producto) + 117 unitarias.
- Specs `docs/specs/login.md` y `compra.md` aprobadas (2026-10-09); features con `Spec:`, `@AC-` y `@tec-`.
- CHK-10 demostrado en los 7 AC verificables: cada control negativo falla en el `Then`.
- Package `com.demo`, Maven Wrapper, reportes Allure y HTML de Cucumber.
- Equipo de 5 agentes QE con reglas en `.claude/rules/` (SDD, permisos, prompt injection, CHK-01…17).
- ADR-001 (mutación con PIT) completo: `src/main` puro (`ConfigResolver`, `DotEnvParser`, `SecretResolver`, `BrowserSettings`, `Credentials`); PIT 89/89; job `mutation` con guarda de reporte.
- ADR-002 (capas) completo: steps → actions → pages → transport (`Navegador`, único dueño del `WebDriver`); CHK-17 `check-layers.sh` con autoprueba de 154 casos.
- CHK-01…17 activas; en CI: CHK-12 antes de la suite; CHK-11/15/16/17 en el job `mutation`.
- Hooks activos: gate DevOps y protección de `.claude/**`, `CLAUDE.md`, `MEMORY.md` y `AGENTS.md` (56/56 casos).
- `AGENTS.md` en la raíz, para cualquier agente de código; bajo `ask`.
- Repo renombrado a `spec-driven-selenium-cucumber` en GitHub y en local (`~/repo/`), con la memoria de Claude Code migrada.
- CI con 4 jobs (`test`, `e2e-firefox`, `e2e-grid`, `mutation`) y paralelismo por escenario (2 hilos); Jenkinsfile endurecido (6 Secret text = nombres de `.env.example`), sin servidor real.

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
- Firefox local es de snap: en local necesita `-Dwebdriver.gecko.driver=/snap/bin/geckodriver`; en CI no.
- No existe la CLI `gh` en esta máquina: las operaciones de GitHub (renombrar, settings) las hace el usuario en la web.

## Próximos pasos
1. Specs con valores ratificados (exploración 2026-10-10) en `en-cambio` → aprobación del usuario → features y steps de AC-LOGIN-04…09 y AC-COMPRA-05…13.
2. AC-COMPRA-09 es defecto conocido del SUT (permite comprar con carrito vacío): `@quarantine` tipo `defecto-sut` + `docs/quarantine.md` + script de CHK-14 (devops).
3. Confirmar en el run remoto de `caf2fa0` los jobs `e2e-firefox` y `e2e-grid` (cierra R-6) y el paralelismo (cierra R-3); R-4 sigue abierto solo para Jenkins.
4. P2: el entorno puede sobrescribir claves `*.expected*`; `BrowserSettingsTest` `:235`/`:252` verifican solo el tipo de la causa.
