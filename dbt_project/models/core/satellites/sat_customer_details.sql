-- Satélite de cliente: los atributos que sí cambian.
--
-- El satélite es de solo inserción. En cada carga se calcula el `hashdiff` de
-- los atributos y solo se escribe una fila nueva si difiere del último
-- `hashdiff` guardado para esa clave. Si nada cambió, no se escribe nada.
--
-- No hay ninguna columna `dv_end_date` que cerrar. La vigencia se deduce al
-- consultar quedándose con el `load_date` más alto (macro `satelite_vigente`),
-- y el intervalo de validez de cada versión se obtiene con una función de
-- ventana cuando hace falta, como en el modelo `customer_history`. Cerrar
-- filas con UPDATE obligaría a reescribir el histórico, que es precisamente lo
-- que un vault no debe hacer.

{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'append',
    tags = ['data_vault', 'satellite']
  )
}}

{% set atributos = [
    'customer_name', 'is_company', 'customer_rank', 'supplier_rank',
    'email', 'phone', 'street', 'city', 'zip', 'country_id',
    'state_id', 'active'
] %}

WITH fuente AS (
    SELECT
        {{ hash_clave(['customer_id']) }} AS hk_customer,
        customer_name,
        is_company,
        customer_rank,
        supplier_rank,
        email,
        phone,
        street,
        city,
        zip,
        country_id,
        state_id,
        active,
        {{ hashdiff(atributos) }}    AS hashdiff,
        {{ dv_load_date() }}         AS load_date,
        '{{ var("record_source") }}' AS record_source
    FROM {{ ref('stg_customers') }}
)

{% if is_incremental() %}
, vigente AS (
    SELECT hk_customer, hashdiff
    FROM (
        SELECT
            hk_customer,
            hashdiff,
            row_number() OVER (PARTITION BY hk_customer ORDER BY load_date DESC) AS dv_fila
        FROM {{ this }}
    )
    WHERE dv_fila = 1
)
{% endif %}

SELECT f.*
FROM fuente f

{% if is_incremental() %}
LEFT JOIN vigente v ON f.hk_customer = v.hk_customer
WHERE v.hashdiff IS NULL      -- cliente nuevo
   OR v.hashdiff <> f.hashdiff -- algún atributo cambió
{% endif %}
