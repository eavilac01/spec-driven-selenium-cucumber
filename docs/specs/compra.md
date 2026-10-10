# Spec — Compra

| Campo | Valor |
|---|---|
| Estado | aprobada |
| Aprobada por | Eduardo Avila Carranza, 2026-10-10 |
| Último cambio | Alineación editorial con los escenarios y claves implementados (2026-10-10); sin cambios de comportamiento |
| Feature | `src/test/resources/features/compra_e2e.feature` |

## Objetivo
Proteger el flujo de compra de un cliente autenticado: selección de productos, revisión del carrito, datos de envío y confirmación del pedido. Spec retroactiva: formaliza los escenarios existentes (AC-COMPRA-01 a 04) y los criterios adicionales cuyos valores esperados el usuario ratificó el 2026-10-10 (AC-COMPRA-05 a 13). Todos los AC cuentan con su escenario en la feature.

## Reglas de negocio
- RN-1: el contador del carrito refleja la cantidad de productos seleccionados; con el carrito sin productos el contador no se muestra (no aparece en 0).
- RN-2: el carrito contiene exactamente los productos seleccionados, en el orden en que se agregaron.
- RN-3: con datos de envío completos (nombre, apellido, código postal) el cliente completa la compra y recibe la confirmación del pedido.
- RN-4: el catálogo ofrece exactamente 6 productos distintos, por lo que el carrito admite entre 0 y 6 productos. Con los 6 en el carrito no quedan productos por agregar.
- RN-5: nombre, apellido y código postal son obligatorios para continuar con la compra; cada ausencia se informa con su propio mensaje.
- RN-6: el cliente puede quitar un producto del carrito antes de comprar; el contador baja en uno y, si era el único, deja de mostrarse.
- RN-7 (regla de negocio vigente; el sistema bajo prueba hoy no la cumple, ver *Defecto conocido*): no se debe permitir tramitar la compra con el carrito sin productos.
- RN-8: tras confirmar una compra, el carrito queda sin productos.

## Valores esperados y datos de prueba (fuente de verdad)
Los valores esperados y los datos de prueba no sensibles se escriben literales en esta spec. Las credenciales no figuran aquí (viven en secretos). Los **datos de entrada** y los **valores esperados** se declaran por separado: un esperado nunca se deriva de la entrada, para que un resultado incorrecto pueda detectarse.

### Catálogo (ratificado el 2026-10-10)
El catálogo tiene exactamente 6 productos, en este orden:
1. `Sauce Labs Backpack`
2. `Sauce Labs Bike Light`
3. `Sauce Labs Bolt T-Shirt`
4. `Sauce Labs Fleece Jacket`
5. `Sauce Labs Onesie`
6. `Test.allTheThings() T-Shirt (Red)`

### Datos de entrada

| Referencia | Valor literal |
|---|---|
| Productos de la compra, en este orden (AC-COMPRA-01, 02, 03 y 13) | `Sauce Labs Backpack`, `Sauce Labs Bike Light` |
| Producto único (AC-COMPRA-04, 08 segundo caso, 10, 11 y 12) | `Sauce Labs Backpack` |
| Cinco productos, en el orden del catálogo (AC-COMPRA-06) | `Sauce Labs Backpack`, `Sauce Labs Bike Light`, `Sauce Labs Bolt T-Shirt`, `Sauce Labs Fleece Jacket`, `Sauce Labs Onesie` |
| Seis productos, en el orden del catálogo (AC-COMPRA-07) | Los 6 del catálogo, en su orden |
| Producto que se quita (AC-COMPRA-08 primer caso: con los dos productos de la compra) | `Sauce Labs Bike Light` |
| Carrito sin productos (AC-COMPRA-05 y 09) | Ningún producto agregado |
| Nombre de envío (AC-COMPRA-03, 11 y 12) | `Ada` |
| Apellido de envío (AC-COMPRA-03, 10 y 12) | `Lovelace` |
| Código postal de envío (AC-COMPRA-03, 10 y 11) | `01000` |
| Nombre, apellido o código postal vacío (AC-COMPRA-10, 11 y 12, respectivamente) | Texto vacío (sin valor); los otros dos datos van informados |

### Valores esperados

| Referencia | Valor esperado literal |
|---|---|
| Título del catálogo (cliente autenticado) | `Products` |
| Contador del carrito con los dos productos (AC-COMPRA-01) | `2` |
| Contenido del carrito, en orden (AC-COMPRA-02) | `Sauce Labs Backpack`, `Sauce Labs Bike Light` |
| Mensaje de confirmación del pedido (AC-COMPRA-03) | `Thank you for your order!` |
| Contador del carrito con el producto único (AC-COMPRA-04) | `1` |
| Contenido del carrito con el producto único (AC-COMPRA-04) | `Sauce Labs Backpack` |
| Contador del carrito sin productos (AC-COMPRA-05, 08 segundo caso y 13) | No se muestra (no aparece en 0) |
| Contenido del carrito sin productos (AC-COMPRA-05, 08 segundo caso y 13) | Sin productos |
| Cantidad de productos del catálogo (AC-COMPRA-06 y 07) | `6` |
| Productos del catálogo, en orden (AC-COMPRA-06 y 07) | Los 6 de la sección *Catálogo* |
| Contador del carrito con cinco productos (AC-COMPRA-06) | `5` |
| Contenido del carrito con cinco productos, en orden (AC-COMPRA-06) | Los 5 primeros del catálogo |
| Contador del carrito con seis productos (AC-COMPRA-07) | `6` |
| Contenido del carrito con seis productos, en orden (AC-COMPRA-07) | Los 6 del catálogo |
| Productos del catálogo que quedan por agregar con seis en el carrito (AC-COMPRA-07) | Ninguno |
| Contador tras quitar un producto de dos (AC-COMPRA-08 primer caso) | `1` |
| Contenido del carrito tras quitar un producto de dos (AC-COMPRA-08 primer caso) | `Sauce Labs Backpack` |
| Resultado de tramitar la compra con el carrito sin productos (AC-COMPRA-09) | No avanza a los datos de envío (sin mensaje esperado definido) |
| Mensaje por nombre vacío (AC-COMPRA-10) | `Error: First Name is required` |
| Mensaje por apellido vacío (AC-COMPRA-11) | `Error: Last Name is required` |
| Mensaje por código postal vacío (AC-COMPRA-12) | `Error: Postal Code is required` |

`src/test/resources/config.properties` debe coincidir con estos valores. Si difieren, prevalece la spec (SDD-03).

**Claves de entrada.**
- Existentes: `test.purchase.products`, `test.purchase.single-product`, `test.checkout.first-name`, `test.checkout.last-name` y `test.checkout.postal-code`.
- Nuevas: `test.purchase.five-products` (AC-COMPRA-06), `test.purchase.all-products` (AC-COMPRA-07) y `test.purchase.removed-product` (AC-COMPRA-08). Los datos de envío vacíos no requieren clave.

**Claves de esperado**, independientes de las de entrada.
- Existentes: `inventory.expected.title`, `cart.expected.count`, `cart.expected.products`, `cart.expected.single-product.count`, `cart.expected.single-product.products` y `checkout.expected.confirmation`.
- Nuevas, del catálogo: `catalog.expected.count`, `catalog.expected.products` y `catalog.expected.remaining-to-add` (valor `0`: no quedan productos por agregar con seis en el carrito, AC-COMPRA-07).
- Nuevas, del carrito: `cart.expected.five-products.count`, `cart.expected.five-products.products`, `cart.expected.all-products.count`, `cart.expected.all-products.products`, `cart.expected.after-removal.count`, `cart.expected.after-removal.products`, `cart.expected.empty.counter-displayed` (valor `false`) y `cart.expected.empty.count` (valor `0`: carrito sin productos; la configuración no admite valores vacíos).
- Nuevas, de la compra: `checkout.expected.empty-cart.advances` (valor `false`), `checkout.expected.errors.first-name`, `checkout.expected.errors.last-name` y `checkout.expected.errors.postal-code`.

## Criterios de aceptación

| ID | Criterio (Dado/Cuando/Entonces resumido) | Verificable | Técnica(s) | Escenarios |
|---|---|---|---|---|
| AC-COMPRA-01 | Dado un cliente autenticado, cuando agrega `Sauce Labs Backpack` y `Sauce Labs Bike Light` (2 productos), entonces el contador del carrito muestra 2 | sí | equivalencia (partición válida: varios productos) | `compra_e2e.feature @AC-COMPRA-01` |
| AC-COMPRA-02 | Dado un cliente que agregó productos, cuando revisa el carrito, entonces contiene exactamente los productos seleccionados, en el mismo orden | sí | equivalencia | `compra_e2e.feature @AC-COMPRA-02` |
| AC-COMPRA-03 | Dado un cliente con productos en el carrito, cuando completa los datos de envío (`Ada`, `Lovelace`, `01000`) y finaliza, entonces la compra se confirma con el mensaje `Thank you for your order!` | sí | equivalencia (partición válida: datos completos) | `compra_e2e.feature @AC-COMPRA-03` |
| AC-COMPRA-04 | Dado un cliente autenticado, cuando agrega 1 producto (mínimo con producto), entonces el contador muestra 1 y el carrito contiene solo ese producto | sí (valores esperados literales en la sección de valores esperados) | frontera (mínimo+1 = 1) | `compra_e2e.feature @AC-COMPRA-04` |
| AC-COMPRA-05 | Dado un cliente autenticado sin productos agregados (0, mínimo), entonces el contador del carrito no se muestra (no aparece en 0) y el carrito no contiene productos | sí | frontera (mínimo = 0) | `compra_e2e.feature @AC-COMPRA-05` |
| AC-COMPRA-06 | Dado un cliente autenticado, cuando agrega 5 productos (máximo−1), entonces el contador muestra 5 y el carrito contiene los 5 en el orden en que se agregaron | sí | frontera (máximo−1 = 5) | `compra_e2e.feature @AC-COMPRA-06` |
| AC-COMPRA-07 | Dado un cliente autenticado, cuando agrega 6 productos (máximo, todo el catálogo), entonces el contador muestra 6, el carrito contiene los 6 en el orden en que se agregaron y no quedan productos por agregar | sí | frontera (máximo = 6) | `compra_e2e.feature @AC-COMPRA-07` |
| AC-COMPRA-08 | Dado un cliente con productos en el carrito, cuando quita uno, entonces el contador baja en uno y el carrito deja de contenerlo; si era el único, el contador deja de mostrarse | sí | estados (transición válida: producto agregado → quitado; dos casos: de 2 a 1 productos y de 1 a 0) | `compra_e2e.feature @AC-COMPRA-08` |
| AC-COMPRA-09 | Dado un cliente con el carrito sin productos, cuando intenta tramitar la compra, entonces no avanza a los datos de envío (regla de negocio RN-7). Defecto conocido del sistema bajo prueba: hoy sí avanza, sin mensaje. Escenario en cuarentena (`@quarantine`) | sí | estados (transición inválida: carrito vacío → pago) · frontera (0) | `compra_e2e.feature @AC-COMPRA-09` y `@quarantine (defecto-sut)` |
| AC-COMPRA-10 | Dado un cliente que tramita la compra con apellido y código postal informados y sin nombre, entonces no continúa y recibe el mensaje `Error: First Name is required` | sí | equivalencia (inválida: nombre vacío) · decision (R2) | `compra_e2e.feature @AC-COMPRA-10` |
| AC-COMPRA-11 | Dado un cliente que tramita la compra con nombre y código postal informados y sin apellido, entonces no continúa y recibe el mensaje `Error: Last Name is required` | sí | equivalencia (inválida: apellido vacío) · decision (R3) | `compra_e2e.feature @AC-COMPRA-11` |
| AC-COMPRA-12 | Dado un cliente que tramita la compra con nombre y apellido informados y sin código postal, entonces no continúa y recibe el mensaje `Error: Postal Code is required` | sí | equivalencia (inválida: código postal vacío) · decision (R4) | `compra_e2e.feature @AC-COMPRA-12` |
| AC-COMPRA-13 | Dado un cliente que completó una compra, entonces el carrito queda sin productos: el contador no se muestra y no contiene productos | sí | estados (transición válida: compra confirmada → carrito vacío) | `compra_e2e.feature @AC-COMPRA-13` |

Cobertura de caminos no felices: AC-COMPRA-01, 02 y 03 son camino feliz. Su contraste son los AC-COMPRA-05 (carrito sin productos), 09 (carrito vacío no puede tramitar), 10, 11 y 12 (datos de envío incompletos), todos con valor esperado ratificado y ya automatizados. AC-COMPRA-04, 06 y 07 son fronteras de cantidad; AC-COMPRA-08 y 13 son transiciones de estado del carrito.

## Defecto conocido del sistema bajo prueba (AC-COMPRA-09, SDD-08)
- **Regla de negocio (decisión del usuario, 2026-10-10):** no se debe permitir tramitar la compra con el carrito sin productos.
- **Comportamiento observado:** el sistema bajo prueba hoy lo permite; avanza a los datos de envío sin mostrar ningún mensaje.
- **Decisión:** el AC se mantiene verificable, con el resultado esperado "no avanza a los datos de envío". No se define un mensaje esperado ni se ajusta el valor esperado al comportamiento observado (SDD-03). Su escenario llevará `@quarantine` hasta que el sistema bajo prueba cambie, y el defecto se registra en `docs/quarantine.md` (archivo de `devops-engineer`, con dueño y fecha según CHK-14). Cuando el sistema se corrija, se retira la cuarentena.

## Datos y fronteras

| Dato | Particiones válidas | Particiones inválidas | Fronteras (incluido el límite exacto) |
|---|---|---|---|
| Productos en el carrito (catálogo de 6 productos, ratificado) | 1 a 6 productos | 0 productos (no se puede tramitar la compra, RN-7) | Mínimo−1 = −1 (inalcanzable); mínimo = 0 (AC-COMPRA-05); mínimo+1 = 1 (AC-COMPRA-04); máximo−1 = 5 (AC-COMPRA-06); máximo = 6 (AC-COMPRA-07); máximo+1 = 7 (inalcanzable: el catálogo tiene exactamente 6 productos y con 6 no quedan productos por agregar) |
| Nombre de envío | texto no vacío (`Ada`) | vacío | Solo se diseña vacío vs. no vacío: no hay regla de longitud observable (ver *Fuera de alcance*) |
| Apellido de envío | texto no vacío (`Lovelace`) | vacío | Ídem |
| Código postal de envío | `01000` | vacío | Ídem |

Reglas de decisión de los datos de envío (un escenario o una fila de `Examples` por regla; nunca dos datos vacíos en el mismo caso):

| Regla | Nombre | Apellido | Código postal | Resultado | AC |
|---|---|---|---|---|---|
| R1 | informado | informado | informado | compra continúa y se confirma: `Thank you for your order!` | AC-COMPRA-03 |
| R2 | vacío | informado | informado | no continúa: `Error: First Name is required` | AC-COMPRA-10 |
| R3 | informado | vacío | informado | no continúa: `Error: Last Name is required` | AC-COMPRA-11 |
| R4 | informado | informado | vacío | no continúa: `Error: Postal Code is required` | AC-COMPRA-12 |

Transiciones de estados del carrito:

| Estado de origen | Evento | Estado de destino / resultado | Tipo | AC |
|---|---|---|---|---|
| sin productos | agregar productos | con productos, contador acorde a la cantidad | válida | AC-COMPRA-01, 04, 06 y 07 |
| con 2 productos | quitar uno | con 1 producto, contador `1` | válida | AC-COMPRA-08 |
| con 1 producto | quitar el único | sin productos, contador no se muestra | válida | AC-COMPRA-08 |
| sin productos | tramitar la compra | no avanza a los datos de envío (RN-7) | inválida | AC-COMPRA-09 |
| compra confirmada | consultar el carrito | sin productos, contador no se muestra | válida | AC-COMPRA-13 |

Técnica de pares: no aplica; los tres datos de envío son independientes, pero las reglas R1 a R4 los cubren de forma exhaustiva por separado y no hay validaciones de formato que combinar.

## No cubiertos
Ninguno. Los AC-COMPRA-05 a 13 dejaron de estar aquí porque el usuario ratificó sus valores esperados el 2026-10-10 (Q-2, Q-3, Q-4, Q-5, Q-6, Q-7, Q-8 y Q-10 resueltas) y ya cuentan con sus escenarios. AC-COMPRA-09 se cubre con un escenario en cuarentena por el defecto conocido del sistema bajo prueba.

## Fuera de alcance
- Autenticación (ver `docs/specs/login.md`); aquí se asume un cliente ya autenticado.
- Formato y longitud de nombre, apellido y código postal (Q-9, retirada el 2026-10-10): el sistema bajo prueba no tiene validación de formato observable, así que no hay reglas que acoten ni fronteras que diseñar.
- Cálculo de importes, impuestos y totales del pedido, pagos y envío físico.
- Orden de presentación y filtros del catálogo.
- Rendimiento, accesibilidad y compatibilidad entre navegadores.
