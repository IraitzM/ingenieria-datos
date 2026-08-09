-- Enlace empleado - departamento.
--
-- Aquí está la consecuencia menos evidente de sacar el departamento del
-- satélite del empleado y ponerlo en un enlace. El enlace es de solo
-- inserción, igual que todo lo demás, así que **un traslado no sustituye
-- nada**: el empleado acaba con dos filas, una por cada departamento en el que
-- ha estado, y las dos son ciertas.
--
-- Eso está bien para la historia y es un problema para la pregunta "¿en qué
-- departamento está ahora?". Preguntar mal aquí duplica al empleado en
-- cualquier recuento, que es la forma clásica de que una plantilla de veinte
-- personas aparezca como veintiuna en un panel.
--
-- La solución no es cerrar filas sino declarar cuál es la **clave conductora**
-- de la relación (el empleado, porque es el que se mueve) y quedarse con su
-- última carga. Eso hace la macro `enlace_vigente()`, y así se consume en
-- `employee_360`.

{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'append',
    tags = ['data_vault', 'link']
  )
}}

WITH fuente AS (
    SELECT DISTINCT employee_id, department_id
    FROM {{ ref('stg_employees') }}
    WHERE department_id IS NOT NULL
),

calculado AS (
    SELECT
        {{ hash_clave(['employee_id', 'department_id']) }} AS hk_employee_department,
        {{ hash_clave(['employee_id']) }}                  AS hk_employee,
        {{ hash_clave(['department_id']) }}                AS hk_department,
        {{ dv_load_date() }}                               AS load_date,
        '{{ var("record_source") }}'                       AS record_source
    FROM fuente
)

SELECT *
FROM calculado

{% if is_incremental() %}
WHERE hk_employee_department NOT IN (SELECT hk_employee_department FROM {{ this }})
{% endif %}
