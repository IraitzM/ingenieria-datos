-- Capa oro: el pedido con su contexto, ya montado.
--
-- El vault está troceado a propósito, y consultarlo directamente obliga a
-- encadenar hubs, enlaces y satélites en cada pregunta. Esta vista hace ese
-- trabajo una vez para que quien explota el dato no tenga que repetirlo.
--
-- Se queda con la versión vigente de cada satélite. Para preguntar por el
-- estado del mundo en una fecha pasada habría que filtrar por `load_date`, y
-- ahí es donde el vault demuestra para qué servía guardarlo todo.

{{ config(materialized = 'view') }}

WITH pedido AS (
    {{ satelite_vigente(ref('sat_order_status'), 'hk_order') }}
),

cliente AS (
    {{ satelite_vigente(ref('sat_customer_details'), 'hk_customer') }}
)

SELECT
    ho.order_id,
    p.order_reference,
    p.order_state,
    p.date_order,
    p.amount_untaxed,
    p.amount_tax,
    p.amount_total,

    hc.customer_id,
    c.customer_name,
    c.email,
    c.city,
    c.country_id,
    c.is_company,

    p.load_date AS vault_load_date
FROM {{ ref('hub_order') }} ho
INNER JOIN pedido p
    ON p.hk_order = ho.hk_order
INNER JOIN {{ ref('link_order_customer') }} l
    ON l.hk_order = ho.hk_order
INNER JOIN {{ ref('hub_customer') }} hc
    ON hc.hk_customer = l.hk_customer
INNER JOIN cliente c
    ON c.hk_customer = hc.hk_customer
