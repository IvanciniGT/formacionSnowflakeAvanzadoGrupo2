
-- seleccionar el wahouse (la infraestructura) que vamos a usar para procesar los datos
USE WAREHOUSE compute_wh;

-- Crear nos una Base de datos y un esuqmea dentro
CREATE DATABASE IF NOT EXISTS mibd;
CREATE SCHEMA IF NOT EXISTS mibd.mies;
USE SCHEMA mibd.mies;

-- CREAR UNA TABLA DE PERSONAS
CREATE OR REPLACE TABLE personas (
    id NUMBER NOT NULL,
    nombre STRING NOT NULL,
    dni STRING NULL
);

-- Creamos un stream sobre la tabla de personas... para monitorizar los cambios en la tabla
CREATE OR REPLACE STREAM cambios_en_personas ON TABLE personas;

--- Metemos a unas cuantas personas
INSERT INTO personas (id, nombre, dni)
VALUES
    (1, 'Felipe', '12345678A'),
    (2, 'Menchu', '23000000T' ),
    (3, 'Lucrecia', '23000023t' ),
    (4, 'Marcial',  NULL );

SELECT * FROM personas;
SELECT * FROM cambios_en_personas;

    
-- CREAR UNA TABLA DE PERSONAS CON DNI VALIDADO
CREATE OR REPLACE TABLE personas_con_dni_valido (
    id NUMBER NOT NULL,
    nombre STRING NOT NULL,
    dni_numero NUMBER NOT NULL,
    dni_letra STRING NOT NULL
);

-- Quiero una tarea que cada X tiempo sincronice (transpase datos)
-- de la tabla de personas a la tabla de personas_con_dni_valido

-- necesitamos una función que valide un DNI
CREATE OR REPLACE FUNCTION validar_dni(dni STRING)
RETURNS VARIANT -- vamos a devolver un JSON: dni_original, letra, numero, valido
LANGUAGE JAVASCRIPT
AS
$$
    var resultado = {
                        dni: null,
                        valido: false,
                        letra: null,
                        numero: null
                    };
    if (!DNI || DNI === null) {
        return resultado;
    }
    resultado.dni = DNI.toUpperCase();
    
    // Lo primero voy a mirar el formato... a través de una expresión regular
    var patron = /^[0-9]{1,8}[A-Z]$/;
    if (patron.test(resultado.dni)) {
        // Tengo que validar la letra
        var letra = resultado.dni.substr(-1);
        var numero = parseInt(resultado.dni.substr(0, resultado.dni.length - 1));
        resultado.letra = letra;
        resultado.numero = numero;

        var letras_validas = "TRWAGMYFPDXBNJZSQVHLCKE";
        var restoDivision  = numero % 23;
        var letraQueDeberiaTener = letras_validas.substr(restoDivision, 1);
        if (letraQueDeberiaTener === letra) {
            resultado.valido = true;
        }
    }

    return resultado;
$$;

SELECT validar_dni(NULL);


SELECT validar_dni('230000t') as resultado,
    resultado['valido']::Boolean as valido,
    resultado['numero']::Number as numero,
    resultado['letra']::String as letra;

    
SELECT id, nombre, dni, validar_dni(dni) as resultado,
    resultado['valido']::Boolean as valido,
    resultado['numero']::Number as numero,
    resultado['letra']::String as letra
FROM personas;

SELECT * FROM cambios_en_personas;
-- Falta el procedimiento que sincroniza datos entre las tablas personas --[stream:cambios_en_personas]--> personas_con_dni_valido
CREATE OR REPLACE PROCEDURE personas_con_dni_valido()
RETURNS VARIANT -- JSON con flas filas insertadas / eliminadas
LANGUAGE JAVASCRIPT
AS
$$
    // Comenzar transaccion
    snowflake.execute({sqlText: 'BEGIN'});
    // Borrar datos eliminados o aqctualizados
    
    snowflake.execute({sqlText: `DELETE FROM personas_con_dni_valido 
                                 WHERE id IN (
                                    SELECT id FROM cambios_en_personas WHERE metadata$action = 'DELETE'
                                )`});
    
    // Insertar datos nuevos o actualizados, siempre que sean validos
    snowflake.execute({sqlText: `INSERT INTO personas_con_dni_valido (id, nombre, dni_letra, dni_numero)
                                 SELECT id, nombre, letra, numero FROM (
                                    SELECT id, 
                                        nombre, 
                                        validar_dni(dni) as resultado, 
                                        resultado['letra'] as letra, 
                                        resultado['numero'] as numero
                                    FROM 
                                        cambios_en_personas WHERE metadata$action = 'INSERT'
                                    AND 
                                        resultado['valido'] = true
                                ) validados`});
    // Commit
    snowflake.execute({sqlText: 'COMMIT'});
$$;
-- Una tarea que programe ese trabajo cada X tiempo

CALL personas_con_dni_valido();


CREATE OR REPLACE TASK tarea_personas_con_dni_valido
    WAREHOUSE = compute_wh
    SCHEDULE  = 'USING CRON * * * * * Europe/Madrid' --UTC' -- CADA MINUTO
    AS
        CALL personas_con_dni_valido();

ALTER TASK tarea_personas_con_dni_valido RESUME;



SELECT * FROM personas_con_dni_valido;
SELECT * FROM personas;
DELETE FROM personas WHERE id = 2;

SELECT * FROM personas_con_dni_valido;
SELECT * FROM cambios_en_personas;


INSERT INTO personas (id, nombre, dni)
VALUES
    (5, 'Jaime', '23000023T');

    
-- ESPERAR AL MENOS UN MINUTO

SELECT * FROM personas_con_dni_valido;
SELECT * FROM cambios_en_personas;
ALTER TASK tarea_personas_con_dni_valido SUSPEND;