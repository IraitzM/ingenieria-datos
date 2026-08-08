-- Capa oro: histórico de cambios del cliente.
--
-- Este modelo existe para enseñar una cosa concreta: de dónde sale el
-- `dv_end_date` del que habla toda la literatura de Data Vault sin que el
-- satélite lo tenga guardado.
--
-- `lead()` mira la siguiente carga de esa misma clave. Si existe, esa es la
-- fecha en la que la versión actual dejó de ser cierta; si no existe, la
-- versión sigue vigente y el cierre queda a NULL. El intervalo se calcula, no
-- se almacena, y así el satélite nunca necesita un UPDATE.
--
-- Con una sola carga cada cliente tendrá una única versión abierta. Para verlo
-- funcionar hay que cambiar algo en Odoo y volver a ejecutar el pipeline, que
-- es justo el ejercicio que propone el apéndice.

{{ config(materialized = 'view') }}

SELECT
    hc.customer_id,
    s.customer_name,
    s.email,
    s.phone,
    s.city,
    s.country_id,

    s.load_date                                AS dv_start_date,
    lead(s.load_date) OVER (
        PARTITION BY s.hk_customer
        ORDER BY s.load_date
    )                                          AS dv_end_date,
    lead(s.load_date) OVER (
        PARTITION BY s.hk_customer
        ORDER BY s.load_date
    ) IS NULL                                  AS es_version_vigente,

    s.record_source
FROM {{ ref('sat_customer_details') }} s
INNER JOIN {{ ref('hub_customer') }} hc
    ON hc.hk_customer = s.hk_customer
