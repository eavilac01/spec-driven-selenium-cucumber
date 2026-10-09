# Equipo de agentes QE — selenium-cucumber-bdd-framework

Equipo de subagentes de Claude Code que trabaja sobre este framework de automatización. Su objetivo no es la cobertura amplia sino demostrar **criterio de arquitectura, trazabilidad y gobierno de calidad**. Este archivo no tiene frontmatter: Claude Code lo trata como documentación, no como agente.

**Principio que ordena al equipo:** el modelo propone y el código dispone. Cada salida generada por un agente queda envuelta en una verificación que no depende de un modelo (reglas ArchUnit, `git grep`, gate de trazabilidad, control negativo, PIT, hook de push). Cada agente declara en su sección *Entradas y salidas* quién valida su salida y qué ocurre si esa validación falla.

## Roster

| Agente | Responsabilidad única | model / effort | Puntaje rúbrica (I/R/V/C) | Motivo de la asignación |
|---|---|---|---|---|
| *Sesión principal* (`CLAUDE.md`) | **Coordinador**: descompone el objetivo, delega con contrato, verifica el cierre y mantiene el estado. No implementa | sesión | — | En Claude Code un subagente no puede invocar a otros; la coordinación solo puede vivir en la sesión principal |
| `qa-automation-architect` | Cinco capas, interfaz de transporte, reglas de dependencia R1–R7, ADRs y reglas ArchUnit | opus / xhigh | 2/2/2/2 = 8 | Se invoca poco y cada invocación fija la estructura que replican todas las pruebas; el error de diseño es el más caro de revertir |
| `qa-test-designer` | Catálogo de criterios de aceptación, features con intención de negocio, técnicas formales y etiquetas `@AC-`/`@tec-` | sonnet / high | 1/1/0/2 = 4 | Las técnicas formales son procedimiento con patrón y el volumen es alto; `high` para no perder fronteras. El verificador y el gate de trazabilidad cubren el coste del error |
| `qa-automation-engineer` | Código Java de pruebas: transporte, páginas, acciones, steps, fábricas de datos y pruebas unitarias | sonnet / high | 1/1/0/1 = 3 | Alto volumen con patrones fijados por ADR; el error se detecta de inmediato en la compilación, el verificador o el gate |
| `qa-test-verifier` | Veredicto independiente: control negativo, mutación, aserciones, sleep, reintentos, independencia y camino feliz | opus / high | 1/2/1/2 = 6 | Decide si una prueba se acepta; un falso APROBADO deja una prueba que nunca detectará un defecto. No edita código |
| `devops-engineer` | Pipelines, paralelismo, reportes, gates de trazabilidad, mutación y cuarentena; double check previo a push | opus / high | 2/2/1/2 = 7 | Único rol que decide qué se sube; el estándar fija opus/high como mínimo y nunca se rebaja |

Ejes de la rúbrica (0–2 cada uno): **I**mpacto e irreversibilidad, profundidad de **R**azonamiento, **V**olumen (invertido: más volumen, menos puntos), **C**oste del error. Total ≥ 5 → `opus`; 3–4 → `sonnet`. `xhigh` solo para roles que deciden y se invocan poco. Los valores `effort` son los que acepta Claude Code (`low`/`medium`/`high`/`xhigh`/`max`).

## Roles evaluados y descartados

| Rol | Motivo | Cuándo reconsiderarlo |
|---|---|---|
| Coordinador como subagente | Un subagente no puede delegar en otros. Se implementa como bloque de orquestación en `CLAUDE.md` | Si se migra a un orquestador externo (Claude Agent SDK) |
| Ingeniero de datos y ambientes | SauceDemo es externo y sin estado de servidor: usuarios fijos, sin API ni BD para preparar estado. Las fábricas son poca lógica y las implementa `qa-automation-engineer`; la independencia y el reloj inyectado los hace cumplir `qa-test-verifier`; los secretos en CI son de `devops-engineer` | Con un sistema bajo prueba propio que permita sembrar datos por API o BD |
| Evaluador de componentes de IA | El proyecto no genera ni clasifica nada con modelos | Si se incorpora generación asistida de casos, de localizadores o de datos |

## Dónde vive cada regla técnica

| Regla | Agente que la aplica como criterio de rechazo |
|---|---|
| Cinco capas, steps sin localizadores, features sin vocabulario de interfaz | `qa-automation-architect` (R1–R7) y, para features, `qa-test-designer` |
| `Thread.sleep` prohibido | `qa-test-verifier` (rechazo automático), `devops-engineer` (gate), `qa-automation-engineer` (autoverificación) |
| Datos por fábrica, sin orden, reloj y semilla inyectados | `qa-automation-engineer` (implementa) y `qa-test-verifier` (rechaza) |
| Trazabilidad `@AC-` + `@tec-` | `qa-test-designer` (etiqueta) y `devops-engineer` (`scripts/check-traceability.sh` en CI) |
| La prueba nueva debe fallar contra un resultado roto | `qa-test-verifier` (control negativo por `-D`, comprobado) |
| Mutación ≥ 80 %, cobertura de líneas no es criterio | `devops-engineer` (job PIT) y `qa-test-verifier` (veredicto) |
| Sin reintentos; cuarentena con dueño y fecha | `devops-engineer` (umbral, carril `@quarantine`, `docs/quarantine.md`) |
| Técnicas formales, fronteras exactas, criterios no verificables no se inventan | `qa-test-designer` |

## Supuestos documentados
1. **Mutación con sistema bajo prueba externo.** No se puede mutar la lógica de SauceDemo. La métrica de mutación (PIT) se aplica a la lógica determinista propia del framework con pruebas unitarias; para los escenarios E2E, la demostración de que la prueba falla se hace por control negativo, corrompiendo el valor esperado con `-D<clave>=…`.
2. **Catálogo de criterios.** Como no existía, `qa-test-designer` crea `docs/acceptance-criteria.md` desde las narrativas actuales, con IDs `AC-<DOMINIO>-<NN>`.
3. **Deuda conocida.** Hoy las páginas reciben `WebDriver` y los steps llaman a las páginas. Es deuda registrada por el ADR-001 pendiente; todo código nuevo o modificado cumple la arquitectura objetivo.
4. **Gate de trazabilidad en rojo al crearse.** Los escenarios actuales no tienen `@AC-`/`@tec-`; el primer rojo es intencional y visible.

## Cómo invocar
- **Delegación automática:** la sesión principal delega según la `description` de cada agente y el protocolo de `CLAUDE.md`.
- **Invocación explícita:** `@agent-qa-test-verifier`, o "usa el agente qa-test-designer para …".
- **Ritmo de una tarea:** objetivo → (arquitecto si toca la estructura) → diseñador → implementador → verificador → gate DevOps → push.

## Gate DevOps
`devops-engineer` es paso obligatorio antes de `git push`, PR o merge. **Hook instalado:** `.claude/hooks/devops-gate-hook.sh`, registrado en `.claude/settings.json`, bloquea cualquier `git push` si `.claude/devops-gate.json` no contiene `verdict: APROBADO` para el `commit` igual a HEAD. Ese JSON está en `.gitignore`.

## Validar tras editar a mano
`python3 <ruta-al-skill-agent-team>/scripts/validate_agents.py .claude/agents` → 0 errores.
