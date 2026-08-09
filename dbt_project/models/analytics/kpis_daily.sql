-- Capa oro: métricas diarias.
--
-- Materializado como tabla porque es lo que va a atacar el panel y conviene
-- que la respuesta sea inmediata. Con este volumen daría igual, pero la
-- decisión se toma pensando en el volumen que habrá, no en el que hay.

{{ config(materialized = 'table') }}

WITH unidades_dia AS (
    -- Las unidades hay que contarlas a grano de línea, no de pedido, y por eso
    -- llegan por su lado y no como una columna más del SELECT de abajo. Sumar
    -- cantidades y facturación en la misma consulta obligaría a partir de las
    -- líneas, y entonces el importe del pedido se contaría una vez por línea.
    SELECT
        CAST(date_order AS DATE) AS fecha,
        sum(quantity)            AS unidades,
        count(*)                 AS lineas
    FROM {{ ref('point_in_time_order_lines') }}
    WHERE date_order IS NOT NULL
    GROUP BY 1
)

SELECT
    CAST(p.date_order AS DATE)        AS fecha,
    count(DISTINCT p.order_id)        AS pedidos,
    count(DISTINCT p.customer_id)     AS clientes,
    count(DISTINCT p.employee_id)     AS comerciales,
    sum(p.amount_untaxed)             AS base_imponible,
    sum(p.amount_total)               AS facturacion,
    avg(p.amount_total)               AS ticket_medio,
    coalesce(max(u.unidades), 0)      AS unidades,
    coalesce(max(u.lineas), 0)        AS lineas
FROM {{ ref('point_in_time_orders') }} p
LEFT JOIN unidades_dia u
    ON u.fecha = CAST(p.date_order AS DATE)
WHERE p.date_order IS NOT NULL
GROUP BY 1
ORDER BY 1
