-- Equipos comerciales.
--
-- Otro `name` en JSON. La tabla es diminuta (cinco filas) y su único trabajo
-- es que el `team_id` del pedido se lea como "Pre-Sales" en lugar de como un 5.

SELECT
    id                                    AS team_id,
    json_extract_string(name, '$.en_US')  AS team_name,
    user_id                               AS team_leader_user_id,
    company_id,
    active,
    create_date,
    write_date
FROM {{ source('raw', 'raw_sales_teams') }}
WHERE id IS NOT NULL
