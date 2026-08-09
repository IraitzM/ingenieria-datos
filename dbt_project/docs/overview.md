{% docs __overview__ %}

# Almacén de ventas de Odoo

Este es el diccionario de datos del ejercicio del lago de datos. El origen es
[Odoo](https://www.odoo.com/), un ERP de código abierto, y el recorrido
completo (con sus decisiones de diseño) está contado en el apéndice
**Ejercicio: un lago de datos entero** del libro.

## Las capas

El almacén es un único fichero DuckDB con cuatro esquemas, y cada uno responde
a una pregunta distinta.

| Esquema | Capa | Para qué sirve |
|---|---|---|
| `raw` | Bronce | Reflejo de Odoo tal y como lo dejó dlt. No se consulta para analizar, se consulta para comprobar qué trajo la carga. |
| `staging` | Preparación | Vistas que absorben las rarezas del origen una sola vez: nombres en JSON, precios que están en otra tabla, identificadores que no casan entre módulos. |
| `vault` | Plata | El Data Vault: hubs, enlaces, satélites y tablas de referencia. Guarda historia, no responde preguntas. |
| `main` | Oro | Lo que consume el panel. Aquí el vault ya está montado y las métricas tienen nombre de negocio. |

El grafo de linaje (el botón azul de la esquina inferior derecha) enseña ese
recorrido de izquierda a derecha. Conviene mirarlo antes que esta lista de
modelos: explica mejor el proyecto que cualquier descripción.

## Por dónde empezar

* Si busca **un número para un informe**, mire los modelos del esquema `main`.
  `point_in_time_orders` y `point_in_time_order_lines` son el punto de entrada
  natural: traen el pedido y la línea con todo su contexto ya resuelto.
* Si busca **cómo era un dato hace un mes**, vaya a los satélites del esquema
  `vault`. Son de solo inserción y guardan todas las versiones.
* Si busca **de dónde sale un valor**, siga el linaje hacia atrás hasta `raw` y
  compárelo con Odoo.

## Lo que este catálogo no cubre

dbt solo conoce lo que pasa por sus `ref()` y sus `source()`. El tramo que va
de Odoo a `raw` lo hace dlt y aquí no aparece (las tablas de `raw` se dibujan
como el principio del mundo, cuando son la mitad de la historia), y el panel de
Rill que consume la capa oro tampoco. Coser los tres tramos es trabajo de un
catálogo de gobierno, no de dbt docs.

{% enddocs %}
