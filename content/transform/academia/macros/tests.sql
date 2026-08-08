{# Test genérico propio: comprueba que la combinación de varias columnas no
   se repite. Es el equivalente a una clave primaria compuesta y en un
   satélite es la comprobación que de verdad importa, porque garantiza que
   no hemos cargado dos veces la misma versión de un registro.

   dbt_utils trae uno equivalente, pero escribirlo a mano evita depender de
   un paquete externo y enseña que un test no es más que una consulta que
   no debe devolver filas. #}

{% test unique_combination(model, columnas) %}

select
    {{ columnas | join(', ') }},
    count(*) as repeticiones
from {{ model }}
group by {{ columnas | join(', ') }}
having count(*) > 1

{% endtest %}
