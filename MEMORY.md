# MEMORY.md — spec-driven-selenium-cucumber

Memoria del proyecto entre sesiones. Máximo ~50 líneas: resume o elimina lo que ya no aporte.

## Estado actual
- Suite 5/5 en verde (local): login exitoso, 2 rechazos de login, compra E2E y carrito con 1 producto (AC-COMPRA-04).
- Specs `docs/specs/login.md` y `compra.md` aprobadas (2026-10-09); features con `Spec:`, `@AC-` y `@tec-`.
- CHK-10 demostrado en los 7 AC verificables: cada control negativo falla en el `Then`.
- Package `com.demo`, Maven Wrapper, `PageManager`, reportes Allure y HTML de Cucumber.
- Equipo de 5 agentes QE con reglas en `.claude/rules/` (SDD, permisos, prompt injection, CHK-01…16).
- ADR-001 (mutación con PIT) aceptado: lógica pura a `src/main/java`, pruebas unitarias, CHK-11/15/16. Paso 1 (`4d75090`): PIT 1.30.0 + junit5-plugin 1.2.3. Paso 2: `ConfigResolver` en `src/main`, 34 unitarias, PIT 33/33; R-4 cerrado.
- Hooks activos: gate DevOps y protección de `.claude/**`, `CLAUDE.md`, `MEMORY.md` y `AGENTS.md` (56/56 casos).
- `AGENTS.md` en la raíz, para cualquier agente de código; bajo `ask`.
- Repo renombrado a `spec-driven-selenium-cucumber` en GitHub y en local (`~/repo/`), con la memoria de Claude Code migrada.
- CHK-12 activa: `scripts/check-traceability.sh` (awk POSIX, compatible con mawk) en CI y Jenkins antes de la suite; 7 controles negativos probados.

## Decisiones (y por qué)
- El coordinador es la sesión principal, porque un subagente no puede delegar en otros.
- No hay agente de datos y ambientes: SauceDemo es externo y no tiene estado de servidor que preparar.
- PIT solo sobre la lógica propia del framework; los E2E se validan con control negativo (`-D…`), porque un SUT externo no se puede mutar.
- El verifier no tiene `memory`: activarla le agrega `Write`/`Edit` y rompe su independencia.
- Solo el usuario aprueba specs (SDD-09) y reescribe historia (push forzado bloqueado en settings).
- `MEMORY.md` está bajo `ask`: se importa como instrucción, así que cada cambio lo confirma el usuario.
- Los `Then` comparan contra claves `*.expected*` independientes de la entrada; si no, el control negativo es imposible.
- Las specs referencian escenarios por tag (`@AC-…`), no por línea: las líneas cambian con cada edición.

## Aprendizajes y errores a evitar
- Commits sin `Co-Authored-By` ni marcas de IA; autor según el git local del repo.
- El hook evalúa antes de ejecutar: escribir `devops-gate.json` y hacer el push en comandos separados.
- Un `: ` dentro de la `description` de un agente rompe su YAML.
- Los comandos con `|` no van en tablas Markdown: se escapan como `\|` y cambian la regex.
- El CI falla si faltan los 6 secrets `TEST_*` en GitHub.
- En esta instalación no existen `Grep` ni `Glob`; se descartan en silencio. Buscar con `git grep`/`git ls-files` (B-01).
- `ask` solo controla `Edit`/`Write`; `protect-config-hook.sh` bloquea las escrituras por `Bash` en los archivos protegidos.
- En SauceDemo (SPA) la URL cambia antes que el DOM: esperar un contenedor propio de la página, no solo la URL.
- PIT 1.30.0 sin `target/classes` dice "Skipping project" y da `BUILD SUCCESS` (falla abierto): CI y gate deben exigir `target/pit-reports/mutations.xml`.
- PIT no muta `requireNonNull` (llamada no `void`): esas pruebas se validan con control negativo manual en una copia aislada (sin `.env`).
- No existe la CLI `gh` en esta máquina: las operaciones de GitHub (renombrar, settings) las hace el usuario en la web.

## Próximos pasos
1. Confirmar en verde el run de GitHub Actions sobre el último push (primer paso CHK-12 en GitHub).
2. Responder las preguntas Q-* de las specs (usuario).
3. ADR-001: pasos 3 (secretos) y 4 (`Credentials`) → 5 verifier → 6 job `mutation` que exija `mutations.xml`. P2: R-5 (`STRONGER` observado) en el ADR; caso con espacio Unicode (`isBlank`).
4. ADR-002: capa de transporte y de acciones de negocio (`qa-automation-architect`).
5. P2: variables de entorno pueden sobrescribir claves `*.expected*` (`ConfigReader`); `getPositiveInt` no admite contador 0 (AC-COMPRA-05); ejemplo XPath desactualizado en `README.md`.
6. Con las Q-* respondidas, cubrir AC-LOGIN-04…09 y AC-COMPRA-05…13.
7. Paralelismo, solo después de confirmar la independencia de los escenarios.
