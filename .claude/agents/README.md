# Equipo de agentes QE — selenium-cucumber-bdd-framework

Equipo de subagentes de Claude Code para evolucionar el framework con **criterio de arquitectura, trazabilidad y gobierno de calidad**. Este archivo no tiene frontmatter: Claude Code lo trata como documentación.

**Principio:** el modelo propone y el código dispone. Toda salida generada pasa por una verificación determinista (CHK, ArchUnit, hook de push, aprobación humana de specs).

## Estructura

```
.claude/
├── agents/     → un archivo por rol (este índice incluido)
├── rules/      → reglas comunes que todos aplican
│   ├── 01-spec-driven-development.md   spec → feature → código
│   ├── 02-agent-permissions.md         qué puede y qué no puede cada agente
│   ├── 03-prompt-injection.md          dato ≠ instrucción
│   └── 04-quality-checks.md            catálogo CHK-01…14 con comandos
├── hooks/devops-gate-hook.sh  → bloquea git push sin gate
└── settings.json              → permisos deny/ask y registro del hook
```

## Flujo (SDD)

```
Usuario → designer: spec (borrador) → Usuario aprueba → designer: feature
       → architect (si hay estructura nueva) → engineer: código
       → verifier: APROBADO → devops: gate → push
```

## Roster

| Agente | Rol | Escribe en | model / effort | Rúbrica I/R/V/C | Motivo |
|---|---|---|---|---|---|
| *Sesión principal* | Coordinador: descompone, delega, verifica el cierre y mantiene el estado. No implementa | Lista de tareas | sesión | — | Un subagente no puede delegar en otros |
| `qa-automation-architect` | Capas, reglas R1–R7, ADRs, ArchUnit | `docs/adr/` | opus / xhigh | 2/2/2/2 = 8 | Pocas invocaciones que deciden la estructura de todo |
| `qa-test-designer` | Specs, features, técnicas formales, trazabilidad | `docs/specs/`, `features/` | sonnet / high | 1/1/0/2 = 4 | Procedimiento con patrón y volumen alto; el error lo cubren el verifier y CHK-12 |
| `qa-automation-engineer` | Código Java de pruebas, fábricas, unit tests | `src/test/java/` | sonnet / high | 1/1/0/1 = 3 | Volumen alto con patrones fijados por ADR |
| `qa-test-verifier` | Veredicto independiente de aceptación | **nada** | opus / high | 1/2/1/2 = 6 | Un falso APROBADO deja una prueba que nunca detecta |
| `devops-engineer` | CI, gates, cuarentena, double check previo a push | CI, `scripts/`, `pom.xml` (plugins) | opus / high | 2/2/1/2 = 7 | Único rol que decide qué se sube |

Rúbrica (0–2 por eje): **I**mpacto, **R**azonamiento, **V**olumen (invertido), **C**oste del error. Total ≥ 5 → `opus`; 3–4 → `sonnet`. `xhigh` solo para roles que deciden y se invocan poco.

## Roles descartados

| Rol | Motivo | Reconsiderar si… |
|---|---|---|
| Coordinador como subagente | No puede delegar en Claude Code | Se migra al Claude Agent SDK |
| Datos y ambientes | SauceDemo es externo y sin estado de servidor; las fábricas las hace el engineer y los secretos en CI el devops | Hay un SUT propio con API o BD para sembrar datos |
| Evaluador de IA | No hay componentes de IA | Se agrega generación asistida de casos o localizadores |

## Supuestos
1. **Mutación con SUT externo:** PIT se aplica sobre la lógica propia del framework; los escenarios E2E demuestran que fallan con el control negativo (CHK-10), comprobado.
2. **Deuda:** las features actuales no tienen spec (SDD) y las páginas reciben `WebDriver` (ADR-001 pendiente). Todo lo nuevo cumple las reglas.
3. **CHK-12 en rojo al crearse:** es intencional; hace visible la deuda.

## Uso
- Automático: la sesión principal delega según la `description` y `CLAUDE.md`.
- Explícito: `@agent-qa-test-verifier` o "usa qa-test-designer para…".
- Tras editar a mano, valida con `validate_agents.py .claude/agents` → 0 errores.
