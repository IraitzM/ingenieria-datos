-- Enlace producto - categoría.
--
-- Mismo caso que el del empleado y su departamento: la relación cambia con el
-- tiempo (un producto se recategoriza) y el enlace guarda las dos versiones.
-- La clave conductora es el producto, y `enlace_vigente()` resuelve cuál es la
-- categoría de ahora.
--
-- Guardar las dos tiene más valor del que parece: permite contestar a "¿cuánto
-- vendimos en mobiliario el año pasado?" con la categoría que el producto
-- tenía entonces, en lugar de reescribir el pasado cada vez que alguien
-- reordena el catálogo.

{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'append',
    tags = ['data_vault', 'link']
  )
}}

WITH fuente AS (
    SELECT DISTINCT product_id, category_id
    FROM {{ ref('stg_products') }}
    WHERE category_id IS NOT NULL
),

calculado AS (
    SELECT
        {{ hash_clave(['product_id', 'category_id']) }} AS hk_product_category,
        {{ hash_clave(['product_id']) }}                AS hk_product,
        {{ hash_clave(['category_id']) }}               AS hk_category,
        {{ dv_load_date() }}                            AS load_date,
        '{{ var("record_source") }}'                    AS record_source
    FROM fuente
)

SELECT *
FROM calculado

{% if is_incremental() %}
WHERE hk_product_category NOT IN (SELECT hk_product_category FROM {{ this }})
{% endif %}
