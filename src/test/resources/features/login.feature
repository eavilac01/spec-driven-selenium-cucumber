Feature: Autenticación de usuarios
  Como cliente de SauceDemo
  Quiero autenticarme con mis credenciales
  Para acceder de forma segura al catálogo

  Background:
    Given que el usuario abre la página de inicio de sesión

  @smoke
  Scenario: Inicio de sesión exitoso
    When inicia sesión con las credenciales estándar configuradas
    Then accede al inventario

  Scenario Outline: Rechazo de credenciales no autorizadas
    When intenta iniciar sesión con el caso configurado <caso>
    Then el acceso es rechazado con el mensaje configurado para <caso>

    Examples:
      | caso             |
      | locked-user      |
      | invalid-password |
