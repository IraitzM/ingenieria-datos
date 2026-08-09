-- Pedidos cuyo comercial no ha podido resolverse contra la plantilla.
--
-- Esta prueba avisa, no rompe. La diferencia importa y es una decisión de
-- diseño, no un descuido: que un pedido lo firme una cuenta que no corresponde
-- a ningún empleado es una situación **legítima** del origen (un usuario del
-- portal, una cuenta de integración, alguien cuya ficha se dio de baja), así
-- que fallar la carga por eso sería castigar al almacén por algo que ocurre en
-- el ERP.
--
-- Lo que no puede pasar es que ocurra en silencio. Sin esta prueba, el día que
-- alguien cambie la cuenta de un comercial los pedidos empezarían a
-- desaparecer del panel de rendimiento sin que ninguna carga fallase, que es
-- la peor forma de perder datos: la que no hace ruido.
--
-- `severity: warn` es exactamente esa distinción escrita en dbt.

{{ config(severity = 'warn') }}

SELECT
    p.order_id,
    p.order_reference,
    p.salesperson_user_id
FROM {{ ref('stg_orders') }} p
LEFT JOIN {{ ref('stg_order_salesperson') }} c
    ON c.order_id = p.order_id
WHERE p.salesperson_user_id IS NOT NULL
  AND c.employee_id IS NULL
