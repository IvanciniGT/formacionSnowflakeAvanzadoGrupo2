
-- seleccionar el wahouse (la infraestructura) que vamos a usar para procesar los datos
USE WAREHOUSE compute_wh;

-- Crear nos una Base de datos y un esuqmea dentro
CREATE DATABASE IF NOT EXISTS mibd;
CREATE SCHEMA IF NOT EXISTS mibd.mies;
USE SCHEMA mibd.mies;

-- Me duplico en mi esquema la tabla de clientes.
-- De normal, podría hacer un CLONE
-- El CLONE es muy rápido, ya que no duplica los datos.
-- Desgraciadamente no podemos hacerlo... ya que Snowflake no nos deja hacer eso contra una BBDD de ejemplo
CREATE OR REPLACE TABLE mibd.mies.clientes AS SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.CUSTOMER LIMIT 0;
-- Me crea una tabla vacía pero con la misma estructura que la original

SELECT * FROM mibd.mies.clientes;

-- Me copio los datos de su tabla a la mia:
INSERT INTO mibd.mies.clientes SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.CUSTOMER;

-- En mi cluster ha tardado 13 segundos... teniendo en cuenta que tengo un MEDIUM : 4 creditos / hora
-- A vosotros 40 segundos, 37, 32, 37....

-- Si fuera proporcional, si mi máquina fuera 4 veces más rápida que la vuestra ... ya que pago 4 veces lo que vosotors, os debería haber tardado: 52 segundos.
-- Aquí veis de nuevo que una máquina más gordda me cuesta MUCHO MAS de la mejora que obtengo.
-- CUATRIPLICO PRECIO... tardo un 35% de lo que vosotros... pero no un 25%

SELECT count(*) FROM mibd.mies.clientes;

-- Voy a sacar los datos de federico!
SELECT * FROM mibd.mies.clientes WHERE C_CUSTOMER_SK = 1;
-- A por menchu
SELECT * FROM mibd.mies.clientes WHERE C_CUSTOMER_SK = 10000000;
-- Felipe
SELECT * FROM mibd.mies.clientes WHERE C_CUSTOMER_SK = 30000000;
-- Manuel
SELECT * FROM mibd.mies.clientes WHERE C_CUSTOMER_SK = 40000000;

ALTER SESSION SET use_cached_result = FALSE;

--- Para leer 1 dato... se está tragando la MITAD de los datos.. o más
-- Partitions scanned: 93
-- Partitions total: 157

-- Nos gusta eso? NI UN POQUITO... SOLUCION? CLUSTER KEY
ALTER TABLE mibd.mies.clientes CLUSTER BY (C_CUSTOMER_SK); -- (1)


-- Voy a sacar los datos de federico!
SELECT * FROM mibd.mies.clientes WHERE C_CUSTOMER_SK = 2;
-- A por menchu
SELECT * FROM mibd.mies.clientes WHERE C_CUSTOMER_SK = 10000001;
-- Felipe
SELECT * FROM mibd.mies.clientes WHERE C_CUSTOMER_SK = 30000001;
-- Manuel
SELECT * FROM mibd.mies.clientes WHERE C_CUSTOMER_SK = 40000001;

--- Arriba (1) lo único que hemos hecho es pedirle a snowflake cómo me gustaría agrupar los datos... y snowflake contesta: OK
-- Y Snowflake se pone en segundo planto  ir optimizando todas esas particiones... Se tiene que reescribir 150 ficheros... con 65M de datos... eso no lo ha hecho en 150ms.


-- Voy a sacar los datos de federico!
SELECT * FROM mibd.mies.clientes WHERE C_CUSTOMER_SK = 3;
-- A por menchu
SELECT * FROM mibd.mies.clientes WHERE C_CUSTOMER_SK = 10000003;
-- Felipe
SELECT * FROM mibd.mies.clientes WHERE C_CUSTOMER_SK = 30000003;
-- Manuel
SELECT * FROM mibd.mies.clientes WHERE C_CUSTOMER_SK = 40000003;

------------ TENEMOS UNA TABLA DE VENTAS POR LA WEB:     WEB_SALES
--- Queremos, el total de ventas por meses del año 20??  DATE_DIM

--- PRIMERO os copiais los datos que necesiteis.
--- SEGUNDO ejecutais la query SIN CLUSTERING KEYS adicionales

--- TERCERO creais clustering keys... los que considereis...... VOY POCO A POCO.... metiendo los clustering keys.
--- CUARTO Pruebo de nuevo

CREATE OR REPLACE TABLE mibd.mies.ventas AS SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.WEB_SALES LIMIT 0;
SELECT * FROM mibd.mies.ventas;
INSERT INTO mibd.mies.ventas SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.WEB_SALES LIMIT 1000000000;


CREATE OR REPLACE TABLE mibd.mies.fechas AS SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.DATE_DIM LIMIT 0;
SELECT * FROM mibd.mies.fechas;
INSERT INTO mibd.mies.fechas SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.DATE_DIM;

SELECT f.d_moy, count(*) as ventas
FROM mibd.mies.fechas f
    JOIN mibd.mies.ventas v ON f.d_date_sk = v.ws_sold_date_sk
WHERE d_year = 2001
GROUP BY f.d_moy
ORDER BY d_moy;

