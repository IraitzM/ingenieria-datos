-- Categorías de producto.
--
-- Mismo patrón de árbol que los departamentos: `parent_id` y una ruta completa
-- ya calculada en el origen ("All / Saleable / Office Furniture").
--
-- Aquí hay un detalle que solo se ve mirando los datos: hay dos categorías
-- distintas llamadas "Saleable", una colgando de "All" y otra de
-- "All / Saleable / Services". El nombre corto no identifica nada, así que
-- agrupar por él en un panel mezclaría dos cosas que no son la misma. Por eso
-- el modelo se lleva las dos columnas y la ruta es la que se usa para
-- presentar.

SELECT
    id                AS category_id,
    name              AS category_name,
    complete_name     AS category_path,
    parent_id         AS parent_category_id,
    create_date,
    write_date
FROM {{ source('raw', 'raw_product_categories') }}
WHERE id IS NOT NULL
