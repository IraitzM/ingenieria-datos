select
    hub.id_asignatura           as asignatura_id,
    stg.nombre                  as asignatura,
    hub.load_date               as alta_en_almacen
from {{ ref('hub_asignatura') }} as hub
join {{ ref('stg_asignaturas') }} as stg
  on stg.hk_asignatura = hub.hk_asignatura
