-- Enlace pedido - producto, a grano de línea de pedido.
--
-- Aquí hay una decisión que conviene entender. La tentación es construir el
-- enlace sobre el par (pedido, producto) y meter la cantidad dentro, pero eso
-- rompe por dos sitios: un mismo producto puede aparecer en dos líneas del
-- mismo pedido, y la cantidad es un atributo descriptivo, que en Data Vault no
-- va nunca en el enlace.
--
-- La línea de pedido es la ocurrencia concreta de la relación, así que es ella
-- la que da el grano. Su identificador se conserva como clave degenerada y las
-- cantidades y precios se van a un satélite del enlace.

{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'append',
    tags = ['data_vault', 'link']
  )
}}

WITH fuente AS (
    SELECT
        l.order_line_id,
        l.order_id,
        l.product_id
    FROM {{ ref('stg_order_lines') }} l
    -- Solo líneas de pedidos que hayan superado el filtro de staging.
    INNER JOIN {{ ref('stg_orders') }} p ON l.order_id = p.order_id
),

calculado AS (
    SELECT
        {{ hash_clave(['order_line_id']) }} AS hk_order_product,
        {{ hash_clave(['order_id']) }}      AS hk_order,
        {{ hash_clave(['product_id']) }}    AS hk_product,
        order_line_id,
        {{ dv_load_date() }}                AS load_date,
        '{{ var("record_source") }}'        AS record_source
    FROM fuente
)

SELECT *
FROM calculado

{% if is_incremental() %}
WHERE hk_order_product NOT IN (SELECT hk_order_product FROM {{ this }})
{% endif %}
