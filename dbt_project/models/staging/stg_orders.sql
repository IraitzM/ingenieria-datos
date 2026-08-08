-- Cabeceras de pedido.
--
-- Se dejan fuera los presupuestos que nunca llegaron a pedido (`draft` y
-- `sent`). Es una decisión de negocio, no técnica, y por eso vive en staging y
-- no escondida dentro de un hub.

SELECT
    id                AS order_id,
    name              AS order_reference,
    partner_id        AS customer_id,
    state             AS order_state,
    date_order,
    amount_untaxed,
    amount_tax,
    amount_total,
    create_date,
    write_date
FROM {{ source('raw', 'raw_orders') }}
WHERE id IS NOT NULL
  AND partner_id IS NOT NULL
  AND state IN ('sale', 'done')
