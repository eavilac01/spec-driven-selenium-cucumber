## Qué cambia y por qué

<!-- Una o dos frases. -->

## Trazabilidad

- Spec: `docs/specs/…` <!-- o "no aplica" si no cambia comportamiento -->
- AC afectados: `@AC-…`
- ADR: `docs/adr/…` <!-- obligatorio si hay estructura, capa o dependencia nueva -->

## Comprobaciones ejecutadas en local

<!-- Marca las que corriste y pega el resultado relevante (sin credenciales). -->

- [ ] CHK-08: suite completa en verde (`Tests run: …`)
- [ ] CHK-10: control negativo de cada prueba nueva (falla en el `Then`)
- [ ] CHK-12: trazabilidad (`bash scripts/check-traceability.sh`)
- [ ] CHK-17: capas (`bash scripts/check-layers.sh`)
- [ ] CHK-15/16: pureza de `src/main` y unitarias aisladas (`bash scripts/check-unit-purity.sh`)
- [ ] Si cambia `scripts/`: su autoprueba y CHK-18 (portabilidad de awk)
- [ ] Si cambia `src/main`: CHK-11 (mutación, umbral 80 %)

## Lista de control

- [ ] Sin `Thread.sleep`, esperas implícitas ni reintentos
- [ ] Ninguna prueba desactivada fuera de la cuarentena reglada
- [ ] Sin credenciales, tokens ni datos personales en el diff ni en los logs adjuntos
- [ ] Sin dependencias, plugins ni cambios de CI sin su ADR
- [ ] Commits sin líneas de coautoría ni marcas de herramientas de IA
