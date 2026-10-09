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
