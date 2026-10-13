---
name: Divergencia entre el sistema y la spec
about: SauceDemo se comporta distinto de lo que dice una spec aprobada (SDD-08)
title: "[spec] AC-"
labels: spec
---

<!--
Una divergencia es un defecto del sistema bajo prueba o una spec desactualizada.
Nunca se resuelve ajustando la aserción: decide el mantenedor (SDD-08).
-->

## Criterio afectado

- Spec: `docs/specs/…`
- AC: `AC-…`
- Escenario: `src/test/resources/features/…` (`@AC-…`)

## Esperado (según la spec)

## Observado (en SauceDemo)

## Evidencia

<!-- Captura de `target/cucumber-report.html` o extracto del log, sin credenciales. -->

## Propuesta

- [ ] Defecto del sistema: cuarentena `defecto-sut` en `docs/quarantine.md`
- [ ] La spec está desactualizada: cambiarla (`en-cambio` → `aprobada`)
