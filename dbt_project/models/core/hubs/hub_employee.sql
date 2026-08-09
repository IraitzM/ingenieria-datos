-- Hub de empleado.
--
-- La clave de negocio es el identificador de la ficha de plantilla, no la
-- cuenta de usuario de Odoo. Son dos cosas distintas y elegir mal aquí se paga
-- caro: la mayoría de los empleados no tiene cuenta, así que un hub montado
-- sobre `user_id` se quedaría con dos de veinte.
--
-- La correspondencia entre ambas identidades ya viene resuelta de staging, de
-- modo que aquí no hay que traducir nada.

{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'append',
    tags = ['data_vault', 'hub']
  )
}}

WITH fuente AS (
    SELECT DISTINCT employee_id
    FROM {{ ref('stg_employees') }}

    UNION

    -- Segundo origen de la clave, por el mismo motivo que en `hub_customer`:
    -- el pedido también nombra empleados. Aquí no puede aparecer ninguno nuevo
    -- porque la resolución ya pasó por la plantilla, pero el día que el
    -- comercial llegue de otro sistema esta línea será lo único que evite un
    -- enlace colgando.
    SELECT DISTINCT employee_id
    FROM {{ ref('stg_order_salesperson') }}
),

calculado AS (
    SELECT
        {{ hash_clave(['employee_id']) }} AS hk_employee,
        employee_id,
        {{ dv_load_date() }} AS load_date,
        '{{ var("record_source") }}' AS record_source
    FROM fuente
)

SELECT *
FROM calculado

{% if is_incremental() %}
WHERE hk_employee NOT IN (SELECT hk_employee FROM {{ this }})
{% endif %}
