-- Correspondencia entre el pedido y el empleado que lo firmó.
--
-- Este modelo existe porque el origen no da esa relación hecha. El pedido
-- guarda `user_id`, que es una **cuenta de Odoo** (`res_users`), y la plantilla
-- vive en `hr_employee`, que a su vez apunta a la cuenta con su propio
-- `user_id`. Son dos identificadores distintos de la misma persona y hay que
-- casarlos por el único sitio donde coinciden.
--
-- Que la resolución esté aquí y no dentro del enlace del vault es
-- deliberado. El enlace debe poder escribirse con las claves de negocio ya
-- resueltas; si la traducción viviera dentro de él, cada modelo del vault que
-- necesitase al comercial tendría que repetirla, y bastaría con que dos la
-- resolvieran distinto para que el almacén contase dos historias.
--
-- El `INNER JOIN` deja fuera los pedidos cuyo comercial no es empleado (un
-- usuario del portal, una cuenta de integración o alguien dado de baja cuya
-- ficha se borró). Es la opción segura: un enlace hacia un empleado que no
-- está en el hub rompe el vault, y la prueba `relationships` lo cazaría. Lo
-- que sí conviene es saber cuántos pedidos se quedan por el camino, y de eso
-- se encarga `tests/cobertura_comercial.sql`, que avisa sin romper la carga.

SELECT
    p.order_id,
    e.employee_id,
    p.salesperson_user_id
FROM {{ ref('stg_orders') }} p
INNER JOIN {{ ref('stg_employees') }} e
    ON e.user_id = p.salesperson_user_id
WHERE p.salesperson_user_id IS NOT NULL
