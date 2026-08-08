-- Hub de pedido.

{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'append',
    tags = ['data_vault', 'hub']
  )
}}

WITH fuente AS (
    SELECT DISTINCT order_id
    FROM {{ ref('stg_orders') }}
),

calculado AS (
    SELECT
        {{ hash_clave(['order_id']) }} AS hk_order,
        order_id,
        {{ dv_load_date() }} AS load_date,
        '{{ var("record_source") }}' AS record_source
    FROM fuente
)

SELECT *
FROM calculado

{% if is_incremental() %}
WHERE hk_order NOT IN (SELECT hk_order FROM {{ this }})
{% endif %}
