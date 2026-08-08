-- Capa oro: ficha de cliente.
--
-- Vivía en el proyecto de Rill, y ese era el error que describe el apéndice de
-- exploración: una definición que sirve a más de una herramienta no debe vivir
-- dentro de una herramienta. Aquí la calcula dbt una vez y la consumen todos.

{{ config(materialized = 'table') }}

WITH cliente AS (
    {{ satelite_vigente(ref('sat_customer_details'), 'hk_customer') }}
),

pedidos AS (
    SELECT
        customer_id,
        count(DISTINCT order_id)  AS pedidos,
        sum(amount_total)         AS facturacion_total,
        avg(amount_total)         AS ticket_medio,
        min(date_order)           AS primer_pedido,
        max(date_order)           AS ultimo_pedido
    FROM {{ ref('point_in_time_orders') }}
    GROUP BY 1
)

SELECT
    hc.customer_id,
    c.customer_name,
    c.email,
    c.city,
    c.country_id,
    c.is_company,

    coalesce(p.pedidos, 0)            AS pedidos,
    coalesce(p.facturacion_total, 0)  AS facturacion_total,
    p.ticket_medio,
    p.primer_pedido,
    p.ultimo_pedido,

    -- Días desde la última compra. Es la base de cualquier análisis de fuga,
    -- y se calcula sobre la fecha de ejecución, no sobre una fecha fija.
    CASE
        WHEN p.ultimo_pedido IS NOT NULL
        THEN date_diff('day', CAST(p.ultimo_pedido AS DATE), CURRENT_DATE)
    END AS dias_desde_ultimo_pedido
FROM {{ ref('hub_customer') }} hc
INNER JOIN cliente c
    ON c.hk_customer = hc.hk_customer
LEFT JOIN pedidos p
    ON p.customer_id = hc.customer_id
