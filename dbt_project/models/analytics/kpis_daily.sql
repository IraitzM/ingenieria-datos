-- Capa oro: métricas diarias.
--
-- Materializado como tabla porque es lo que va a atacar el panel y conviene
-- que la respuesta sea inmediata. Con este volumen daría igual, pero la
-- decisión se toma pensando en el volumen que habrá, no en el que hay.

{{ config(materialized = 'table') }}

SELECT
    CAST(date_order AS DATE)        AS fecha,
    count(DISTINCT order_id)        AS pedidos,
    count(DISTINCT customer_id)     AS clientes,
    sum(amount_untaxed)             AS base_imponible,
    sum(amount_total)               AS facturacion,
    avg(amount_total)               AS ticket_medio
FROM {{ ref('point_in_time_orders') }}
WHERE date_order IS NOT NULL
GROUP BY 1
ORDER BY 1
