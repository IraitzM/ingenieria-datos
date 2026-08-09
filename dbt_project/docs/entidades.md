{#
  Definiciones de negocio de las entidades del almacén.

  Estas descripciones son el germen de un glosario: contestan a "¿qué es un
  cliente aquí?", que es la pregunta que más discusiones ahorra y la que ningún
  esquema de base de datos responde. Al referenciarlas desde los hubs, los
  satélites y los modelos de la capa oro, la misma definición sale en todos los
  sitios donde aparece la entidad.
#}

{% docs entidad_cliente %}
Contacto de Odoo (`res_partner`) que ha firmado al menos un pedido o que está
dado de alta como tal.

La lista incluye personas y empresas, y en el origen convive con proveedores,
empleados y direcciones de envío: en Odoo **todos son la misma tabla**. El
contador `customer_rank` pretende distinguirlos y no es de fiar, porque Odoo lo
incrementa desde el flujo de su interfaz y no desde la base de datos; los datos
de demostración lo dejan a cero incluso para quien tiene pedidos confirmados.

Instalar el módulo de recursos humanos aumenta esta tabla sin que nadie dé de
alta un cliente: cada empleado trae su propio contacto asociado. Es una razón
más para no confiar en el número de filas como medida de nada.
{% enddocs %}

{% docs entidad_pedido %}
Pedido de venta confirmado (`sale_order` en estado `sale` o `done`).

Los presupuestos que nunca llegaron a pedido (`draft` y `sent`) se descartan en
la capa de staging. Es una decisión de negocio y está tomada en un solo sitio,
de modo que ningún modelo de aguas abajo tiene que acordarse de repetirla.
{% enddocs %}

{% docs entidad_producto %}
Variante concreta de producto (`product_product`), que es lo que de verdad se
vende y lo que aparece en la línea de pedido.

No hay que confundirla con la plantilla (`product_template`), que es la ficha
comercial de la que cuelgan todas las variantes y donde viven el nombre y el
precio de tarifa. Un mismo nombre de catálogo puede corresponder a varias
variantes.
{% enddocs %}

{% docs entidad_empleado %}
Persona dada de alta en el módulo de recursos humanos (`hr_employee`).

Un empleado no es lo mismo que una cuenta de usuario de Odoo: la mayoría de la
plantilla no tiene cuenta, y las cuentas que existen pueden no corresponder a
nadie de la plantilla. Cuando el pedido dice quién es el comercial, lo que
guarda es la cuenta; llegar desde ahí al empleado exige un salto que resuelve
`stg_order_salesperson`.

Del origen solo se traen los datos profesionales. Todo lo demás que guarda esa
tabla (documentos de identidad, fecha de nacimiento, situación familiar) se
queda en el ERP.
{% enddocs %}

{% docs entidad_departamento %}
Unidad organizativa del ERP (`hr_department`), en árbol: cada departamento
puede colgar de otro.

La ruta completa (`department_path`) es lo que conviene enseñar en un panel,
porque un nombre corto como "R&D USA" no dice de qué rama cuelga.
{% enddocs %}

{% docs entidad_categoria %}
Categoría de producto (`product_category`), también en árbol.

El nombre corto no identifica la categoría: en los datos de demostración hay
dos llamadas "Saleable" en ramas distintas del árbol. Para agrupar hay que usar
la ruta completa.
{% enddocs %}

{% docs entidad_equipo %}
Equipo comercial al que se atribuye el pedido (`crm_team`).

Se trata como tabla de referencia y no como hub: en este almacén el equipo solo
sirve para decodificar el `team_id` del pedido. Si algún día el equipo pasara a
tener atributos propios que interese historiar (objetivos, responsable,
composición), el modelo tendría que ascenderlo a hub con su satélite.
{% enddocs %}

{% docs entidad_pais %}
País del catálogo de Odoo (`res_country`).

Tabla de referencia de manual: doscientas cincuenta filas que no cambian casi
nunca y que existen para que `country_id = 233` se lea como "United States". La
clave que vale fuera de esta instalación es el código ISO, no el identificador
numérico.
{% enddocs %}
