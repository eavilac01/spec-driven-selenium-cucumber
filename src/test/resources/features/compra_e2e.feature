Feature: Compra de productos
  Como cliente autenticado de SauceDemo
  Quiero comprar varios productos
  Para recibir la confirmación de mi pedido

  Spec: docs/specs/compra.md

  @e2e @AC-COMPRA-01 @AC-COMPRA-02 @AC-COMPRA-03 @tec-equivalencia
  Scenario: Compra exitosa de dos productos
    Given que el usuario está autenticado para comprar
    When agrega los productos configurados al carrito
    Then el carrito refleja la cantidad de productos configurada
    And el carrito contiene los productos seleccionados
    When tramita la compra con los datos de envío configurados
    Then la compra se confirma con el mensaje configurado

  @e2e @AC-COMPRA-04 @tec-frontera
  Scenario: Carrito con el mínimo de un producto
    Given que el usuario está autenticado para comprar
    When agrega el producto individual configurado al carrito
    Then el carrito refleja la cantidad de productos configurada
    And el carrito contiene los productos seleccionados

  @e2e @AC-COMPRA-05 @tec-frontera
  Scenario: Carrito sin productos en el mínimo de cero
    Given que el usuario está autenticado para comprar
    Then el contador del carrito no se muestra
    And el carrito no contiene productos

  @e2e @AC-COMPRA-06 @tec-frontera
  Scenario: Carrito con cinco productos, un producto por debajo del máximo
    Given que el usuario está autenticado para comprar
    When agrega los cinco productos configurados al carrito
    Then el carrito refleja la cantidad de productos configurada
    And el carrito contiene los productos seleccionados
    And el catálogo ofrece los productos esperados

  @e2e @AC-COMPRA-07 @tec-frontera
  Scenario: Carrito con todos los productos del catálogo, en el máximo de seis
    Given que el usuario está autenticado para comprar
    When agrega todos los productos del catálogo al carrito
    Then el carrito refleja la cantidad de productos configurada
    And el carrito contiene los productos seleccionados
    And el catálogo ofrece los productos esperados
    And no quedan productos del catálogo por agregar

  @e2e @AC-COMPRA-08 @tec-estados
  Scenario: Quitar un producto de un carrito con dos productos
    Given que el usuario está autenticado para comprar
    When agrega los productos configurados al carrito
    And quita del carrito el producto configurado para quitar
    Then el carrito refleja la cantidad de productos configurada
    And el carrito contiene los productos seleccionados

  @e2e @AC-COMPRA-08 @tec-estados
  Scenario: Quitar el único producto de un carrito
    Given que el usuario está autenticado para comprar
    When agrega el producto individual configurado al carrito
    And quita del carrito el producto individual configurado
    Then el contador del carrito no se muestra
    And el carrito no contiene productos

  @e2e @quarantine @AC-COMPRA-09 @tec-estados @tec-frontera
  Scenario: Tramitar la compra con el carrito sin productos
    Given que el usuario está autenticado para comprar
    When intenta tramitar la compra con el carrito sin productos
    Then la compra no avanza a los datos de envío

  Scenario Outline: Rechazo de la compra por datos de envío incompletos
    Given que el usuario está autenticado para comprar
    When agrega el producto individual configurado al carrito
    And tramita la compra sin informar el dato de envío <dato>
    Then la compra no continúa y se informa el mensaje configurado para <dato>

    @e2e @AC-COMPRA-10 @tec-equivalencia @tec-decision
    Examples:
      | dato       |
      | first-name |

    @e2e @AC-COMPRA-11 @tec-equivalencia @tec-decision
    Examples:
      | dato      |
      | last-name |

    @e2e @AC-COMPRA-12 @tec-equivalencia @tec-decision
    Examples:
      | dato        |
      | postal-code |

  @e2e @AC-COMPRA-13 @tec-estados
  Scenario: Carrito vacío tras confirmar una compra
    Given que el usuario está autenticado para comprar
    When agrega los productos configurados al carrito
    And tramita la compra con los datos de envío configurados
    Then la compra se confirma con el mensaje configurado
    And el contador del carrito no se muestra
    And el carrito no contiene productos
