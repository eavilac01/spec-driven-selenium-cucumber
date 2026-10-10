# Spec — Login

| Campo | Valor |
|---|---|
| Estado | aprobada |
| Aprobada por | Eduardo Avila Carranza, 2026-10-10 |
| Último cambio | Alineación editorial con los escenarios y claves implementados (2026-10-10); sin cambios de comportamiento |
| Feature | `src/test/resources/features/login.feature` |

## Objetivo
Proteger el acceso al catálogo: solo un cliente con credenciales vigentes y una cuenta habilitada accede; cualquier otro intento se rechaza informando el motivo, y sin sesión iniciada no se accede al catálogo. Spec retroactiva: formaliza el comportamiento que la feature ya verifica (AC-LOGIN-01 a 03) y los criterios adicionales cuyos valores esperados el usuario ratificó el 2026-10-10 (AC-LOGIN-04 a 09). Todos los AC cuentan con su escenario en la feature.

## Reglas de negocio
- RN-1: un cliente con credenciales válidas y cuenta habilitada accede al catálogo de productos.
- RN-2: un cliente con cuenta bloqueada no accede, aunque sus credenciales sean correctas, y recibe el mensaje de bloqueo.
- RN-3: una contraseña que no corresponde al usuario no da acceso y recibe el mensaje de credenciales no coincidentes.
- RN-4: un usuario inexistente no accede y recibe el mismo mensaje de credenciales no coincidentes que una contraseña incorrecta.
- RN-5: las credenciales incompletas no dan acceso. El usuario se valida antes que la contraseña: si falta el usuario (con o sin contraseña) el mensaje es el del usuario obligatorio; si solo falta la contraseña, el de la contraseña obligatoria.
- RN-6: sin sesión iniciada no se accede al catálogo: el cliente vuelve al inicio de sesión y recibe el mensaje de acceso restringido.
- RN-7: un cliente con sesión iniciada puede cerrarla; al cerrarla vuelve al inicio de sesión y pierde el acceso al catálogo hasta autenticarse de nuevo, con el mismo mensaje de acceso restringido de RN-6.

## Valores esperados y datos de prueba (fuente de verdad)
Los valores esperados y los datos de prueba no sensibles se escriben literales en esta spec; las credenciales no (viven en secretos y no figuran aquí). Los **datos de entrada** y los **valores esperados** se declaran por separado: un esperado nunca se deriva de la entrada, para que un resultado incorrecto pueda detectarse.

### Datos de entrada

| Referencia | Valor literal |
|---|---|
| Credenciales de la cuenta estándar, la bloqueada y la contraseña válida (AC-LOGIN-01, 02, 03, 05, 06 y 09) | Sin valor en esta spec: salen de los secretos existentes |
| Usuario inexistente (AC-LOGIN-04), sintético y no sensible | `nonexistent_user` |
| Contraseña del usuario inexistente (AC-LOGIN-04) y del usuario vacío (AC-LOGIN-05) | Sin valor en esta spec: la contraseña válida de la cuenta estándar, de los secretos existentes |
| Usuario vacío (AC-LOGIN-05 y 07) / contraseña vacía (AC-LOGIN-06 y 07) | Texto vacío (sin valor) |
| Solicitud directa del catálogo sin sesión (AC-LOGIN-08 y 09) | El catálogo; la ruta ya existe en la configuración de navegación (`route.inventory`) |

### Valores esperados

| Referencia | Valor esperado literal |
|---|---|
| Título del catálogo tras un acceso exitoso (AC-LOGIN-01) | `Products` |
| Mensaje de rechazo por cuenta bloqueada (AC-LOGIN-02) | `Epic sadface: Sorry, this user has been locked out.` |
| Mensaje de rechazo por credenciales no coincidentes (AC-LOGIN-03) | `Epic sadface: Username and password do not match any user in this service` |
| Mensaje de rechazo por usuario inexistente (AC-LOGIN-04) | `Epic sadface: Username and password do not match any user in this service` |
| Mensaje de rechazo por usuario obligatorio (AC-LOGIN-05) | `Epic sadface: Username is required` |
| Mensaje de rechazo por contraseña obligatoria (AC-LOGIN-06) | `Epic sadface: Password is required` |
| Mensaje de rechazo con usuario y contraseña vacíos (AC-LOGIN-07) | `Epic sadface: Username is required` |
| Mensaje al solicitar el catálogo sin sesión (AC-LOGIN-08 y 09) | `Epic sadface: You can only access '/inventory.html' when you are logged in.` |

`src/test/resources/config.properties` debe coincidir con estos valores. Si difieren, prevalece la spec (SDD-03).

Claves de esperado, independientes de las de entrada:
- Existentes: `inventory.expected.title`, `test.login.cases.locked-user.expected-error` y `test.login.cases.invalid-password.expected-error`.
- Nuevas: `test.login.cases.nonexistent-user.expected-error`, `test.login.cases.empty-username.expected-error`, `test.login.cases.empty-password.expected-error`, `test.login.cases.empty-both.expected-error` y `test.login.cases.anonymous-access.expected-error` (compartida por AC-LOGIN-08 y 09).

Claves de entrada nuevas (no sensibles): `test.login.cases.nonexistent-user.username`. El usuario vacío y la contraseña vacía no requieren clave. La contraseña válida de AC-LOGIN-04 y 05 y el usuario válido de AC-LOGIN-06 reutilizan los secretos existentes de la cuenta estándar.

## Criterios de aceptación

| ID | Criterio (Dado/Cuando/Entonces resumido) | Verificable | Técnica(s) | Escenarios |
|---|---|---|---|---|
| AC-LOGIN-01 | Dado un cliente con credenciales estándar válidas, cuando inicia sesión, entonces accede al catálogo cuyo título es `Products` | sí | equivalencia (partición válida) | `login.feature @AC-LOGIN-01` |
| AC-LOGIN-02 | Dado un cliente con cuenta bloqueada, cuando intenta iniciar sesión, entonces el acceso es rechazado con el mensaje `Epic sadface: Sorry, this user has been locked out.` | sí | equivalencia (inválida: cuenta bloqueada) · decision (usuario bloqueado + contraseña correcta) | `login.feature @AC-LOGIN-02` |
| AC-LOGIN-03 | Dado un cliente con contraseña incorrecta, cuando intenta iniciar sesión, entonces el acceso es rechazado con el mensaje `Epic sadface: Username and password do not match any user in this service` | sí | equivalencia (inválida: contraseña incorrecta) · decision (usuario habilitado + contraseña incorrecta) | `login.feature @AC-LOGIN-03` |
| AC-LOGIN-04 | Dado un usuario inexistente con una contraseña válida de otra cuenta, cuando intenta iniciar sesión, entonces el acceso es rechazado con el mensaje `Epic sadface: Username and password do not match any user in this service` (el mismo que AC-LOGIN-03) | sí (valor esperado literal en la sección de valores esperados) | equivalencia (inválida: usuario inexistente) · decision (R4) | `login.feature @AC-LOGIN-04` |
| AC-LOGIN-05 | Dado un intento sin usuario y con contraseña válida, cuando intenta iniciar sesión, entonces el acceso es rechazado con el mensaje `Epic sadface: Username is required` | sí | equivalencia (inválida: usuario vacío) · decision (R5) | `login.feature @AC-LOGIN-05` |
| AC-LOGIN-06 | Dado un intento con usuario habilitado y sin contraseña, cuando intenta iniciar sesión, entonces el acceso es rechazado con el mensaje `Epic sadface: Password is required` | sí | equivalencia (inválida: contraseña vacía) · decision (R6) | `login.feature @AC-LOGIN-06` |
| AC-LOGIN-07 | Dado un intento sin usuario ni contraseña, cuando intenta iniciar sesión, entonces el acceso es rechazado con el mensaje `Epic sadface: Username is required` (el usuario se valida primero) | sí | decision (R7: regla explícita de ambos vacíos) | `login.feature @AC-LOGIN-07` |
| AC-LOGIN-08 | Dado un cliente sin sesión iniciada, cuando solicita directamente el catálogo, entonces no accede, vuelve al inicio de sesión y recibe el mensaje `Epic sadface: You can only access '/inventory.html' when you are logged in.` | sí | estados (transición inválida: anónimo → catálogo) | `login.feature @AC-LOGIN-08` |
| AC-LOGIN-09 | Dado un cliente con sesión iniciada, cuando cierra sesión, entonces vuelve al inicio de sesión; y cuando después solicita directamente el catálogo, no accede y recibe el mensaje `Epic sadface: You can only access '/inventory.html' when you are logged in.` | sí | estados (transición válida: autenticado → anónimo; transición inválida posterior: anónimo → catálogo) | `login.feature @AC-LOGIN-09` |

Cobertura de caminos no felices: AC-LOGIN-01 (camino feliz) queda contrastado por AC-LOGIN-02 y AC-LOGIN-03, ya automatizados, y por AC-LOGIN-04 a 08, todos caminos de rechazo, también automatizados. AC-LOGIN-09 contiene una transición válida (cierre de sesión) y una inválida (acceso posterior al catálogo). Todos los AC de rechazo cuentan con su contraste: no hay AC de solo camino feliz sin contraparte negativa.

## Datos y fronteras
Tabla de decisión de autenticación (una regla = una fila de `Examples` o un escenario; nunca se combinan dos particiones inválidas en un mismo caso, salvo la regla explícita R7):

| Regla | Usuario | Contraseña | Resultado esperado | AC |
|---|---|---|---|---|
| R1 | habilitado | correcta | acceso al catálogo (`Products`) | AC-LOGIN-01 |
| R2 | bloqueado | correcta | rechazo: `Epic sadface: Sorry, this user has been locked out.` | AC-LOGIN-02 |
| R3 | habilitado | incorrecta | rechazo: `Epic sadface: Username and password do not match any user in this service` | AC-LOGIN-03 |
| R4 | inexistente | válida de otra cuenta | rechazo: `Epic sadface: Username and password do not match any user in this service` | AC-LOGIN-04 |
| R5 | vacío | válida | rechazo: `Epic sadface: Username is required` | AC-LOGIN-05 |
| R6 | habilitado | vacía | rechazo: `Epic sadface: Password is required` | AC-LOGIN-06 |
| R7 | vacío | vacía | rechazo: `Epic sadface: Username is required` | AC-LOGIN-07 |

Nota de diseño: R4 y R5 usan una contraseña válida de otra cuenta para que la única partición inválida sea el usuario (una partición inválida por caso).

Transiciones de estados de la sesión (cada estado con al menos una transición inválida):

| Estado de origen | Evento | Estado de destino / resultado | Tipo | AC |
|---|---|---|---|---|
| anónimo | inicio de sesión con credenciales válidas | autenticado, con acceso al catálogo | válida | AC-LOGIN-01 |
| anónimo | solicitud directa del catálogo | sigue anónimo, vuelve al inicio de sesión con el mensaje de acceso restringido | inválida | AC-LOGIN-08 |
| autenticado | cierre de sesión | anónimo, en el inicio de sesión | válida | AC-LOGIN-09 |
| anónimo (tras cerrar sesión) | solicitud directa del catálogo | sigue anónimo, vuelve al inicio de sesión con el mensaje de acceso restringido | inválida | AC-LOGIN-09 |

| Dato | Particiones válidas | Particiones inválidas | Fronteras (incluido el límite exacto) |
|---|---|---|---|
| Usuario (credenciales por caso; los valores reales viven en secretos, no en esta spec) | cuenta estándar habilitada | cuenta bloqueada · usuario inexistente · vacío | No aplica: dato categórico sin rango numérico ni de longitud |
| Contraseña | la que corresponde al usuario | incorrecta · vacía | No aplica: la spec no define reglas de longitud ni complejidad (ver *Fuera de alcance*) |
| Sesión | autenticada | anónima | No aplica |

Técnica de pares: no aplica, solo hay dos parámetros (usuario, contraseña) y la tabla de decisión ya los cubre de forma exhaustiva.

## No cubiertos
Ninguno. Los AC-LOGIN-04 a 09 dejaron de estar aquí porque el usuario ratificó sus valores esperados el 2026-10-10 (Q-2, Q-3, Q-4, Q-6, Q-7 y Q-8 resueltas) y ya cuentan con sus escenarios.

## Fuera de alcance
- Recuperación o cambio de contraseña, registro de usuarios y autenticación de múltiples factores: el sistema bajo prueba no los ofrece.
- Reglas de longitud o complejidad de la contraseña (Q-5, retirada el 2026-10-10): el sistema bajo prueba no tiene registro ni cambio de contraseña, así que no hay regla que acote ni fronteras que diseñar.
- Compra y carrito (ver `docs/specs/compra.md`).
- Rendimiento, accesibilidad y compatibilidad entre navegadores.
