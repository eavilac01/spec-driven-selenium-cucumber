# MEMORY.md — selenium-cucumber-bdd-framework

Memoria del proyecto entre sesiones. Máximo ~50 líneas: resume o elimina lo que ya no aporte.

## Estado actual
- Suite 4/4 en verde, local y en GitHub Actions: login exitoso, 2 rechazos de login y compra E2E.
- Package `com.demo`, Maven Wrapper, `PageManager`, reportes Allure y HTML de Cucumber.
- Equipo de 5 agentes QE con reglas en `.claude/rules/` (SDD, permisos, prompt injection, CHK-01…14).
- Hook del gate DevOps activo: ningún push sin `APROBADO` sobre HEAD.
- Commit `61c8036` (quitar `memory` al verifier) aprobado por el gate y **sin subir**: espera la confirmación del usuario (PI-07).

## Decisiones (y por qué)
- El coordinador es la sesión principal, porque un subagente no puede delegar en otros.
- No hay agente de datos y ambientes: SauceDemo es externo y no tiene estado de servidor que preparar.
- PIT solo sobre la lógica propia del framework; los E2E se validan con control negativo (`-D…`), porque un SUT externo no se puede mutar.
- El verifier no tiene `memory`: activarla le agrega `Write`/`Edit` y rompe su independencia.
- Solo el usuario aprueba specs (SDD-09) y reescribe historia (push forzado bloqueado en settings).

## Aprendizajes y errores a evitar
- Commits sin `Co-Authored-By` ni marcas de IA; autor según el git local del repo.
- El hook evalúa antes de ejecutar: escribir `devops-gate.json` y hacer el push en comandos separados.
- Un `: ` dentro de la `description` de un agente rompe su YAML.
- Los comandos con `|` no van en tablas Markdown: se escapan como `\|` y cambian la regex.
- El CI falla si faltan los 6 secrets `TEST_*` en GitHub.

## Próximos pasos
1. Decidir el push de `61c8036` y reiniciar Claude Code para que el verifier cargue sin `Write`/`Edit`.
2. Specs retroactivas de login y compra (`qa-test-designer`) → aprobación del usuario.
3. ADR-001: capa de transporte y de acciones de negocio (`qa-automation-architect`).
4. CHK-12 `scripts/check-traceability.sh` y CHK-11 PIT, este último tras su ADR (`devops-engineer`).
5. Etiquetar las features con `@AC-`/`@tec-` una vez aprobadas las specs.
6. Fábricas de datos con `Clock` y semilla inyectados; fronteras del checkout y del carrito.
7. Paralelismo, solo después de confirmar la independencia de los escenarios.
