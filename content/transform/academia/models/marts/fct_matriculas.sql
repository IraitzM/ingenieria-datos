-- Tabla de hechos del modelo en estrella, con las claves de negocio que
-- el usuario reconoce en lugar de las claves hash del vault.

select
    link.hk_matricula           as matricula_id,
    hub_a.id_alumno             as alumno_id,
    hub_s.id_asignatura         as asignatura_id,
    link.load_date              as fecha_matricula,
    link.record_source          as origen
from {{ ref('link_matricula') }} as link
join {{ ref('hub_alumno') }}     as hub_a on hub_a.hk_alumno = link.hk_alumno
join {{ ref('hub_asignatura') }} as hub_s on hub_s.hk_asignatura = link.hk_asignatura
