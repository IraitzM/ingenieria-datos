-- Enlace pedido - empleado: quién firmó la venta.
--
-- El grano es el pedido, porque en Odoo un pedido tiene un comercial y solo
-- uno. Eso se comprueba en `stg_order_salesperson` con una prueba de unicidad,
-- y no es una formalidad: si el origen empezara a permitir dos, este enlace
-- duplicaría cada pedido y el rendimiento por comercial contaría doble sin que
-- nada fallase.

{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'append',
    tags = ['data_vault', 'link']
  )
}}

WITH fuente AS (
    SELECT DISTINCT order_id, employee_id
    FROM {{ ref('stg_order_salesperson') }}
),

calculado AS (
    SELECT
        {{ hash_clave(['order_id', 'employee_id']) }} AS hk_order_employee,
        {{ hash_clave(['order_id']) }}                AS hk_order,
        {{ hash_clave(['employee_id']) }}             AS hk_employee,
        {{ dv_load_date() }}                          AS load_date,
        '{{ var("record_source") }}'                  AS record_source
    FROM fuente
)

SELECT *
FROM calculado

{% if is_incremental() %}
WHERE hk_order_employee NOT IN (SELECT hk_order_employee FROM {{ this }})
{% endif %}
