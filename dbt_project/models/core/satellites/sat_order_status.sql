-- Satélite de pedido: estado e importes.
--
-- Es el satélite que más se mueve de los tres, porque un pedido cambia de
-- estado varias veces a lo largo de su vida y cada cambio deja una fila.

{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'append',
    tags = ['data_vault', 'satellite']
  )
}}

-- `team_id` sí es un atributo del pedido y no una relación con un hub, porque
-- el equipo comercial se modela como tabla de referencia (ver `ref_sales_team`
-- y la explicación que lleva dentro). Se guarda el código y se decodifica al
-- consultar.
{% set atributos = [
    'order_reference', 'order_state', 'date_order',
    'amount_untaxed', 'amount_tax', 'amount_total', 'team_id'
] %}

WITH fuente AS (
    SELECT
        {{ hash_clave(['order_id']) }} AS hk_order,
        order_reference,
        order_state,
        date_order,
        amount_untaxed,
        amount_tax,
        amount_total,
        team_id,
        {{ hashdiff(atributos) }}    AS hashdiff,
        {{ dv_load_date() }}         AS load_date,
        '{{ var("record_source") }}' AS record_source
    FROM {{ ref('stg_orders') }}
)

{% if is_incremental() %}
, vigente AS (
    SELECT hk_order, hashdiff
    FROM (
        SELECT
            hk_order,
            hashdiff,
            row_number() OVER (PARTITION BY hk_order ORDER BY load_date DESC) AS dv_fila
        FROM {{ this }}
    )
    WHERE dv_fila = 1
)
{% endif %}

SELECT f.*
FROM fuente f

{% if is_incremental() %}
LEFT JOIN vigente v ON f.hk_order = v.hk_order
WHERE v.hashdiff IS NULL
   OR v.hashdiff <> f.hashdiff
{% endif %}
