# Cuarentena de escenarios (CHK-14)

Un escenario con la etiqueta `@quarantine` queda fuera de la suite que bloquea (`not @quarantine`) y corre en un job propio (`quarantine` en GitHub Actions, etapa `Cuarentena (CHK-14)` en Jenkins). `scripts/evaluate-quarantine-run.sh` evalúa esa ejecución contra este registro según el tipo de cada escenario:

| Resultado del escenario | `defecto-sut` | `inestable` |
|---|---|---|
| Falla por aserción | **Verde** (lo esperado) | **Verde** (informativo) |
| Pasa | **Verde con aviso**: hay que revisar la spec | **Verde** (informativo): un verde aislado no la saca de la cuarentena |
| Termina con error (excepción o timeout, no aserción) | **Rojo**: no mide el criterio | **Verde con aviso** que nombra su `@AC-`: hay que revisar el diagnóstico y el límite |

"Verde con aviso" es un aviso en GitHub y una etapa inestable en Jenkins. Un escenario cuyos `@AC-` tienen tipos distintos, o que no tiene fila, cuenta como rojo si termina con error. Además, la ejecución queda en **rojo** siempre que no mida la cuarentena, aunque el error sea de un `inestable`: Maven no compila, no hay reporte, el rc de Maven es inesperado o no cuadra con el reporte, se ejecutan cero escenarios o un escenario no tiene fila. La cuarentena es la **única** vía para sacar un escenario de la suite que bloquea (P-05), y cada uno necesita una fila en este registro. `scripts/check-quarantine.sh` lo comprueba en cada ejecución del CI.

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
