Feature: Autenticación de usuarios
  Como cliente de SauceDemo
  Quiero autenticarme con mis credenciales
  Para acceder de forma segura al catálogo

  Spec: docs/specs/login.md

  Background:
    Given que el usuario abre la página de inicio de sesión

  @smoke @AC-LOGIN-01 @tec-equivalencia
  Scenario: Inicio de sesión exitoso
    When inicia sesión con las credenciales estándar configuradas
    Then accede al inventario

  Scenario Outline: Rechazo de credenciales no autorizadas
    When intenta iniciar sesión con el caso configurado <caso>
    Then el acceso es rechazado con el mensaje configurado para <caso>

    @AC-LOGIN-02 @tec-equivalencia @tec-decision
    Examples:
      | caso             |
      | locked-user      |

    @AC-LOGIN-03 @tec-equivalencia @tec-decision
    Examples:
      | caso             |
      | invalid-password |

    @AC-LOGIN-04 @tec-equivalencia @tec-decision
    Examples:
      | caso             |
      | nonexistent-user |

    @AC-LOGIN-05 @tec-equivalencia @tec-decision
    Examples:
      | caso           |
      | empty-username |

    @AC-LOGIN-06 @tec-equivalencia @tec-decision
    Examples:
      | caso           |
      | empty-password |

    @AC-LOGIN-07 @tec-decision
    Examples:
      | caso       |
      | empty-both |

  @AC-LOGIN-08 @tec-estados
  Scenario: Acceso directo al catálogo sin sesión iniciada
    When solicita directamente el catálogo
    Then vuelve al inicio de sesión
    And el acceso es rechazado con el mensaje configurado para anonymous-access

  @AC-LOGIN-09 @tec-estados
  Scenario: Cierre de sesión y pérdida del acceso al catálogo
    When inicia sesión con las credenciales estándar configuradas
    Then accede al inventario
    When cierra la sesión
    Then vuelve al inicio de sesión
    When solicita directamente el catálogo
    Then vuelve al inicio de sesión
    And el acceso es rechazado con el mensaje configurado para anonymous-access
