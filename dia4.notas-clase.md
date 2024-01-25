
# Modelo/Esquema de BBDD

Asegurarme que tengo un buen modelo de datos es fundamental para que mi BBDD sea eficiente.
Y este tema es COMPLICAO !
Además, un modelo / esquema de BBDD lo puedo optimizar para actualizaciones o para consultas... pero no para los dos a la vez!

Nuestro negocio es el BI... mi objetivo es un modelo de BBDD que sea eficiente para las consultas.

El modelo estrella que usamos en el mundo de BI, el modelo de estrella.

## Modelo de estrella

Es un modelo de datos optimizado para consultas... en el que:
- tenemos unas tablas de HECHOS
- y unas tablas de DIMENSIONES

Las tablas de hechos guardan una relación N-1 con las tablas de dimensiones.
Y las tablas de dimensiones no guardan relación entre si.

### Tablas de hechos?

Contienen los datos que quiero analizar.
    ESTOS SON LOS QUE SACO, AGREGO

### Tablas de dimensiones?

Contienen los factores asociados / de los que hay dependencia con los datos de las tablas de hechos.
    ESTOS SON POR LOS QUE AGRUPO, FILTRO...

Los modelos en estrella no son aptos para entornos de producción. Son modelos de datos para entornos de BI.
En los entornos de producción buscamos modelos que sean eficientes para las actualizaciones discretas de datos.

### Ejemplo de modelo apto para un entorno de producción: WEB DE VENTAS DE PRODUCTOS DE MANOLO !

- Clientes
  - id
  - nombre
  - apellidos
  - sexo
  - hijos
- Direcciones
  - id
  - cliente_id
  - calle
  - numero
  - ciudad
  - provincia
  - cp
  - pais
- Productos
  - id
  - nombre
  - precio
  - categoria_id
- Categorías de productos
  - id
  - nombre
- Pedidos
  - id
  - fecha
  - cliente_id
  - direccion_id
  - producto_id
  - cantidad
  - precio

    Tenemos las siguientes relaciones:

        Direcciones >- Clientes -< Pedidos >- Productos >- Categorías de productos
    
    Es un modelo muy optimizado para actualizaciones.
    - Si quiero añadir/ editar 1 dirección: 1 INSERT / 1 UPDATE que afecta a 1 registro
    - Si quiero un pedido nuevo de un producto: 1 INSERT que afecta a 1 registro
    - Nuevo cliente: 1 INSERT que afecta a 1 registro
    - Actualizo el nombre del cliente: 1 UPDATE que afecta a 1 registro

Pero este modelo sería muy ineficaz para realizar consultas de BI.... comparado con otras alternativas... como puede ser un modelo en estrella.

Lo normal es que monte unas ETL que lleven los datos de mi BBDD de producción a mi DataLAKE.

En ese proceso NO CAMBIO NI UNA COMA DE LA ESTRUCTURA DE DATOS.
No quiero cambiar nada... porque si no se me complica el tema... y quiero unos procesos muy sencillitos para evacuar a TODA OSTIA datos de producción.... puede ser que haga un poco de manipulación MINIMO: Estado del pedido: Iniciado... en tramite... cerrado.

Y ahora... a algún cobartilla se le ocurre la brillante idea de querer analizar los datos de ventas de la web de Manolo.

Y monto un DATAWAREHOUSE... donde voy a llevar mis datos.... mediante otras ETL.... dejándolos "finitos", "niquelaos"... estupendísisisimos para poder hacer mogollón de consultas MUY EFICIENTES SOBRE ELLOS.

# A TRANSFORMAR !!!!!

Lo primero... necesito identificar los HECHOS y las DIMENSIONES:

## Tablas de hechos:

    PEDIDOS
    - id
    - fecha
    - cliente_id
    - direccion_id
    - producto_id
    - categoria_id
    - sexo_id
    - pais_id
    - cantidad
    - precio

## Tablas de dimensiones

    FECHA
    - id
    - fecha
    - dia del mes
    - dia de la semana
    - mes
    - año
    - trimestre
    - semestre
    - si cae en fin de semana
    - festivo
    - vispera de festivo
    Clientes (Esta tabla es una potencial candidata a ser ELIMINADA)
        Es más... no eliminarla me daría un dolor de cabeza con la LGPD...
        Tengo que notificar que tengo OTRA BBDD más con datos sensibles... Apuntar y notificar a las autoridades competentes que tengo otras 50 personas que tienen acceso a esos datos...
        Si hay una fuga... a ver quien cojones ha sido...
    - id
    - sexo
    SEXOS (Si lo tuviera en la BBDD dentro de clientes: SELECT DISTINCT etiqueta FROM clientes) ... O no....
                            - O lo calzo a mano en la FILTRO (desplegable)
                            - O la BBDD Lo va a tener en cache
    - id sexo
    - etiqueta
    HIJOS (discretizada) (CUALITATIVA) (1.2.3....45). 0, 1, 2, 3, muchos
    - id_numero de hijos
    - etiqueta
    DIRECCIONES
    - id
    - calle
    - numero
    - ciudad
    - provincia *
    - cp *
   PAISES
    - id
    - nombre
   PRODUCTOS
    - id
    - nombre
    - precio
    (- categoria_id) TENGO YA UN MODELO EN ESTRELLA? NO ---> SI LA DEJO, TENGO UN MODELO COPO DE Nieve
  - CATEGORIAS de productos
    - id
    - nombre

SELECT * FROM PEDIDOS para los "machos ibéricos"
Si tengo en medio la tabla clientes: PEDIDOS x CLIENTES
Si tengo una tabla propia: PEDIDOS (sexo_id)
SELECT * FROM PEDIDOS para los "hembras peninsulares"

Si dibujamos ese modelo y sus relaciones:

                        DIRECCIONES
                            |
                            ^
            PRODUCTOS -< PEDIDOS >- FECHAS
                            v
                            |
                           SEXO

                          PAIS
                            |
                            ^
            CATEGORIAS -< PEDIDOS >- HIJOS

## Nos vamos a Snowflake

Y vamos a pensar qué tipo de clustering keys vamos a usar en cada tabla.

Sease la tabla SEXO: Ninguno... porque solo tiene 2 valores posibles: Hombre y Mujer.
Sease la tabla CP: El ID Sería el clustering key
    En general en todas las tablas de dimensiones vamos a usar el ID.
    Cuando creamos un clustering key:
        ALTER TABLE CP CLUSTER BY (ID); -- nosotros definimos esto...
        -- Pero luego en la pantallita del Snowflake, lo que vemos es: Linear( ID )
    Y el punto es que los datos son únicos.... pero queremos que snowflake guarde... los datos iguales en la misma micropartición... pero los datos correlativos, que también me los guarde juntos.

    Si tengo una tabla:
        1 1 2 3 4 2 1 3 4 4

        Y se van a partir en 2 microparticiones:
            OPCION 1:           OPCION 2:
            MP1: 1 1 1 2 2      MP1: 1 1 1 3 3
            MP2: 3 3 4 4 4      MP2: 2 2 3 4 4
        
        Cuál me interesa más? La que tiene los datos colocados por orden... Esto, a la hora de buscar en qué partición tengo un dato, me permite hacer búsquedas binarias... y eso es MUY EFICIENTE.... y es lo que hace el snowflake.
        
                MP1 ... los ids del 1 al 10000
                MP2 ... los ids del 10001 al 20000
                MP3 ... los ids del 20001 al 30000
                MP4 ... los ids del 30001 al 40000
                MP5 ... los ids del 40001 al 50000

    Pregunta... tengo 2 campos en esta tabla de CP:     
        - id
        - código postal
    Por qué campo voy a entrar a esta tabla? por el ID.
    La respuesta es: (en la mayor parte de los escenarios)
        Que yo no voy a entrar a esa tabla por ninguno de los 2.Yo lo que haré será una búsqueda en PEDIDOS... y los pediré agrupados por CP... Y snowflake para hacer esa agrupación entra por ID
    
    Si quiero hacer una búsqueda de todos los pedidos del CP: 28888 ... me penaliza este criterio... pero el tema es que el 99% de las búsquedas no van a ser de ese tipo.
    Si quiero hacer muchas BUSQUEDAS por CP discreto... qué me interesa? Meter el CP en la tabla pedidos!

    En la realidad ... posiblemente esa tabla ni la particione con un clusterring key customizado.

    Para la búsqueda: 
    SELECT CP_LABEL, count(*) 
    FROM PEDIDOS, CP 
    WHERE 
        CP.id = PEDIDOS.cp_id
    GROUP BY CP_LABEL

    Lo normal es que si hay 100000 CP... los tenga todos en 1 o 2 microparticiones... y lea las 2 en memoria

    LA REGLA GENERAL ES: TODAS LAS TABLAS DE DIMENSIONES : Clustering key = ID...
    Y si tengo en cuenta que cargo los datos ordenados por ID... entonces... no le pongo ni clustering key...
    QUE ES LO QUE ME VIENEN A DECIR LOS DE SNOWFLAKE... 

# Vamos a la tabla de hechos
    PEDIDOS
        Cuál va a ser el clustering key que vamos a elegir? FECHA(ID)

PEDIDOS  con datos de 10 años
PRODUCTOS (DIM) con 1.000.000 productos
Si busco pedidos de lel último año, los productos que saldrán serán con mucha probbiliodad muy distintos de los productos de la misma query hace 10 años...Los productos cambian con el tiempo... y las tendencias también.

En un escenario como este, si que me interesa tener los productos por ID...