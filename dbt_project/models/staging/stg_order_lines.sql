-- Líneas de pedido.
--
-- Se filtran las líneas sin producto, que en Odoo son las de sección y nota:
-- filas que existen para maquetar el documento impreso y no representan nada
-- vendido.

SELECT
    id                AS order_line_id,
    order_id,
    product_id,
    name              AS line_description,
    product_uom_qty   AS quantity,
    qty_delivered,
    qty_invoiced,
    price_unit,
    discount,
    price_subtotal,
    price_total,
    create_date,
    write_date
FROM {{ source('raw', 'raw_order_lines') }}
WHERE id IS NOT NULL
  AND product_id IS NOT NULL
