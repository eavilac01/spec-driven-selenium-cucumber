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
