-- Capa oro: rendimiento del catálogo.
--
-- Una fila por producto, haya salido o no. Los que no se han vendido nunca son
-- justo los que interesa mirar en un catálogo, y por eso el punto de partida
-- es el hub de producto y no las líneas de pedido: empezando por las ventas,
-- lo que no se vendió no existe y la pregunta "¿qué tenemos parado?" no se
-- puede ni formular.
--
-- Aquí no hay margen y no es un olvido. El coste (`standard_price`) no es una
-- columna en Odoo: vive en `ir_property` porque depende de la compañía, y no
-- se ha traído. Cualquier cálculo de rentabilidad exige antes ese origen, y es
-- uno de los ejercicios que propone el apéndice.

{{ config(materialized = 'table') }}

WITH producto AS (
    {{ satelite_vigente(ref('sat_product_pricing'), 'hk_product') }}
),

categoria AS (
    {{ satelite_vigente(ref('sat_category_details'), 'hk_category') }}
),

clasificacion AS (
    {{ enlace_vigente(ref('link_product_category'), 'hk_product') }}
),

ventas AS (
    SELECT
        product_id,
        count(DISTINCT order_id)     AS pedidos,
        count(DISTINCT customer_id)  AS clientes,
        count(*)                     AS lineas,
        sum(quantity)                AS unidades,
        sum(price_subtotal)          AS base_imponible,
        sum(price_total)             AS facturacion,
        sum(importe_descuento)       AS descuento_concedido,
        avg(price_unit)              AS precio_medio_venta,
        max(date_order)              AS ultima_venta
    FROM {{ ref('point_in_time_order_lines') }}
    GROUP BY 1
)

SELECT
    hp.product_id,
    p.product_name,
    p.product_code,
    p.product_type,
    p.list_price,

    hcat.category_id,
    coalesce(cat.category_path, 'Sin categoría') AS category_path,
    coalesce(cat.category_name, 'Sin categoría') AS category_name,

    coalesce(v.pedidos, 0)        AS pedidos,
    coalesce(v.clientes, 0)       AS clientes,
    coalesce(v.lineas, 0)         AS lineas,
    coalesce(v.unidades, 0)       AS unidades,
    coalesce(v.base_imponible, 0) AS base_imponible,
    coalesce(v.facturacion, 0)    AS facturacion,
    coalesce(v.descuento_concedido, 0) AS descuento_concedido,
    v.precio_medio_venta,
    v.ultima_venta,

    -- Cuánto se aparta el precio real del de catálogo, en tanto por uno.
    -- Negativo significa que se vendió por debajo de tarifa.
    CASE
        WHEN p.list_price > 0 AND v.precio_medio_venta IS NOT NULL
        THEN (v.precio_medio_venta - p.list_price) / p.list_price
    END AS desviacion_sobre_tarifa,

    coalesce(v.pedidos, 0) = 0 AS nunca_vendido
FROM {{ ref('hub_product') }} hp
INNER JOIN producto p
    ON p.hk_product = hp.hk_product
LEFT JOIN clasificacion cl
    ON cl.hk_product = hp.hk_product
LEFT JOIN {{ ref('hub_category') }} hcat
    ON hcat.hk_category = cl.hk_category
LEFT JOIN categoria cat
    ON cat.hk_category = hcat.hk_category
LEFT JOIN ventas v
    ON v.product_id = hp.product_id
