# Cuarentena de escenarios (CHK-14)

Un escenario con la etiqueta `@quarantine` queda fuera de la suite que bloquea (`not @quarantine`) y corre en un job informativo (`quarantine` en GitHub Actions, etapa `Cuarentena` en Jenkins) que no rompe el build. La cuarentena es la **única** vía para sacar un escenario de la suite que bloquea (P-05), y cada uno necesita una fila en este registro. `scripts/check-quarantine.sh` lo comprueba en cada ejecución del CI.

## Tipos

| Tipo | Cuándo | Plazo | Cómo sale de la cuarentena |
|---|---|---|---|
| `inestable` | El escenario falla de forma intermitente sin cambios en el código (umbral: 2 o más fallos en 20 ejecuciones de `main`, o 1 o más en 10 ejecuciones locales) | Límite ≤ 14 días desde el ingreso | Se corrige la causa raíz, se quita la etiqueta y CHK-08 pasa dos veces seguidas; o se retira el escenario con un ADR. Un verde aislado no basta |
| `defecto-sut` | El sistema bajo prueba no cumple una regla de negocio vigente de la spec (SDD-08). El escenario falla porque el resultado esperado es correcto | Próxima revisión ≤ 90 días desde el ingreso | Cuando el sistema bajo prueba se corrige, el escenario pasa en el job `quarantine`: se revisa la spec, se quita la etiqueta y se borra la fila. Si en la revisión sigue fallando, se renueva la fecha con una nueva revisión |

## Reglas del registro
- Una fila por criterio de aceptación: la columna **Escenario** lleva una sola etiqueta `@AC-<DOMINIO>-<NN>`, la misma del escenario en cuarentena. Si varios escenarios con ese `@AC-` están en cuarentena, comparten la fila.
- Ninguna fila sin escenario `@quarantine`, ni escenario `@quarantine` sin fila.
- Fechas en formato `YYYY-MM-DD`. El ingreso no puede ser posterior a hoy, y una fecha de límite o de revisión vencida hace fallar CHK-14.
- Una celda vacía o con `—` cuenta como campo ausente.
- Nunca se copian aquí secretos, credenciales ni texto literal del sistema bajo prueba fuera de lo que ya dice la spec.

## Registro

### `inestable`

| Tipo | Escenario | Dueño | Ingreso | Límite | Issue | Diagnóstico |
|---|---|---|---|---|---|---|

### `defecto-sut`

| Tipo | Escenario | Dueño | Ingreso | Referencia | Esperado | Observado | Próxima revisión |
|---|---|---|---|---|---|---|---|
| defecto-sut | `@AC-COMPRA-09` | Eduardo Avila Carranza | 2026-10-10 | `docs/specs/compra.md`, sección "Defecto conocido del sistema bajo prueba (AC-COMPRA-09, SDD-08)" | Con el carrito vacío, no avanza a los datos de envío (RN-7) | Avanza a los datos de envío sin mostrar ningún mensaje | 2026-12-31 |
