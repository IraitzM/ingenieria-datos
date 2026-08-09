{#
  Descripciones de las columnas técnicas del Data Vault.

  Estas columnas aparecen en los veinte modelos del esquema `vault` y en varios
  de la capa oro. Escritas a mano en cada YAML serían veinte copias que se
  desincronizan a la primera corrección; escritas aquí una vez y referenciadas
  con `{{ doc('...') }}`, hay un solo sitio que mantener.

  Es para lo que sirven los bloques de documentación de dbt, y la ganancia se
  nota justo cuando el proyecto pasa de cuatro modelos a veinte.
#}

{% docs dv_load_date %}
Momento en el que esta fila entró en el almacén. **No es una fecha de negocio**:
no dice cuándo ocurrió el hecho, dice cuándo nos enteramos.

Todas las tablas construidas en la misma ejecución comparten valor, porque sale
de `run_started_at` a través de la macro `dv_load_date()`. Esa propiedad es la
que permite reconstruir el estado completo del almacén en cualquier carga
pasada, y la que hace que ordenar por esta columna dé el histórico de una clave.
{% enddocs %}

{% docs dv_record_source %}
Sistema del que procede la fila, `odoo_erp` en todo este proyecto.

Con un solo origen parece una columna decorativa y en cuanto aparece el segundo
deja de serlo: es lo que permite responder a "¿esto lo dijo el ERP o el CRM?"
cuando dos sistemas describen al mismo cliente y no coinciden.
{% enddocs %}

{% docs dv_hashdiff %}
Huella de los atributos descriptivos del satélite, calculada con la macro
`hashdiff()`.

En cada carga se compara la huella nueva con la última guardada para esa clave:
si coinciden no se escribe nada, y si difieren entra una versión nueva. Es lo
que evita que el satélite crezca en cada ejecución aunque no haya cambiado nada.

La huella se calcula sobre los atributos, nunca sobre la clave ni sobre
`load_date`. Meter cualquiera de los dos dentro haría que toda fila pareciese
distinta en cada carga y la detección de cambios dejaría de funcionar.
{% enddocs %}

{% docs dv_hash_key %}
Clave hash de la clave de negocio, calculada con `md5()` sobre los componentes
unidos por un separador (macro `hash_clave()`).

El separador no es un detalle menor: concatenando en crudo, `('ab', 'c')` y
`('a', 'bc')` producen el mismo hash y dos entidades distintas colapsan en una.

Sirve para unir las tablas del vault sin arrastrar claves compuestas y para que
los enlaces tengan siempre el mismo ancho, venga la clave de negocio de donde
venga.
{% enddocs %}

{% docs dv_link_hash_key %}
Clave hash del enlace: el `md5()` de las claves de negocio que participan en la
relación.

Es la clave primaria del enlace y el punto de anclaje de sus satélites, que es
justo lo que permite describir una relación sin ensuciarla con atributos.
{% enddocs %}

{% docs dv_degenerate_key %}
Clave degenerada: el identificador que el origen daba a la relación y que no
pertenece a ninguno de los hubs que el enlace une.

Se conserva porque es lo que permite volver al documento original en el ERP, y
porque en este caso es también lo que fija el grano del enlace.
{% enddocs %}
