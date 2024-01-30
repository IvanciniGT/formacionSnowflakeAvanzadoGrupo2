

-- seleccionar el wahouse (la infraestructura) que vamos a usar para procesar los datos
USE WAREHOUSE compute_wh;

-- Crear nos una Base de datos y un esuqmea dentro
CREATE DATABASE IF NOT EXISTS mibd;
CREATE SCHEMA IF NOT EXISTS mibd.mies;
USE SCHEMA mibd.mies;

--

CREATE OR REPLACE TABLE mascotas (
    id NUMBER NOT NULL,
    nombre STRING NOT NULL,
    raza STRING NULL
);

INSERT INTO mascotas (id, nombre, raza)
VALUES
    (1, 'Pipo', 'Perro'),
    (2, 'Pepo', 'Gato' ),
    (3, 'Pupi',  NULL  )
;

SELECT * FROM mascotas;

CREATE OR REPLACE STREAM cambios_en_mascotas ON TABLE mascotas;

SELECT * FROM cambios_en_mascotas;

INSERT INTO mascotas (id, nombre, raza)
VALUES
    (4, 'Peco', 'Lagarto'),
    (5, 'Pico', 'Tiburón' ),
    (6, 'Poca',  NULL  )
;

SELECT * FROM mascotas;
SELECT * FROM cambios_en_mascotas;
-- Los Streams, no duplican datos... son muy ligeros de crear... 
-- y de hecho en muchas ocasiones tenemos MULTIPLES streams sobre una UNICA TABLA



CREATE OR REPLACE TABLE nombres_mascotas (
    id NUMBER NOT NULL,
    nombre STRING NOT NULL
);

INSERT INTO nombres_mascotas SELECT id, nombre FROM cambios_en_mascotas WHERE METADATA$ACTION = 'INSERT';
SELECT * FROM nombres_mascotas;

-- Cuando usamos datos de un STREAM dentro de una transacción (INSERT, DELETE, UPDATE) los datos son consumidos del STREAM
SELECT * FROM cambios_en_mascotas;

INSERT INTO mascotas (id, nombre, raza)
VALUES
    (7, 'Melo', 'Perrito'),
    (8, 'Milu', 'Elefante' ),
    (9, 'Mola',  NULL  )
;
SELECT * FROM cambios_en_mascotas;
DELETE FROM mascotas WHERE id = 1;
SELECT * FROM mascotas;
SELECT * FROM cambios_en_mascotas;

INSERT INTO nombres_mascotas SELECT id, nombre FROM cambios_en_mascotas WHERE METADATA$ACTION = 'INSERT';
SELECT * FROM nombres_mascotas;
SELECT * FROM cambios_en_mascotas;
-- ojo: Que los datos no los consuminos solo si los filtramos... se consumen todos.

UPDATE mascotas SET raza = 'papagayo' WHERE raza IS NULL;
SELECT * FROM cambios_en_mascotas;

BEGIN; -- Iniciar una transacción
SELECT * FROM cambios_en_mascotas;
DELETE FROM mascotas;
SELECT * FROM mascotas;
SELECT * FROM cambios_en_mascotas;
COMMIT;

SELECT * FROM mascotas;
SELECT * FROM cambios_en_mascotas;
-- El STREAM se va actualizando... datos que antes había modificado... y después BORRADO... ya solo aparecen como borrados
