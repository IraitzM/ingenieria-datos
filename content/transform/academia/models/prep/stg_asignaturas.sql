select
    {{ hash_key('id_asignatura') }}     as hk_asignatura,
    {{ hashdiff(['nombre']) }}          as hd_asignatura,
    id_asignatura,
    nombre,
    _cargado_en                         as load_date,
    _origen                             as record_source
from {{ source('staging', 'asignaturas') }}
where id_asignatura is not null
