-- Satélite del enlace pedido - producto.
--
-- Aquí viven las cantidades y los precios de cada línea. Colgar un satélite de
-- un enlace es lo que permite describir la relación sin ensuciarla: el enlace
-- dice que ese pedido lleva ese producto, y el satélite dice cuánto y a qué
-- precio en cada momento.

{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'append',
    tags = ['data_vault', 'satellite']
  )
}}

{% set atributos = [
    'quantity', 'qty_delivered', 'qty_invoiced',
    'price_unit', 'discount', 'price_subtotal', 'price_total'
] %}

WITH fuente AS (
    SELECT
        {{ hash_clave(['order_line_id']) }} AS hk_order_product,
        line_description,
        quantity,
        qty_delivered,
        qty_invoiced,
        price_unit,
        discount,
        price_subtotal,
        price_total,
        {{ hashdiff(atributos) }}    AS hashdiff,
        {{ dv_load_date() }}         AS load_date,
        '{{ var("record_source") }}' AS record_source
    FROM {{ ref('stg_order_lines') }} l
    WHERE EXISTS (
        SELECT 1 FROM {{ ref('stg_orders') }} p WHERE p.order_id = l.order_id
    )
)

{% if is_incremental() %}
, vigente AS (
    SELECT hk_order_product, hashdiff
    FROM (
        SELECT
            hk_order_product,
            hashdiff,
            row_number() OVER (PARTITION BY hk_order_product ORDER BY load_date DESC) AS dv_fila
        FROM {{ this }}
    )
    WHERE dv_fila = 1
)
{% endif %}

SELECT f.*
FROM fuente f

{% if is_incremental() %}
LEFT JOIN vigente v ON f.hk_order_product = v.hk_order_product
WHERE v.hashdiff IS NULL
   OR v.hashdiff <> f.hashdiff
{% endif %}
