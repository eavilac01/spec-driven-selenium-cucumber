# Cómo contribuir

Gracias por tu interés. Este repositorio es un framework de referencia para automatización E2E con **Spec Driven Development (SDD)**: cada prueba nace de una especificación aprobada y cada comprobación de calidad es un comando determinista. Antes de proponer un cambio, lee el [README](README.md) y las reglas de [`.claude/rules/`](.claude/rules/).

## Preparar el entorno

1. JDK 17 y Chrome (o Firefox). Maven no hace falta: el proyecto trae Maven Wrapper (`./mvnw`).
2. Copia `.env.example` a `.env` y complétalo con las credenciales públicas de SauceDemo, como explica el README en [Credenciales de SauceDemo](README.md#credenciales-de-saucedemo-cómo-obtenerlas). `.env` está ignorado: **nunca lo subas**.
3. Opcional, para correr CHK-18 como el CI: instala `gawk` (`sudo apt install gawk`).

Sin `.env` puedes correr igualmente las pruebas unitarias y las de mutación:

```bash
./mvnw -B -ntp test -Dtest='com.demo.config.*Test,com.demo.data.*Test' -Dsurefire.failIfNoSpecifiedTests=false
./mvnw -B -ntp test-compile org.pitest:pitest-maven:mutationCoverage
```

## El flujo de trabajo (SDD)

1. **Spec:** un comportamiento nuevo empieza en `docs/specs/<dominio>.md`, con criterios de aceptación `AC-<DOMINIO>-<NN>`. Solo el mantenedor marca una spec como `aprobada`.
2. **Feature:** con la spec aprobada, el escenario Gherkin va en `src/test/resources/features/`, con las etiquetas `@AC-…` y `@tec-…` y sin vocabulario de interfaz (clic, botón, campo, selectores).
3. **Código:** steps, acciones, páginas y transporte según las capas del [ADR-002](docs/adr/002-transport-and-business-actions.md). Una estructura o dependencia nueva requiere un ADR en `docs/adr/`.

Nunca se ajusta una aserción para que "coincida" con la aplicación sin cambiar antes la spec. Si la aplicación diverge de la spec, abre un issue de tipo **Divergencia entre el sistema y la spec**.

## Antes de abrir un pull request

Corre en local las comprobaciones que aplican a tu cambio (el catálogo completo, CHK-01…20, está en [`.claude/rules/04-quality-checks.md`](.claude/rules/04-quality-checks.md)):

```bash
./mvnw -B -ntp clean test -Dheadless=true -Dcucumber.filter.tags="not @quarantine"   # CHK-08: suite completa
bash scripts/check-traceability.sh   # CHK-12: trazabilidad spec → feature
bash scripts/check-layers.sh         # CHK-17: reglas de capas
bash scripts/check-unit-purity.sh    # CHK-15/16: src/main puro y unitarias aisladas
bash scripts/check-quarantine.sh     # CHK-14: cuarentena reglada
```

Si cambias un script de `scripts/`, corre también su autoprueba en `scripts/tests/` y CHK-18 (portabilidad de awk).

Cada prueba nueva debe demostrar que **falla cuando debe** (control negativo, CHK-10):

```bash
./mvnw -B -ntp test -Dheadless=true -Dcucumber.filter.tags="@AC-XXX-NN" -D<clave.esperada>=__CONTROL_NEGATIVO__
```

## Reglas que no se negocian

- Sin `Thread.sleep`, esperas implícitas ni reintentos automáticos: se corrige la causa raíz.
- No se desactiva, comenta ni filtra ninguna prueba fuera de la cuarentena reglada (`docs/quarantine.md`).
- Sin dependencias ni plugins nuevos sin un ADR.
- Nada de credenciales, tokens ni datos personales en el código, los commits, los issues o los logs adjuntos.
- Los commits no llevan líneas de coautoría ni marcas de herramientas de IA. Se recomienda firmarlos.

## Cómo llega un cambio a `main`

`main` está protegida (ruleset `proteger-main`) y nadie sube directo a ella, tampoco el autor del repositorio:

1. Trabaja en una rama (por ejemplo `tanda/<tema>` o la de tu fork).
2. Abre un pull request hacia `main` con la plantilla completa (trazabilidad y CHK ejecutadas).
3. Deben pasar los 5 checks de CI: `test`, `e2e-firefox`, `e2e-grid`, `mutation` y `quarantine`.
4. Los commits deben estar firmados (*Require signed commits*). Un PR externo necesita además la aprobación de un mantenedor.
5. La fusión se hace con **merge commit**, no con *squash* ni *rebase*: los ADR citan commits por su hash y deben seguir existiendo en `main`.

## Pull requests desde un fork

Los pull requests que vienen de un fork **no reciben los secrets** del repositorio, así que en ellos el CI omite los jobs E2E (`test`, `e2e-firefox`, `e2e-grid` y `quarantine`) y lo indica con un aviso. Sí corren el job `mutation` (pruebas unitarias, mutación, trazabilidad, capas, cuarentena y portabilidad) sin credenciales.

Antes de fusionar, un mantenedor ejecuta los E2E sobre tu commit desde una rama del propio repositorio. Un job omitido no significa que tu cambio esté verificado.

## Si trabajas con Claude Code

El repositorio incluye un equipo de agentes en `.claude/` y hooks en `.claude/settings.json` que Claude Code ejecuta si confías en el espacio de trabajo: bloquean un `git push` sin el gate de DevOps y cualquier escritura por Bash en la configuración de los agentes y en los workflows. Son inocuos, pero conviene saber que existen. Detalle en [`.claude/agents/README.md`](.claude/agents/README.md).

## Reportar un problema de seguridad

No uses issues públicos: sigue [SECURITY.md](SECURITY.md).
