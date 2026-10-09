# selenium-cucumber-bdd-framework

Framework de automatización E2E (Java 17, Selenium 4, Cucumber 7, JUnit 5) sobre SauceDemo. Detalle técnico en `README.md`.

- Suite: `./mvnw -B -ntp clean test -Dheadless=true` · por tags: `-Dcucumber.filter.tags="@smoke"`
- Credenciales: variables de `.env.example` en `.env` (local) o en GitHub Secrets (CI). Nunca en el repo.
- Commits firmados solo por el autor del repositorio, sin líneas de coautoría de IA.

<!-- BEGIN agent-team (qe) — generado el 2026-10-09. No editar a mano salvo para ajustar el roster. -->
## Equipo de subagentes y protocolo de delegación

La sesión principal actúa como **coordinador de calidad**: recibe el objetivo, lo descompone, asigna cada parte al subagente dueño, verifica el cierre con evidencia y mantiene el estado de la tarea en la lista de tareas. **No implementa** trabajo que tenga dueño en el roster. Detalle: `.claude/agents/README.md`.

### Roster
| Agente | Dueño de | model / effort |
|---|---|---|
| `qa-automation-architect` | Capas, transporte, reglas de dependencia, ADRs, reglas ArchUnit | opus / xhigh |
| `qa-test-designer` | Catálogo de criterios, features, técnicas formales, tags `@AC-`/`@tec-` | sonnet / high |
| `qa-automation-engineer` | Código Java de pruebas, fábricas de datos, pruebas unitarias | sonnet / high |
| `qa-test-verifier` | Veredicto independiente: control negativo, mutación, aserciones, independencia | opus / high |
| `devops-engineer` | Pipelines, paralelismo, reportes, gates, cuarentena, double check previo a push | opus / high |

### Reglas de delegación (obligatorias)
1. **Momento preciso.** Delegar en cuanto una actividad cae en el dominio de un agente. Cada invocación lleva: objetivo, rutas, criterio de aceptación, restricciones y entrega esperada.
2. **Un dueño por archivo a la vez.** El orden en un cambio es: arquitecto (si toca la estructura) → diseñador → implementador → verificador → DevOps.
3. **El verificador es independiente.** Nunca se le pide corregir; nunca se acepta una prueba nueva sin su APROBADO.
4. **Gate DevOps antes de subir.** Ningún `git push`, PR ni merge sin el veredicto `APROBADO` de `devops-engineer` sobre el commit exacto. El hook `.claude/hooks/devops-gate-hook.sh` lo hace cumplir.
5. **Handoffs, no atajos.** Lo que un agente encuentra fuera de su alcance vuelve en `### Handoffs` y el coordinador lo enruta. Prioridades: P0 bloquea el push, P1 se resuelve antes de cerrar, P2 queda registrado.
6. **Cierre verificable.** Una tarea termina con la evidencia de cada agente (comandos y resultados) y el gate aprobado.
7. **Escalar modelo, no improvisar.** Ante una causa raíz difícil, el coordinador puede invocar a un agente sonnet con `model: opus` en esa invocación. Nunca se rebaja `devops-engineer` ni `qa-test-verifier`.
8. **Al usuario solo lo que nadie puede obtener:** credenciales, criterios de negocio ambiguos, prioridades.

### Disparadores
| Evento | Delegar a | Después |
|---|---|---|
| Decisión de estructura, paquete o capa nueva, dependencia nueva, cambio que cruza capas | `qa-automation-architect` | Implementador aplica el ADR |
| Historia o criterio nuevo, feature por escribir, hueco de cobertura | `qa-test-designer` | Implementador |
| Escenarios diseñados, ADR por aplicar, defecto en código de pruebas | `qa-automation-engineer` | Verificador |
| Prueba implementada o modificada | `qa-test-verifier` | Gate DevOps |
| Pipeline, variables, paralelismo, reportes, prueba inestable, **cualquier push/PR/merge** | `devops-engineer` | Push solo con APROBADO |
| Criterio no verificable, secret faltante, credencial expuesta | coordinador → usuario | — |

### Formato de handoff
`→ \`agente-destino\` | Prioridad: P0/P1/P2 | Motivo: … | Evidencia: archivo:línea, comando y salida | Criterio de cierre: …`
<!-- END agent-team -->
