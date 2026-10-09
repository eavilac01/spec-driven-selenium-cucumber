# Spec — Login

| Campo | Valor |
|---|---|
| Estado | aprobada |
| Aprobada por | Eduardo Avila Carranza, 2026-10-09 |
| Último cambio | Referencias a escenarios por archivo y tag en lugar de por línea; sin cambios de comportamiento (2026-10-09) |
| Feature | `src/test/resources/features/login.feature` |

## Objetivo
Proteger el acceso al catálogo: solo un cliente con credenciales vigentes y una cuenta habilitada accede; cualquier otro intento se rechaza informando el motivo. Spec retroactiva: formaliza el comportamiento que la feature ya verifica y propone criterios adicionales aún sin valor esperado confirmado.

## Reglas de negocio
- RN-1: un cliente con credenciales válidas y cuenta habilitada accede al catálogo de productos.
- RN-2: un cliente con cuenta bloqueada no accede, aunque sus credenciales sean correctas, y recibe el mensaje de bloqueo.
- RN-3: una contraseña que no corresponde al usuario no da acceso y recibe el mensaje de credenciales no coincidentes.
- RN-4 (supuesto, sin confirmar): las credenciales incompletas, o de un usuario inexistente, tampoco dan acceso.
- RN-5 (supuesto, sin confirmar): sin sesión iniciada no se puede acceder al catálogo.

## Valores esperados (fuente de verdad)
Los valores esperados se escriben literales en esta spec; las credenciales no (viven en secretos y no figuran aquí).

| Referencia | Valor esperado literal |
|---|---|
| Título del catálogo tras un acceso exitoso (AC-LOGIN-01) | `Products` |
| Mensaje de rechazo por cuenta bloqueada (AC-LOGIN-02) | `Epic sadface: Sorry, this user has been locked out.` |
| Mensaje de rechazo por credenciales no coincidentes (AC-LOGIN-03) | `Epic sadface: Username and password do not match any user in this service` |

`src/test/resources/config.properties` (claves `inventory.expected.title`, `test.login.cases.locked-user.expected-error` y `test.login.cases.invalid-password.expected-error`) debe coincidir con estos valores. Si difieren, prevalece la spec (SDD-03).

## Criterios de aceptación

| ID | Criterio (Dado/Cuando/Entonces resumido) | Verificable | Técnica(s) | Escenarios |
|---|---|---|---|---|
| AC-LOGIN-01 | Dado un cliente con credenciales estándar válidas, cuando inicia sesión, entonces accede al catálogo cuyo título es `Products` | sí | equivalencia (partición válida) | `login.feature @AC-LOGIN-01` |
| AC-LOGIN-02 | Dado un cliente con cuenta bloqueada, cuando intenta iniciar sesión, entonces el acceso es rechazado con el mensaje `Epic sadface: Sorry, this user has been locked out.` | sí | equivalencia (inválida: cuenta bloqueada) · decision (usuario bloqueado + contraseña correcta) | `login.feature @AC-LOGIN-02` |
| AC-LOGIN-03 | Dado un cliente con contraseña incorrecta, cuando intenta iniciar sesión, entonces el acceso es rechazado con el mensaje `Epic sadface: Username and password do not match any user in this service` | sí | equivalencia (inválida: contraseña incorrecta) · decision (usuario habilitado + contraseña incorrecta) | `login.feature @AC-LOGIN-03` |
| AC-LOGIN-04 | Dado un usuario inexistente, cuando intenta iniciar sesión, entonces el acceso es rechazado con un mensaje | no | equivalencia (inválida: usuario inexistente) · decision | — |
| AC-LOGIN-05 | Dado un intento sin usuario, cuando intenta iniciar sesión, entonces el acceso es rechazado con un mensaje que indica que el usuario es obligatorio | no | equivalencia (inválida: usuario vacío) · decision | — |
| AC-LOGIN-06 | Dado un intento sin contraseña, cuando intenta iniciar sesión, entonces el acceso es rechazado con un mensaje que indica que la contraseña es obligatoria | no | equivalencia (inválida: contraseña vacía) · decision | — |
| AC-LOGIN-07 | Dado un intento sin usuario ni contraseña, cuando intenta iniciar sesión, entonces el acceso es rechazado con un mensaje | no | decision (regla de ambos vacíos) | — |
| AC-LOGIN-08 | Dado un cliente sin sesión iniciada, cuando solicita directamente el catálogo, entonces no accede y se le exige autenticarse | no | estados (transición inválida: anónimo → catálogo) | — |
| AC-LOGIN-09 | Dado un cliente con sesión iniciada, cuando cierra sesión, entonces pierde el acceso al catálogo hasta autenticarse de nuevo | no | estados (transición válida: autenticado → anónimo) | — |

Cobertura de caminos no felices: AC-LOGIN-01 (camino feliz) queda contrastado por AC-LOGIN-02 y AC-LOGIN-03, ya automatizados. Los AC-LOGIN-04 a 09 amplían el diseño pero no tienen valor esperado confirmado.

## Datos y fronteras
Tabla de decisión de autenticación (una regla = una fila de `Examples` o un escenario; nunca se combinan dos particiones inválidas en un mismo caso, salvo la regla explícita de AC-LOGIN-07):

| Regla | Usuario | Contraseña | Resultado esperado | AC |
|---|---|---|---|---|
| R1 | habilitado | correcta | acceso al catálogo | AC-LOGIN-01 |
| R2 | bloqueado | correcta | rechazo por bloqueo | AC-LOGIN-02 |
| R3 | habilitado | incorrecta | rechazo por credenciales no coincidentes | AC-LOGIN-03 |
| R4 | inexistente | cualquiera | rechazo (mensaje sin confirmar) | AC-LOGIN-04 |
| R5 | vacío | cualquiera | rechazo (mensaje sin confirmar) | AC-LOGIN-05 |
| R6 | habilitado | vacía | rechazo (mensaje sin confirmar) | AC-LOGIN-06 |
| R7 | vacío | vacía | rechazo (mensaje sin confirmar) | AC-LOGIN-07 |

| Dato | Particiones válidas | Particiones inválidas | Fronteras (incluido el límite exacto) |
|---|---|---|---|
| Usuario (credenciales por caso; los valores reales viven en secretos, no en esta spec) | cuenta estándar habilitada | cuenta bloqueada · usuario inexistente · vacío | No aplica: dato categórico sin rango numérico ni de longitud conocido |
| Contraseña | la que corresponde al usuario | incorrecta · vacía | No aplica: sin regla de longitud conocida (ver Q-5) |
| Sesión | autenticada | anónima | No aplica |

Técnica de pares: no aplica, solo hay dos parámetros (usuario, contraseña) y la tabla de decisión ya los cubre de forma exhaustiva.

## No cubiertos
| ID | Motivo | Pregunta que lo desbloquea |
|---|---|---|
| AC-LOGIN-04 | Valor esperado no confirmado: el mensaje para un usuario inexistente no está en el repositorio | Q-2: ¿el mensaje de rechazo para un usuario inexistente es el mismo que el de contraseña incorrecta o es distinto? Indicar el texto exacto esperado. |
| AC-LOGIN-05 | Valor esperado no confirmado | Q-3: ¿cuál es el mensaje exacto esperado cuando falta el usuario? |
| AC-LOGIN-06 | Valor esperado no confirmado | Q-4: ¿cuál es el mensaje exacto esperado cuando falta la contraseña? |
| AC-LOGIN-07 | Valor esperado no confirmado; depende de la precedencia entre las dos validaciones | Q-6: cuando faltan usuario y contraseña a la vez, ¿qué mensaje se espera (el del usuario, el de la contraseña u otro)? |
| AC-LOGIN-08 | Resultado observable no confirmado: no se sabe si el sistema redirige al inicio de sesión ni con qué mensaje | Q-7: ¿qué debe ocurrir y qué mensaje (si lo hay) debe verse cuando un anónimo solicita el catálogo directamente? |
| AC-LOGIN-09 | Fuera de la evidencia del repositorio: no hay escenario ni valor esperado de cierre de sesión | Q-8: ¿el cierre de sesión forma parte del alcance de esta spec y qué resultado observable se espera? |

Preguntas generales (no ligadas a un AC):
- Q-5: ¿existe una regla de longitud o complejidad de la contraseña que deba tener fronteras?

## Fuera de alcance
- Recuperación o cambio de contraseña, registro de usuarios y autenticación de múltiples factores (no existen en el repositorio).
- Compra y carrito (ver `docs/specs/compra.md`).
- Rendimiento, accesibilidad y compatibilidad entre navegadores.
- Longitud o complejidad de las contraseñas (ver Q-5).
