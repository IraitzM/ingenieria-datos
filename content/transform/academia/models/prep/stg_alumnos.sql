-- Prepara el aterrizaje para el vault: calcula la clave hash de negocio,
-- la huella de los atributos y renombra los metadatos de carga al
-- vocabulario de Data Vault. No aplica ninguna regla de negocio.

select
    {{ hash_key('id_alumno') }}                            as hk_alumno,
    {{ hashdiff(['nombre', 'apellido', 'email']) }}        as hd_alumno,
    id_alumno,
    nombre,
    apellido,
    email,
    _cargado_en                                            as load_date,
    _origen                                                as record_source
from {{ source('staging', 'alumnos') }}
where id_alumno is not null
