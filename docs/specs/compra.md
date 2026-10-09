# Spec — Compra

| Campo | Valor |
|---|---|
| Estado | aprobada |
| Aprobada por | Eduardo Avila Carranza, 2026-10-09 |
| Último cambio | Valores esperados de carrito separados de la entrada; referencias por tag (2026-10-09) |
| Feature | `src/test/resources/features/compra_e2e.feature` |

## Objetivo
Proteger el flujo de compra de un cliente autenticado: selección de productos, revisión del carrito, datos de envío y confirmación del pedido. Spec retroactiva: formaliza el único escenario existente (compra de dos productos) y propone criterios adicionales cuyo valor esperado aún no está confirmado.

## Reglas de negocio
- RN-1: el contador del carrito refleja la cantidad de productos seleccionados.
- RN-2: el carrito contiene exactamente los productos seleccionados, en el orden en que se agregaron.
- RN-3: con datos de envío completos (nombre, apellido, código postal) el cliente completa la compra y recibe la confirmación del pedido.
- RN-4 (supuesto, sin confirmar): el catálogo ofrece 6 productos distintos, por lo que el carrito admite entre 0 y 6 productos.
- RN-5 (supuesto, sin confirmar): nombre, apellido y código postal son obligatorios para continuar con la compra.
- RN-6 (supuesto, sin confirmar): el cliente puede quitar un producto del carrito antes de comprar.

## Valores esperados y datos de prueba (fuente de verdad)
Los valores esperados y los datos de prueba no sensibles se escriben literales en esta spec. Las credenciales no figuran aquí (viven en secretos). Los **datos de entrada** y los **valores esperados** se declaran por separado: un esperado nunca se deriva de la entrada, para que un resultado incorrecto pueda detectarse.

### Datos de entrada

| Referencia | Valor literal |
|---|---|
| Productos de la compra, en este orden (AC-COMPRA-01, 02 y 03) | `Sauce Labs Backpack`, `Sauce Labs Bike Light` |
| Producto único (AC-COMPRA-04) | `Sauce Labs Backpack` |
| Nombre de envío (AC-COMPRA-03) | `Ada` |
| Apellido de envío (AC-COMPRA-03) | `Lovelace` |
| Código postal de envío (AC-COMPRA-03) | `01000` |

### Valores esperados

| Referencia | Valor esperado literal |
|---|---|
| Título del catálogo (cliente autenticado) | `Products` |
| Contador del carrito con los dos productos (AC-COMPRA-01) | `2` |
| Contenido del carrito, en orden (AC-COMPRA-02) | `Sauce Labs Backpack`, `Sauce Labs Bike Light` |
| Contador del carrito con el producto único (AC-COMPRA-04) | `1` |
| Contenido del carrito con el producto único (AC-COMPRA-04) | `Sauce Labs Backpack` |
| Mensaje de confirmación del pedido (AC-COMPRA-03) | `Thank you for your order!` |

`src/test/resources/config.properties` debe coincidir con estos valores. Si difieren, prevalece la spec (SDD-03). Claves de entrada: `test.purchase.products`, `test.purchase.single-product`, `test.checkout.first-name`, `test.checkout.last-name` y `test.checkout.postal-code`. Claves de esperado, independientes de las de entrada: `inventory.expected.title`, `cart.expected.count`, `cart.expected.products`, `cart.expected.single-product.count`, `cart.expected.single-product.products` y `checkout.expected.confirmation`.

## Criterios de aceptación

| ID | Criterio (Dado/Cuando/Entonces resumido) | Verificable | Técnica(s) | Escenarios |
|---|---|---|---|---|
| AC-COMPRA-01 | Dado un cliente autenticado, cuando agrega `Sauce Labs Backpack` y `Sauce Labs Bike Light` (2 productos), entonces el contador del carrito muestra 2 | sí | equivalencia (partición válida: varios productos) | `compra_e2e.feature @AC-COMPRA-01` |
| AC-COMPRA-02 | Dado un cliente que agregó productos, cuando revisa el carrito, entonces contiene exactamente los productos seleccionados, en el mismo orden | sí | equivalencia | `compra_e2e.feature @AC-COMPRA-02` |
| AC-COMPRA-03 | Dado un cliente con productos en el carrito, cuando completa los datos de envío (`Ada`, `Lovelace`, `01000`) y finaliza, entonces la compra se confirma con el mensaje `Thank you for your order!` | sí | equivalencia (partición válida: datos completos) | `compra_e2e.feature @AC-COMPRA-03` |
| AC-COMPRA-04 | Dado un cliente autenticado, cuando agrega 1 producto (mínimo con producto), entonces el contador muestra 1 y el carrito contiene solo ese producto | sí (valores esperados literales en la sección de valores esperados) | frontera (mínimo = 1) | `compra_e2e.feature @AC-COMPRA-04` |
| AC-COMPRA-05 | Dado un cliente autenticado sin productos (0, mínimo), entonces el contador del carrito refleja la ausencia de productos | no | frontera (mínimo = 0) | — |
| AC-COMPRA-06 | Dado un cliente autenticado, cuando agrega 5 productos (máximo−1), entonces el contador muestra 5 y el carrito contiene los 5 | no | frontera (máximo−1 = 5, supuesto) | — |
| AC-COMPRA-07 | Dado un cliente autenticado, cuando agrega 6 productos (máximo, todo el catálogo), entonces el contador muestra 6 y el carrito contiene los 6 | no | frontera (máximo = 6, supuesto) | — |
| AC-COMPRA-08 | Dado un cliente con productos en el carrito, cuando quita uno, entonces el contador disminuye en uno y el carrito deja de contenerlo | no | estados (transición válida: producto agregado → quitado) | — |
| AC-COMPRA-09 | Dado un cliente con el carrito sin productos, cuando intenta tramitar la compra, entonces se aplica la regla de negocio definida para el carrito vacío | no | estados (transición inválida: carrito vacío → pago) · frontera (0) | — |
| AC-COMPRA-10 | Dado un cliente que tramita la compra sin nombre, entonces no continúa y recibe un mensaje que indica que el nombre es obligatorio | no | equivalencia (inválida: nombre vacío) · decision | — |
| AC-COMPRA-11 | Dado un cliente que tramita la compra sin apellido, entonces no continúa y recibe un mensaje que indica que el apellido es obligatorio | no | equivalencia (inválida: apellido vacío) · decision | — |
| AC-COMPRA-12 | Dado un cliente que tramita la compra sin código postal, entonces no continúa y recibe un mensaje que indica que el código postal es obligatorio | no | equivalencia (inválida: código postal vacío) · decision | — |
| AC-COMPRA-13 | Dado un cliente que completó una compra, entonces el carrito queda sin productos | no | estados (transición válida: compra confirmada → carrito vacío) | — |

Cobertura de caminos no felices: AC-COMPRA-01, 02 y 03 son camino feliz y el repositorio no tiene hoy ningún escenario negativo de compra. Su contraste son los AC-COMPRA-05, 09, 10, 11 y 12, que quedan en *No cubiertos* hasta confirmar sus valores esperados; mientras tanto el riesgo se registra, no se cubre con casos inventados. El AC-COMPRA-04 (frontera inferior) es verificable y ya tiene su escenario.

## Datos y fronteras

| Dato | Particiones válidas | Particiones inválidas | Fronteras (incluido el límite exacto) |
|---|---|---|---|
| Productos en el carrito (supuesto: catálogo de 6 productos, no respaldado por el repositorio; solo hay 2 productos de prueba configurados) | 1 a 6 productos | 0 productos (a confirmar si es inválido para comprar) | Mínimo−1 = −1 (inalcanzable); mínimo = 0 (AC-COMPRA-05); mínimo+1 = 1 (AC-COMPRA-04); máximo−1 = 5 (AC-COMPRA-06); máximo = 6 (AC-COMPRA-07); máximo+1 = 7 (inalcanzable: el catálogo no ofrece un séptimo producto, a confirmar) |
| Nombre de envío | texto no vacío (`Ada`) | vacío | Longitud mínima y máxima no definidas (Q-9); solo se diseña vacío vs. no vacío |
| Apellido de envío | texto no vacío (`Lovelace`) | vacío | Ídem (Q-9) |
| Código postal de envío | `01000` | vacío | Formato y longitud no definidos (Q-9) |

Reglas de decisión de los datos de envío (un escenario o una fila de `Examples` por regla; nunca dos datos vacíos en el mismo caso):

| Regla | Nombre | Apellido | Código postal | Resultado | AC |
|---|---|---|---|---|---|
| R1 | informado | informado | informado | compra continúa y se confirma | AC-COMPRA-03 |
| R2 | vacío | informado | informado | no continúa, mensaje de nombre obligatorio | AC-COMPRA-10 |
| R3 | informado | vacío | informado | no continúa, mensaje de apellido obligatorio | AC-COMPRA-11 |
| R4 | informado | informado | vacío | no continúa, mensaje de código postal obligatorio | AC-COMPRA-12 |

Técnica de pares: no aplica por ahora; los tres datos de envío son independientes, pero las reglas R1 a R4 los cubren de forma exhaustiva por separado. Se reevaluará si se confirman validaciones de formato (Q-9).

## No cubiertos
| ID | Motivo | Pregunta que lo desbloquea |
|---|---|---|
| AC-COMPRA-05 | Valor esperado no confirmado: no se sabe qué refleja el contador sin productos | Q-2: con el carrito sin productos, ¿el contador debe verse con el valor 0 o no debe mostrarse? |
| AC-COMPRA-06 | Valor esperado no confirmado: solo hay 2 productos de prueba conocidos y el tamaño del catálogo es un supuesto | Q-3: ¿el catálogo tiene exactamente 6 productos? Indicar sus nombres exactos para configurar los datos de prueba. |
| AC-COMPRA-07 | Ídem AC-COMPRA-06; la frontera superior depende del tamaño del catálogo | Q-3 (misma pregunta) |
| AC-COMPRA-08 | Valor esperado no confirmado: el repositorio no demuestra el comportamiento de quitar productos | Q-4: ¿quitar un producto del carrito es parte del alcance, y qué contador y contenido se esperan después? |
| AC-COMPRA-09 | Valor esperado no confirmado: no se sabe si el sistema impide o permite tramitar un carrito sin productos | Q-5: ¿se debe impedir la compra con carrito vacío? Si sí, ¿con qué resultado observable y mensaje exacto? |
| AC-COMPRA-10 | Valor esperado no confirmado: el mensaje de nombre obligatorio no está en el repositorio | Q-6: ¿cuál es el mensaje exacto esperado cuando falta el nombre? |
| AC-COMPRA-11 | Ídem | Q-7: ¿cuál es el mensaje exacto esperado cuando falta el apellido? |
| AC-COMPRA-12 | Ídem | Q-8: ¿cuál es el mensaje exacto esperado cuando falta el código postal? |
| AC-COMPRA-13 | Resultado observable no confirmado | Q-10: tras confirmar la compra, ¿el carrito debe quedar sin productos y cómo se observa (contador ausente o en 0)? |

Preguntas generales (no ligadas a un AC):
- Q-9: ¿existen reglas de longitud o de formato para nombre, apellido y código postal que deban tener fronteras?

## Fuera de alcance
- Autenticación (ver `docs/specs/login.md`); aquí se asume un cliente ya autenticado.
- Cálculo de importes, impuestos y totales del pedido, pagos y envío físico.
- Orden de presentación y filtros del catálogo.
- Rendimiento, accesibilidad y compatibilidad entre navegadores.
