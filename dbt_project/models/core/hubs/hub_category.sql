-- Hub de categoría de producto.
--
-- Mismo patrón de tres orígenes que el hub de departamento: el catálogo, la
-- categoría que declara cada producto y la categoría padre de otra categoría.
--
-- Que la categoría tenga hub propio y no sea una columna del satélite de
-- producto es la decisión que conviene entender. Un `categ_id` dentro del
-- satélite obligaría a repetir el nombre de la categoría en cada producto, y
-- renombrar una categoría escribiría una versión nueva en el satélite de los
-- cientos de productos que cuelgan de ella, como si hubiesen cambiado. La
-- categoría tiene identidad propia, así que le corresponde un hub y un enlace.

{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'append',
    tags = ['data_vault', 'hub']
  )
}}

WITH fuente AS (
    SELECT category_id FROM {{ ref('stg_product_categories') }}
    UNION
    SELECT category_id FROM {{ ref('stg_products') }} WHERE category_id IS NOT NULL
    UNION
    SELECT parent_category_id FROM {{ ref('stg_product_categories') }} WHERE parent_category_id IS NOT NULL
),

calculado AS (
    SELECT
        {{ hash_clave(['category_id']) }} AS hk_category,
        category_id,
        {{ dv_load_date() }} AS load_date,
        '{{ var("record_source") }}' AS record_source
    FROM fuente
)

SELECT *
FROM calculado

{% if is_incremental() %}
WHERE hk_category NOT IN (SELECT hk_category FROM {{ this }})
{% endif %}
