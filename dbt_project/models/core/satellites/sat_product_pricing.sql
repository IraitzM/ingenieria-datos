-- Satélite de producto: descripción y tarifa.
--
-- `list_price` es el precio de tarifa de la plantilla, no el precio al que se
-- vendió. El precio realmente aplicado en cada venta está en el satélite de la
-- línea de pedido, que es donde tiene sentido: un mismo producto se vende a
-- precios distintos según el descuento.

{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'append',
    tags = ['data_vault', 'satellite']
  )
}}

{% set atributos = [
    'product_name', 'product_code', 'product_type', 'category_id',
    'list_price', 'weight', 'volume', 'active'
] %}

WITH fuente AS (
    SELECT
        {{ hash_clave(['product_id']) }} AS hk_product,
        product_name,
        product_code,
        product_type,
        category_id,
        list_price,
        weight,
        volume,
        active,
        {{ hashdiff(atributos) }}    AS hashdiff,
        {{ dv_load_date() }}         AS load_date,
        '{{ var("record_source") }}' AS record_source
    FROM {{ ref('stg_products') }}
)

{% if is_incremental() %}
, vigente AS (
    SELECT hk_product, hashdiff
    FROM (
        SELECT
            hk_product,
            hashdiff,
            row_number() OVER (PARTITION BY hk_product ORDER BY load_date DESC) AS dv_fila
        FROM {{ this }}
    )
    WHERE dv_fila = 1
)
{% endif %}

SELECT f.*
FROM fuente f

{% if is_incremental() %}
LEFT JOIN vigente v ON f.hk_product = v.hk_product
WHERE v.hashdiff IS NULL
   OR v.hashdiff <> f.hashdiff
{% endif %}
