Feature: Compra de productos
  Como cliente autenticado de SauceDemo
  Quiero comprar varios productos
  Para recibir la confirmación de mi pedido

  @e2e
  Scenario: Compra exitosa de dos productos
    Given que el usuario está autenticado para comprar
    When agrega los productos configurados al carrito
    Then el carrito refleja la cantidad de productos configurada
    And el carrito contiene los productos seleccionados
    When tramita la compra con los datos de envío configurados
    Then la compra se confirma con el mensaje configurado
