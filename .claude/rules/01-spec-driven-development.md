# Regla 01 — Spec Driven Development (SDD)

La **spec es la fuente de verdad**. Las features y el código se derivan de ella; nunca al revés.

## Cadena de artefactos

| Nivel | Artefacto | Ubicación | Redacta | Aprueba |
|---|---|---|---|---|
| 1. Spec | Objetivo, reglas de negocio, criterios de aceptación (AC) con ID | `docs/specs/<dominio>.md` | `qa-test-designer` | **Usuario** |
| 2. Diseño | ADR, solo si la spec exige estructura nueva | `docs/adr/NNN-*.md` | `qa-automation-architect` | Coordinador |
| 3. Feature | Escenarios ejecutables con `@AC-` y `@tec-` | `src/test/resources/features/<dominio>.feature` | `qa-test-designer` | `qa-test-verifier` + CHK-12 |
| 4. Acciones y steps | Vocabulario de negocio que ejecuta la feature. La lógica pura de esta capa (configuración, secretos, datos) vive en `src/main/java` (ADR-001) | `com.demo.actions`, `com.demo.steps`; `com.demo.config`, `com.demo.data` | `qa-automation-engineer` | `qa-test-verifier` |
| 5. Páginas y transporte | Interacción con la interfaz | `com.demo.pages`, `com.demo.transport` | `qa-automation-engineer` | `qa-test-verifier` |

## Reglas

| ID | Regla |
|---|---|
| SDD-01 | Sin una spec en estado `aprobada` no se escribe la feature. |
| SDD-02 | Sin feature no hay step; sin step no hay acción ni página nueva. No se escribe código especulativo. Las pruebas unitarias del framework no requieren spec: las origina un ADR, y un ADR puede originarse en una CHK. |
| SDD-03 | Un cambio de comportamiento empieza por la spec: spec → feature → código. Nunca se ajusta una feature o una aserción para que "coincida" con la aplicación sin cambiar antes la spec. |
| SDD-04 | Cada AC tiene un ID estable `AC-<DOMINIO>-<NN>`. Un ID no se reutiliza; un AC eliminado queda marcado como `retirado`. |
| SDD-05 | Cada escenario apunta a uno o más AC. Cada AC apunta a uno o más escenarios, o figura en *No cubiertos* con su motivo. |
| SDD-06 | La descripción de la feature declara su spec: `Spec: docs/specs/<dominio>.md`. |
| SDD-07 | Cada nivel describe solo lo suyo. La spec dice el **qué** (negocio), la feature el comportamiento observable y el código el **cómo**. No hay selectores ni vocabulario de interfaz en la spec ni en la feature. |
| SDD-08 | Si la aplicación diverge de la spec, es un defecto del sistema bajo prueba o una spec desactualizada. Se reporta a `main` para que decida el usuario; nunca se resuelve en silencio. |
| SDD-09 | Ciclo de vida de una spec: `borrador` → `aprobada` → (`en-cambio` → `aprobada`) o `retirada`. **Solo el usuario** cambia una spec a `aprobada`. |

## Estado
`login.feature` y `compra_e2e.feature` ya tienen spec aprobada (`docs/specs/login.md`, `docs/specs/compra.md`); CHK-12 lo comprueba en cada ejecución del CI.

Plantilla: `docs/specs/_plantilla.md`.
