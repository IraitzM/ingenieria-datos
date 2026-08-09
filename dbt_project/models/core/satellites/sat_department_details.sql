-- Satélite de departamento.
--
-- `parent_department_id` se queda aquí como atributo y merece una explicación,
-- porque contradice en apariencia lo que se acaba de hacer con el departamento
-- del empleado.
--
-- La diferencia es que esto es una jerarquía: la entidad se referencia a sí
-- misma. Modelarla como relación exigiría un **enlace jerárquico**, un enlace
-- cuyos dos extremos apuntan al mismo hub, y consultarlo obliga a recursión.
-- Como el origen ya calcula la ruta completa (`department_path`) y es lo que
-- el panel necesita, aquí se guardan la ruta y el padre como atributos. Es una
-- simplificación consciente, y montar el enlace jerárquico es uno de los
-- ejercicios que propone el apéndice.

{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'append',
    tags = ['data_vault', 'satellite']
  )
}}

{% set atributos = [
    'department_name', 'department_path', 'parent_department_id',
    'manager_employee_id', 'active'
] %}

WITH fuente AS (
    SELECT
        {{ hash_clave(['department_id']) }} AS hk_department,
        department_name,
        department_path,
        parent_department_id,
        manager_employee_id,
        active,
        {{ hashdiff(atributos) }}    AS hashdiff,
        {{ dv_load_date() }}         AS load_date,
        '{{ var("record_source") }}' AS record_source
    FROM {{ ref('stg_departments') }}
)

{% if is_incremental() %}
, vigente AS (
    SELECT hk_department, hashdiff
    FROM (
        SELECT
            hk_department,
            hashdiff,
            row_number() OVER (PARTITION BY hk_department ORDER BY load_date DESC) AS dv_fila
        FROM {{ this }}
    )
    WHERE dv_fila = 1
)
{% endif %}

SELECT f.*
FROM fuente f

{% if is_incremental() %}
LEFT JOIN vigente v ON f.hk_department = v.hk_department
WHERE v.hashdiff IS NULL
   OR v.hashdiff <> f.hashdiff
{% endif %}
