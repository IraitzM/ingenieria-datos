-- Capa oro: ficha de empleado.
--
-- Hermana de `customer_360`, y con la misma forma: la entidad completa con su
-- actividad agregada al lado. Cubre dos preguntas que en el origen viven en
-- módulos distintos y que aquí ya están juntas: quién es cada persona y qué ha
-- vendido.
--
-- La plantilla entera entra, venda o no. Es una decisión con consecuencias: si
-- solo entrasen los que tienen pedidos, el modelo pasaría de veinte filas a
-- dos y dejaría de servir para contar plantilla. Los que no venden salen con
-- cero, que es un dato, no un hueco.

{{ config(materialized = 'table') }}

WITH empleado AS (
    {{ satelite_vigente(ref('sat_employee_details'), 'hk_employee') }}
),

departamento AS (
    {{ satelite_vigente(ref('sat_department_details'), 'hk_department') }}
),

adscripcion AS (
    {{ enlace_vigente(ref('link_employee_department'), 'hk_employee') }}
),

ventas AS (
    SELECT
        employee_id,
        count(DISTINCT order_id)     AS pedidos,
        count(DISTINCT customer_id)  AS clientes,
        sum(amount_total)            AS facturacion_total,
        avg(amount_total)            AS ticket_medio,
        min(date_order)              AS primera_venta,
        max(date_order)              AS ultima_venta
    FROM {{ ref('point_in_time_orders') }}
    WHERE employee_id IS NOT NULL
    GROUP BY 1
)

SELECT
    he.employee_id,
    e.employee_name,
    e.work_email,
    e.job_title,
    e.active                                        AS empleado_activo,

    hd.department_id,
    coalesce(d.department_name, 'Sin departamento') AS department_name,
    coalesce(d.department_path, 'Sin departamento') AS department_path,

    coalesce(v.pedidos, 0)                          AS pedidos,
    coalesce(v.clientes, 0)                         AS clientes,
    coalesce(v.facturacion_total, 0)                AS facturacion_total,
    v.ticket_medio,
    v.primera_venta,
    v.ultima_venta,

    -- Marca de si la persona vende, calculada y no declarada. En el origen no
    -- existe ningún campo que diga "es comercial": lo dice su actividad.
    coalesce(v.pedidos, 0) > 0                      AS es_comercial
FROM {{ ref('hub_employee') }} he
INNER JOIN empleado e
    ON e.hk_employee = he.hk_employee
LEFT JOIN adscripcion ad
    ON ad.hk_employee = he.hk_employee
LEFT JOIN {{ ref('hub_department') }} hd
    ON hd.hk_department = ad.hk_department
LEFT JOIN departamento d
    ON d.hk_department = hd.hk_department
LEFT JOIN ventas v
    ON v.employee_id = he.employee_id
