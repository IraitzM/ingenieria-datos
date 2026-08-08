-- Enlace pedido - cliente.
--
-- Un enlace guarda la relación y las claves hash de los hubs que une. Como los
-- hubs, es de solo inserción: si un pedido cambiase de cliente, entraría una
-- fila nueva y la anterior seguiría ahí, que es la forma que tiene el modelo de
-- recordar que la relación existió.

{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'append',
    tags = ['data_vault', 'link']
  )
}}

WITH fuente AS (
    SELECT DISTINCT order_id, customer_id
    FROM {{ ref('stg_orders') }}
),

calculado AS (
    SELECT
        {{ hash_clave(['order_id', 'customer_id']) }} AS hk_order_customer,
        {{ hash_clave(['order_id']) }}                AS hk_order,
        {{ hash_clave(['customer_id']) }}             AS hk_customer,
        {{ dv_load_date() }}                          AS load_date,
        '{{ var("record_source") }}'                  AS record_source
    FROM fuente
)

SELECT *
FROM calculado

{% if is_incremental() %}
WHERE hk_order_customer NOT IN (SELECT hk_order_customer FROM {{ this }})
{% endif %}
