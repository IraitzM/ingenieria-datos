-- Satélite de categoría de producto.
--
-- La ruta completa es un atributo curioso, porque **cambia sin que la
-- categoría cambie**: basta con que alguien renombre a un ancestro para que
-- "All / Saleable / Software" pase a ser otra cosa. Al estar dentro del
-- hashdiff, ese renombrado escribe una versión nueva en todas las categorías
-- que cuelgan de la rama afectada, que es exactamente lo que uno querría que
-- pasase: el histórico refleja que la etiqueta con la que se presentaba el
-- dato dejó de ser esa.

{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'append',
    tags = ['data_vault', 'satellite']
  )
}}

{% set atributos = [
    'category_name', 'category_path', 'parent_category_id'
] %}

WITH fuente AS (
    SELECT
        {{ hash_clave(['category_id']) }} AS hk_category,
        category_name,
        category_path,
        parent_category_id,
        {{ hashdiff(atributos) }}    AS hashdiff,
        {{ dv_load_date() }}         AS load_date,
        '{{ var("record_source") }}' AS record_source
    FROM {{ ref('stg_product_categories') }}
)

{% if is_incremental() %}
, vigente AS (
    SELECT hk_category, hashdiff
    FROM (
        SELECT
            hk_category,
            hashdiff,
            row_number() OVER (PARTITION BY hk_category ORDER BY load_date DESC) AS dv_fila
        FROM {{ this }}
    )
    WHERE dv_fila = 1
)
{% endif %}

SELECT f.*
FROM fuente f

{% if is_incremental() %}
LEFT JOIN vigente v ON f.hk_category = v.hk_category
WHERE v.hashdiff IS NULL
   OR v.hashdiff <> f.hashdiff
{% endif %}
