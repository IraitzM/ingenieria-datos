-- Hub de departamento.
--
-- Tres orígenes para la misma clave, y ninguno sobra:
--
--   * la propia lista de departamentos,
--   * el departamento al que se asigna cada empleado,
--   * y el departamento padre de otro departamento.
--
-- El tercero es el que sorprende. Un árbol se referencia a sí mismo, así que
-- la tabla de departamentos es a la vez el catálogo de claves y un consumidor
-- de esas claves. Si algún día el catálogo llegara filtrado (solo los activos,
-- por ejemplo) y un departamento activo colgase de uno archivado, la clave del
-- padre no estaría en el hub y la jerarquía se rompería.

{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'append',
    tags = ['data_vault', 'hub']
  )
}}

WITH fuente AS (
    SELECT department_id FROM {{ ref('stg_departments') }}
    UNION
    SELECT department_id FROM {{ ref('stg_employees') }} WHERE department_id IS NOT NULL
    UNION
    SELECT parent_department_id FROM {{ ref('stg_departments') }} WHERE parent_department_id IS NOT NULL
),

calculado AS (
    SELECT
        {{ hash_clave(['department_id']) }} AS hk_department,
        department_id,
        {{ dv_load_date() }} AS load_date,
        '{{ var("record_source") }}' AS record_source
    FROM fuente
)

SELECT *
FROM calculado

{% if is_incremental() %}
WHERE hk_department NOT IN (SELECT hk_department FROM {{ this }})
{% endif %}
