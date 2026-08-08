-- Hub de producto.
--
-- La clave de negocio es la variante (`product_product`), no la plantilla,
-- porque es la variante lo que se vende y lo que aparece en la línea de pedido.

{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'append',
    tags = ['data_vault', 'hub']
  )
}}

WITH fuente AS (
    SELECT DISTINCT product_id
    FROM {{ ref('stg_products') }}
),

calculado AS (
    SELECT
        {{ hash_clave(['product_id']) }} AS hk_product,
        product_id,
        {{ dv_load_date() }} AS load_date,
        '{{ var("record_source") }}' AS record_source
    FROM fuente
)

SELECT *
FROM calculado

{% if is_incremental() %}
WHERE hk_product NOT IN (SELECT hk_product FROM {{ this }})
{% endif %}
