-- Capa oro: la línea de pedido con todo su contexto.
--
-- Es el modelo de grano más fino del almacén y el que sostiene el panel de
-- catálogo. La diferencia con `point_in_time_orders` no es de detalle sino de
-- **grano**, y confundirlos es el error que más veces convierte un panel en
-- una fuente de números que no cuadran:
--
--   * a grano de pedido, `sum(amount_total)` es la facturación;
--   * a grano de línea, sumar `amount_total` la multiplica por el número de
--     líneas de cada pedido.
--
-- Por eso aquí el importe del pedido no se arrastra. Lo que se suma en esta
-- vista es `price_total`, que es el importe de la línea, y los pedidos se
-- cuentan con `count(distinct order_id)`, nunca con `count(*)`.
--
-- La categoría que se atribuye es la vigente del producto. Para analizar con
-- la categoría que tenía en el momento de la venta habría que cruzar por
-- `load_date`, y el vault guarda lo necesario para hacerlo.

{{ config(materialized = 'view') }}

WITH linea AS (
    {{ satelite_vigente(ref('sat_order_line'), 'hk_order_product') }}
),

producto AS (
    {{ satelite_vigente(ref('sat_product_pricing'), 'hk_product') }}
),

categoria AS (
    {{ satelite_vigente(ref('sat_category_details'), 'hk_category') }}
),

clasificacion AS (
    {{ enlace_vigente(ref('link_product_category'), 'hk_product') }}
)

SELECT
    lop.order_line_id,
    ho.order_id,
    o.order_reference,
    o.date_order,
    o.order_state,

    hp.product_id,
    pr.product_name,
    pr.product_code,
    pr.product_type,
    pr.list_price,

    hcat.category_id,
    coalesce(cat.category_path, 'Sin categoría') AS category_path,
    coalesce(cat.category_name, 'Sin categoría') AS category_name,

    l.line_description,
    l.quantity,
    l.qty_delivered,
    l.qty_invoiced,
    l.price_unit,
    l.discount,
    l.price_subtotal,
    l.price_total,

    -- Lo que el descuento se llevó, en euros. Es la resta entre lo que habría
    -- costado a precio de línea sin descuento y lo que se cobró, y sale más a
    -- cuenta calcularla una vez aquí que dejar que cada panel la reinvente.
    (l.price_unit * l.quantity) - l.price_subtotal AS importe_descuento,

    o.customer_id,
    o.customer_name,
    o.city,
    o.country_name,
    o.employee_id,
    o.salesperson_name,
    o.department_path,
    o.team_name,

    l.load_date AS vault_load_date
FROM {{ ref('link_order_product') }} lop
INNER JOIN linea l
    ON l.hk_order_product = lop.hk_order_product
INNER JOIN {{ ref('hub_order') }} ho
    ON ho.hk_order = lop.hk_order
INNER JOIN {{ ref('hub_product') }} hp
    ON hp.hk_product = lop.hk_product
LEFT JOIN producto pr
    ON pr.hk_product = hp.hk_product

-- El contexto del pedido no se vuelve a montar: se toma de la vista que ya lo
-- resuelve. Repetir aquí el recorrido por el vault sería la segunda copia de
-- una lógica que ya existe, y la primera en quedarse desactualizada.
INNER JOIN {{ ref('point_in_time_orders') }} o
    ON o.order_id = ho.order_id

LEFT JOIN clasificacion cl
    ON cl.hk_product = hp.hk_product
LEFT JOIN {{ ref('hub_category') }} hcat
    ON hcat.hk_category = cl.hk_category
LEFT JOIN categoria cat
    ON cat.hk_category = hcat.hk_category
