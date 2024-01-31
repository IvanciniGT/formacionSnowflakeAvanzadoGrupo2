
-- seleccionar el wahouse (la infraestructura) que vamos a usar para procesar los datos
USE WAREHOUSE compute_wh;

-- Crear nos una Base de datos y un esuqmea dentro
CREATE DATABASE IF NOT EXISTS mibd;
CREATE SCHEMA IF NOT EXISTS mibd.mies;
USE SCHEMA mibd.mies;

-- CREAR UNA TABLA DE PERSONAS
CREATE TABLE IF NOT EXISTS personas (
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
CREATE TABLE IF NOT EXISTS personas_con_dni_valido (
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

-- Falta el procedimiento que sincroniza datos entre las tablas personas --[stream]--> personas_con_dni_valido
-- Una tarea que programe ese trabajo cada X tiempo