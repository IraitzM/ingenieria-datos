-- Tabla de referencia: equipos comerciales.
--
-- Este es el caso discutible, y por eso está aquí y no en un hub. Un equipo
-- comercial no es un país: tiene responsable, tiene objetivos y en muchas
-- empresas tiene vida analítica propia. En este almacén, sin embargo, solo
-- aparece para que el `team_id` del pedido se lea como "Pre-Sales", así que
-- una tabla de referencia le basta.
--
-- La regla no es sobre la entidad, es sobre el uso: **una tabla de referencia
-- es una entidad de la que no queremos historia**. El día que alguien quiera
-- comparar la facturación de un equipo antes y después de una reorganización,
-- este modelo se queda corto y hay que ascenderlo a hub con su satélite.

{{ config(materialized = 'table', tags = ['data_vault', 'reference']) }}

SELECT
    team_id,
    team_name,
    team_leader_user_id,
    active,
    {{ dv_load_date() }}         AS load_date,
    '{{ var("record_source") }}' AS record_source
FROM {{ ref('stg_sales_teams') }}
