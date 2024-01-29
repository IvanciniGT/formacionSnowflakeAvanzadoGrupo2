
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


-- Cuántas ventas he tenido?
SELECT COUNT(*) FROM ventas;

-- Tenemos una columna llamada ws_sold_date_sk // Contiene el día de la venta
-- En cuántos dias he hecho ventas?
SELECT COUNT(DISTINCT ws_sold_date_sk) FROM ventas;
SELECT COUNT(ws_sold_date_sk) FROM ventas GROUP BY ws_sold_date_sk;
SELECT COUNT(*) FROM (SELECT DISTINCT ws_sold_date_sk FROM ventas);
SELECT APPROX_COUNT_DISTINCT(ws_sold_date_sk) FROM ventas;          -- da una aproximación... pero muy buena... y muy rápida!

SELECT 
    COUNT_IF(ws_net_paid  > 1000),
    COUNT_IF(ws_net_paid  > 2000),
    COUNT_IF(ws_net_paid  > 5000),
    COUNT_IF(ws_net_paid  > 10000)
FROM ventas;

---
-- Me gustaría saber las 5 formas de envío más usadas... y cuantas ventas se han mandado según esas formas de envío
-- CAMPO: ws_ship_mode_sk
SELECT count(*) from ventas where ws_ship_mode_sk is null;

SELECT 
    ws_ship_mode_sk,
    count(*) as recuento
FROM 
    ventas
WHERE 
    ws_ship_mode_sk is not null
GROUP BY ws_ship_mode_sk
ORDER BY recuento DESC
LIMIT 5;

SELECT APPROX_TOP_K(ws_ship_mode_sk, 5) 
FROM ventas;
---
WITH top_ventas AS (
    SELECT APPROX_TOP_K(ws_ship_mode_sk, 5) as ventas
    FROM ventas
)
SELECT 
    value[0]::INT as tipo_envio,
    TO_NUMBER(value[1]) as recuento
FROM 
    top_ventas,
    LATERAL FLATTEN (top_ventas.ventas);

---
--- Me gustaría saber el importe máximo que recoge el 95% de las ventas
SELECT 
    APPROX_PERCENTILE(ws_net_paid, 0.95) -- = 8625.80 -- 0,5 MEDIANA
FROM ventas;

-- Cuántas ventas hay con importe inferior a 8625.80 entre el número de ventas totales
SELECT 
    COUNT_IF(ws_net_paid < 8625.80) as menores,
    count(*) as total,
    menores/total
FROM 
    ventas; -- 0.949883

-- Dame el ID de los productos (ws_item_sk)  que se han vendido con más cobro (ws_net_paid máximo)
SELECT 
    ws_item_sk
    , MAX(ws_net_paid) as importe_maximo
FROM 
    ventas
WHERE 
    ws_net_paid is not null
GROUP BY 
    ws_item_sk
ORDER BY importe_maximo DESC
LIMIT 5;

---
WITH top_productos AS (
    SELECT 
        MAX_BY(ws_item_sk,ws_net_paid, 5) as maximos -- MIN_BY
    FROM ventas
)
SELECT value::INT as top_product_id
FROM top_productos, LATERAL FLATTEN (top_productos.maximos);


SELECT ws_item_sk, ws_net_paid FROM ventas WHERE ws_item_sk IN (305408, 30973) ORDER BY ws_net_paid DESC;

---
-- Generar tablas de datos dentro de una query
SELECT 
    * -- Las columas reciben como nombre: column1, column2....
FROM
    values 
        (1,'a'),
        (1, null),
        (2, null),
        (null, 'a'),
        (null, null);
---
SELECT 
    column1,
    column2,
    COALESCE(column1, column2) as primer_no_nulo,
    IFF(column1 is null,'NULO','NO NULO') as nulo,
    IFF(column2 > 3,'MAYOR','NO MAYOR') as mayor_que_3,
    IFNULL(column1, -5) as modificado,
    DECODE(column1, 1, 'UNO', NULL, 'NULO', 'OTRO') as col1_texto
FROM
    values 
        (1,2),
        (1, null),
        (2, null),
        (null,5),
        (null, null);

---
-- FECHAS

SELECT 
    SYSDATE(),           -- Me devuelve el timestamp actual (fecha+hora)  trabaja sin zona horaria (UTC... zona 0)
    CURRENT_TIMESTAMP(); -- Me devuelve el timestamp actual (fecha+hora)  trabaja con la zona horaria de la sesión del usuario

ALTER SESSION SET TIMEZONE = 'Europe/Lisbon';
SELECT 
    SYSDATE(),           -- Me devuelve el timestamp actual (fecha+hora)  trabaja sin zona horaria (UTC... zona 0)
    CURRENT_TIMESTAMP(); -- Me devuelve el timestamp actual (fecha+hora)  trabaja con la zona horaria de la sesión del usuario

ALTER SESSION SET TIMEZONE = 'Europe/Madrid';
SELECT 
    SYSDATE(),           -- Me devuelve el timestamp actual (fecha+hora)  trabaja sin zona horaria (UTC... zona 0)
    CURRENT_TIMESTAMP(),  -- Me devuelve el timestamp actual (fecha+hora)  trabaja con la zona horaria de la sesión del usuario
    LOCALTIMESTAMP,
    CURRENT_DATE,
    CURRENT_TIME,
    LOCALTIME;
    
SELECT 
    SYSDATE(),           -- Me devuelve el timestamp actual (fecha+hora)  trabaja sin zona horaria (UTC... zona 0)
    CURRENT_TIMESTAMP,  -- Me devuelve el timestamp actual (fecha+hora)  trabaja con la zona horaria de la sesión del usuario
    LOCALTIMESTAMP(),
    CURRENT_DATE(),
    CURRENT_TIME(),
    LOCALTIME();
-- LAs funciones sin arrgumentos, las puedo invocar sin parentesis.
ALTER SESSION SET TIMESTAMP_LTZ_OUTPUT_FORMAT = 'YYYY-MM-DD HH24:MI:SS';
ALTER SESSION SET TIMESTAMP_NTZ_OUTPUT_FORMAT = 'YYYY-MM-DD HH24:MI:SS';

SELECT 
    SYSDATE(),           -- Me devuelve el timestamp actual (fecha+hora)  trabaja sin zona horaria (UTC... zona 0)
    CURRENT_TIMESTAMP,  -- Me devuelve el timestamp actual (fecha+hora)  trabaja con la zona horaria de la sesión del usuario
    LOCALTIMESTAMP(),
    CURRENT_DATE(),
    CURRENT_TIME(),
    LOCALTIME();

SELECT TO_DATE('29/01/2024', 'DD/MM/YYYY'),TO_DATE('01/29/2024', 'MM/DD/YYYY');
SELECT TO_DATE('29/043/2024', 'DD/MM/YYYY'),TO_DATE('01/29/2024', 'MM/DD/YYYY'); -- No cumple formato. ERROR Y se para query
SELECT TRY_TO_DATE('29/043/2024', 'DD/MM/YYYY'),TO_DATE('01/29/2024', 'MM/DD/YYYY'); -- No cumple formato, se devuelve null y sigue la query
SELECT TO_NUMBER('1237465');
SELECT TO_NUMBER('1237465a');
SELECT TRY_TO_NUMBER('1237465'),TRY_TO_NUMBER('1237465a');

--DATEADD
-----
-- Además de todas las funciones típicas de SQL, aprovechando el tema del JSON, tenemos algunas funciones adicionales chulas

WITH frutas AS (
    SELECT 
        column1 as fruta,
        column2 as colores
    FROM 
        values 
        ('manzana', 'roja,verde,amarilla'),
        ('ciruela', 'morada,verde,amarilla')
)
SELECT 
    fruta,
    colores,
    split(colores,',') as color_array
FROM frutas
;

-- Quiero cada fruta con cada uno de sus colores disponibles... es decir, quiero acabar con 6 filas.
WITH frutas AS (
    SELECT 
        column1 as fruta,
        column2 as colores
    FROM 
        values 
        ('manzana', 'roja,verde,amarilla'),
        ('ciruela', 'morada,verde,amarilla')
)
SELECT 
    --fruta,
    --colores,
    --*
    fruta,
    value::string as color
FROM 
    frutas,
    LATERAL FLATTEN (split(colores,','))
;
--- TODAS LAS FUNCIONES DE SNOWFLAKE: https://docs.snowflake.com/sql-reference/functions

--- Funciones de ventana

-- Importe total cobrado neto por dia
WITH importes_por_dia_2000 AS (
    SELECT
        d_year,
        d_moy,
        d_dom,
        sum(ws_net_paid) as importe_total_dia
    FROM
        --ventas
        SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.WEB_SALES as ventas
        --, fechas
        INNER JOIN fechas ON ventas.ws_sold_date_sk = fechas.d_date_sk
    WHERE 
        --ventas.ws_sold_date_sk = fechas.d_date_sk and
        fechas.d_year = 2000
    GROUP BY 
        d_year,
        d_moy,
        d_dom
)
SELECT 
    d_year,
    d_moy,
    d_dom,
    importe_total_dia,
    SUM(importe_total_dia) OVER(PARTITION BY d_moy ) as importe_total_mensual,
    SUM(importe_total_dia) OVER() as importe_total_anual,
    RANK() OVER( ORDER BY importe_total_dia DESC) as ranking_anual,
    RANK() OVER( PARTITION BY d_moy ORDER BY importe_total_dia DESC) as ranking_mensual,
    SUM(importe_total_dia) OVER(
        ORDER BY d_year, d_moy, d_dom
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as acumulado_anual,
    SUM(importe_total_dia) OVER(
        PARTITION BY d_moy
        ORDER BY d_year, d_moy, d_dom
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as acumulado_mensual,
    AVG(importe_total_dia) OVER(
        ORDER BY d_year, d_moy, d_dom
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    )as media_movil_a_7_dias,
    importe_total_dia
FROM
    importes_por_dia_2000
ORDER BY 
    d_year,
    d_moy,
    d_dom
;

--- Contabilizando por meses... los meses en lo que hemos doblado ingresos con respecto al anterior (ws_net_paid)



