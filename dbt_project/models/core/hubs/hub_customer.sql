-- Hub de cliente.
--
-- Un hub guarda la lista de claves de negocio y nada más. Ni un atributo
-- descriptivo: en cuanto se cuela el nombre del cliente en un hub, el modelo
-- deja de poder absorber cambios sin reescribir historia, que era justo lo que
-- se quería evitar.
--
-- Es de solo inserción. Una clave de negocio entra una vez y no vuelve a
-- tocarse, así que en cada carga se añaden únicamente las que no estaban.

{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'append',
    tags = ['data_vault', 'hub']
  )
}}

-- El hub se carga desde TODOS los orígenes que traen la clave de negocio, no
-- solo desde la tabla que "es" la entidad. Aquí son dos: la lista de contactos
-- y los propios pedidos, que también nombran clientes.
--
-- Saltarse esto es el error más habitual al construir un vault. Si el hub sale
-- únicamente de la lista de contactos y el pedido referencia a alguien que ese
-- filtro dejó fuera, el enlace queda colgando. La prueba `relationships` de
-- este proyecto lo detecta, y conviene provocarlo alguna vez para verlo fallar.
WITH fuente AS (
    SELECT customer_id FROM {{ ref('stg_customers') }}
    UNION
    SELECT customer_id FROM {{ ref('stg_orders') }}
),

calculado AS (
    SELECT
        {{ hash_clave(['customer_id']) }} AS hk_customer,
        customer_id,
        {{ dv_load_date() }} AS load_date,
        '{{ var("record_source") }}' AS record_source
    FROM fuente
)

SELECT *
FROM calculado

{% if is_incremental() %}
WHERE hk_customer NOT IN (SELECT hk_customer FROM {{ this }})
{% endif %}
