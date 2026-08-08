-- Un satélite no puede tener dos versiones de la misma clave con la misma
-- fecha de carga. Si ocurre, la detección por hashdiff ha fallado y el
-- histórico deja de poder ordenarse: al preguntar por la versión vigente
-- habría un empate sin forma de resolverlo.
--
-- Esta es la invariante que sostiene todo el patrón de solo inserción, así que
-- merece una prueba propia. Una prueba singular devuelve las filas que no
-- deberían existir: si devuelve alguna, dbt falla.

SELECT 'sat_customer_details' AS modelo, CAST(hk_customer AS VARCHAR) AS clave, load_date, count(*) AS versiones
FROM {{ ref('sat_customer_details') }}
GROUP BY 1, 2, 3
HAVING count(*) > 1

UNION ALL

SELECT 'sat_order_status', CAST(hk_order AS VARCHAR), load_date, count(*)
FROM {{ ref('sat_order_status') }}
GROUP BY 1, 2, 3
HAVING count(*) > 1

UNION ALL

SELECT 'sat_product_pricing', CAST(hk_product AS VARCHAR), load_date, count(*)
FROM {{ ref('sat_product_pricing') }}
GROUP BY 1, 2, 3
HAVING count(*) > 1

UNION ALL

SELECT 'sat_order_line', CAST(hk_order_product AS VARCHAR), load_date, count(*)
FROM {{ ref('sat_order_line') }}
GROUP BY 1, 2, 3
HAVING count(*) > 1
