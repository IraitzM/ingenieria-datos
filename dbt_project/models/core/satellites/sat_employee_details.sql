-- Satélite de empleado: los datos profesionales.
--
-- Lo que no está aquí es tan intencionado como lo que sí. El departamento no
-- aparece entre los atributos porque no es un atributo: es una relación con
-- otra entidad que tiene su propio hub, y vive en `link_employee_department`.
-- La regla que separa un caso del otro es si la cosa referida tiene identidad
-- propia; el puesto (`job_title`) llega como texto libre en la ficha, no
-- referencia a nada, y por eso sí se queda como atributo.
--
-- Los datos personales sensibles no llegan siquiera a la capa bronce: el
-- recorte se hace en la ingesta, que es donde se decide qué sale del ERP.

{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'append',
    tags = ['data_vault', 'satellite']
  )
}}

{% set atributos = [
    'employee_name', 'work_email', 'work_phone', 'job_title', 'active'
] %}

WITH fuente AS (
    SELECT
        {{ hash_clave(['employee_id']) }} AS hk_employee,
        employee_name,
        work_email,
        work_phone,
        job_title,
        active,
        {{ hashdiff(atributos) }}    AS hashdiff,
        {{ dv_load_date() }}         AS load_date,
        '{{ var("record_source") }}' AS record_source
    FROM {{ ref('stg_employees') }}
)

{% if is_incremental() %}
, vigente AS (
    SELECT hk_employee, hashdiff
    FROM (
        SELECT
            hk_employee,
            hashdiff,
            row_number() OVER (PARTITION BY hk_employee ORDER BY load_date DESC) AS dv_fila
        FROM {{ this }}
    )
    WHERE dv_fila = 1
)
{% endif %}

SELECT f.*
FROM fuente f

{% if is_incremental() %}
LEFT JOIN vigente v ON f.hk_employee = v.hk_employee
WHERE v.hashdiff IS NULL
   OR v.hashdiff <> f.hashdiff
{% endif %}
