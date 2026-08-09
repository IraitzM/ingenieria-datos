-- Capa oro: el pedido con su contexto, ya montado.
--
-- El vault está troceado a propósito, y consultarlo directamente obliga a
-- encadenar hubs, enlaces y satélites en cada pregunta. Esta vista hace ese
-- trabajo una vez para que quien explota el dato no tenga que repetirlo. Con
-- el comercial y su departamento dentro, el recorrido pasa de tres tablas del
-- vault a nueve, que es precisamente la razón de que exista.
--
-- Se queda con la versión vigente de cada satélite. Para preguntar por el
-- estado del mundo en una fecha pasada habría que filtrar por `load_date`, y
-- ahí es donde el vault demuestra para qué servía guardarlo todo.
--
-- Los `LEFT JOIN` no son por prudencia genérica. Un pedido puede no tener
-- comercial resuelto (la cuenta que lo firmó no es un empleado), un empleado
-- puede no tener departamento y un cliente puede no tener país. Con `INNER`,
-- cada una de esas ausencias haría desaparecer el pedido entero del panel, que
-- es la forma más silenciosa de perder facturación por el camino.

{{ config(materialized = 'view') }}

WITH pedido AS (
    {{ satelite_vigente(ref('sat_order_status'), 'hk_order') }}
),

cliente AS (
    {{ satelite_vigente(ref('sat_customer_details'), 'hk_customer') }}
),

comercial AS (
    {{ satelite_vigente(ref('sat_employee_details'), 'hk_employee') }}
),

departamento AS (
    {{ satelite_vigente(ref('sat_department_details'), 'hk_department') }}
),

-- Departamento vigente de cada empleado. El enlace guarda todas las
-- adscripciones por las que ha pasado, así que sin esto un empleado que se
-- hubiese trasladado duplicaría todos sus pedidos.
adscripcion AS (
    {{ enlace_vigente(ref('link_employee_department'), 'hk_employee') }}
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
    -- El identificador numérico no dice nada en un panel. La tabla de
    -- referencia existe para esto.
    pais.country_name,
    pais.country_code,
    c.is_company,

    he.employee_id,
    -- "Sin asignar" en lugar de NULL: en un panel, una barra sin etiqueta se
    -- lee como un error de la herramienta, y esto es un dato real que conviene
    -- ver. Los importes de esos pedidos cuentan igual que los demás.
    coalesce(e.employee_name, 'Sin asignar')  AS salesperson_name,
    e.job_title                               AS salesperson_job,
    hd.department_id,
    coalesce(d.department_path, 'Sin departamento') AS department_path,
    coalesce(d.department_name, 'Sin departamento') AS department_name,

    p.team_id,
    coalesce(equipo.team_name, 'Sin equipo')  AS team_name,

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

LEFT JOIN {{ ref('ref_country') }} pais
    ON pais.country_id = c.country_id

LEFT JOIN {{ ref('link_order_employee') }} le
    ON le.hk_order = ho.hk_order
LEFT JOIN {{ ref('hub_employee') }} he
    ON he.hk_employee = le.hk_employee
LEFT JOIN comercial e
    ON e.hk_employee = he.hk_employee
LEFT JOIN adscripcion ad
    ON ad.hk_employee = he.hk_employee
LEFT JOIN {{ ref('hub_department') }} hd
    ON hd.hk_department = ad.hk_department
LEFT JOIN departamento d
    ON d.hk_department = hd.hk_department

LEFT JOIN {{ ref('ref_sales_team') }} equipo
    ON equipo.team_id = p.team_id
