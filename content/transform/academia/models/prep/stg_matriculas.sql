-- La clave del enlace es el hash del conjunto de claves de negocio que
-- relaciona, de modo que la misma matrícula produzca siempre la misma clave.

select
    {{ hash_key(['id_alumno', 'id_asignatura']) }}  as hk_matricula,
    {{ hash_key('id_alumno') }}                     as hk_alumno,
    {{ hash_key('id_asignatura') }}                 as hk_asignatura,
    id_alumno,
    id_asignatura,
    _cargado_en                                     as load_date,
    _origen                                         as record_source
from {{ source('staging', 'cursa') }}
where id_alumno is not null
  and id_asignatura is not null
