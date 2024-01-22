# Snowflake. Repaso básico

## Qué es snowflake?

Snowflake NO ES UNA BBDD... ni tampoco es algo que pueda ejecutar on premise.

Es un servicio de almacenamiento/gestión del dato en la nube.
Principalmente sirve para:
- Almacenar datos: Datalake y/o Data Warehouse (NO UNA BBDD al uso)
- Reporting, BI, etc.

Como todo servicio en cloud, pagaremos por uso:
- Almacenamiento
- Computo
- Servicios adicionales

Los de SF nos hacen mucho hincapie en la arquitectura de snowflake... 
- Es genial
- Es rápido
- Es muy flexible
- Muy escalable

En SF tenemos varias capas:
- Capa de almacenamiento
  Nos permite almacenar información, tanto datos estructurados como datos no estructurados (JSON, XML, AVRO, **PARQUET**.)
   ^   |
   |   v
- Capa de cómputo / procesamiento (infra que uso para hacer las queries... etls...)
  - Warehouse. En SF un Warehouse es una definición de una infraestructura virtual de máquinas que usamos para procesamiento de datos)
- Capa de servicios

Contrataré en cada capa lo que me interese... a razón pagaré más o menos.

---

# Almacenamiento dentro de snowflake

## Repaso de almacenamiento de datos en BBDD Relacionales

En una BBDD relacional, al final, los datos acaban en un fichero binario... guardado en disco.

> Ejemplo: Tabla usuarios

    | id | nombre | apellidos | telefono | edad | dni       |
    |----|--------|-----------|----------|------|-----------|
    | 1  | Pepe   | Pérez     | 123456   | 30   | 12345678T |
    | 2  | Juan   | García    | 654321   | 40   | 87654321T |
    | 3  | María  | López     | 987654   | 50   | 12345678T |

    Para crear esa tabla y cargarle datos, lo primero es dar de alta la tabla con su esquema:
    ```sql
    CREATE TABLE usuarios (
        id INT,
        nombre VARCHAR(50),
        apellidos VARCHAR(50),
        telefono VARCHAR(9),
        edad INT,
        dni VARCHAR(9)
    );
    ```

    Esa información se guarda en un fichero binario secuencialmente.

    - Ficheros de texto
    - Ficheros binarios
    
    Quiero guardar DNIs Españoles en una tabla... Tipo de dato?
    - OPCION 1: VARCHAR(9)... Cuánto ocupa un DNI en el fichero?
        Depende de cuanto ocupe cada carácter... y eso a su vez es en función del juego de caracteres que use (collate: UTF-8, ISO-8859-1...)
        Hoy en día UTF-8 es un estándar.
        UTF: Unicode Transformation Format
        UNICODE: es un estándar que contiene "Todos" los caracteres que usa la humanidad... Va por 150k caracteres... y creciendo.
        Hay distintas formas de codificar ese juego de caracteres... UTF-8, UTF-16, UTF-32, etc.
        - En utf-32, cada carácter se representa usando 32 bits (4 bytes)
        - En utf-16, cada carácter se representa usando 16 bits o 32 bits (2 bytes o 4 bytes)... depende del carácter.
        - En utf-8, cada carácter ocupa 1, 2 o 4 bytes, depende del carácter.
        - Qu es un DNI lo que guardamos... Número... y una letra = 9 caracteres = 9 bytes.
    - OPCION 2: Número por un lado y la letra por otro:
      - Número...
        - 1 byte: 256 valores diferentes
        - 2 bytes: 65536 valores diferentes
        - 3 bytes: 16777216 valores diferentes
        - 4 bytes: 4294967296 valores diferentes
      - Letra... 1 byte
    En total... un dni almacenado de esta forma ocupa 5 bytes... frente a los 9 bytes de la opción 1.
    Si tengo 1M de datos... 1M * 4 bytes = 4M bytes... frente a los 9M bytes de la opción 1.

    El almacenamiento en un entorno de producción es una pasta gansa!
    1º Discos duros de los caros... caros de narices
    2º Al menos vamos a tener 3 copias del dato.
        Con la opción 1: 9M * 3 = 27M bytes
        Con la opción 2: 4M * 3 = 12M bytes
    3º En producción necesito HA / Tolerancia a fallos (incluidos los humanos) = BACKUPS = x 2.5
        Con la opción 1: 27M * 2.5 = 67.5M bytes
        Con la opción 2: 12M * 2.5 = 30M bytes
    En binario guardo bytes... 00011010010110101000101010010101 -> NUMERO
    En texto guardo bytes que representan caracteres 
                                00100011 00100011 00100011 00100011 00100011 00100011 00100011 00100011 00100011 00100011 

  - OPCION 3: Guardo el número.... y la letra cuando haga falta la REGENERO.
    La letra del DNI es una huella (algoritmo tipo HASH del número). Sirve para verificar (más o menos) que el número introducido es correcto.
    Con esta opción: 4M bytes
    Con la anterior: 5M bytes
    Con la primera:  9M bytes

    La primera RUINA !... eso no lo hago... por vaguería o falta de conocimiento SI
    - Si primo el almacenamiento ---> Opción 3
    - Si primo el cómputo        ---> Opción 2


Al tener los datos almacenados en binario puedo interpretar cada dato como lo que me interese: Número, Fecha, booleano, carácter... y hago que los datos ocupen menos espacio... 
Menos espacio significa: Menos tiempo para leer, escribir, transmitir los datos.

El punto de esto era entender cómo las BBDD relacionales guardan la información:
Ficheros binarios en disco, donde la información se guarda de forma secuencial... fila a fila:


    | id | nombre | apellidos | telefono | edad | dni       |
    |----|--------|-----------|----------|------|-----------|
    | 1  | Pepe   | Pérez     | 123456   | 30   | 12345678T |
    | 2  | Juan   | García    | 654321   | 40   | 87654321T |
    | 3  | María  | López     | 987654   | 50   | 12345678T |

    BYTE 0
    v       v byte1
    0000000 00110100(P) 0000000 00110101(e) 0000000 00110000(p) 0000000 00110101(e) 0...

    FICHERO ... pero con ceros y unos
    > 1PepePérez123456781JuanGarcía6543213MaríaLópez98765412345678T

    Ese fichero está guay...
    Si quiero leer el segundo registro del HDD (del fichero)
    ... Cuánto ocupa 1 fila de datos: 1 + 50 + 50 + 9 + 4 + 9 = 123 bytes
    Para leer la segunda entrada: Pongo la aguja del HDD en el byte 122x(n-1)
    Y leo hasta el byte 122x(n-1) + 123 (incluido)

... y si quiero hacer una búsqueda que devuelva varias filas ... o una... en función de unas condiciones?

> WHERE edad > 35

Qué hace la BBDD? Un FULLSCAN... lee el fichero de principio a fin... y cuando encuentra una fila que cumple la condición... la devuelve.
ESTO ES ALTAMENTE INEFICIENTE !... y más ineficiente se hace según tengo más datos.

Alternativa que tengo en las BBDD relacionales? Crear un índice

Qué es un índice? Es una copia ordenada de algunos datos... junto con información de su ubicación:
- Indice por nombre:
    Dato que se copia (duplica)... más espacio en HDD
     v 
    Juan -> 2
    María -> 3
    Pepe -> 1 
- Indice por edad:
    30 -> 1
    40 -> 2
    50 -> 3
    ---
    Anexo: 35-> 5

Para qué quiero crear un índice? Para poder hacer búsquedas binarias... en lugar de un fullscan

1.000.000 ... en la primera partición:
  500.000 ... en la segunda partición:
    250.000 ... en la tercera partición:
      125.000 ... en la cuarta partición:
        62.500 ... en la quinta partición:
          31.250 ... en la sexta partición:
            15.625 ... en la séptima partición:
              7.812 ... en la octava partición:
                3.906 ... en la novena partición:
                  1.953 ... en la décima partición:
                    976 ... en la undécima partición:
                      488 ... en la duodécima partición:
                        244 ... en la decimotercera partición:
                          122 ... en la decimocuarta partición:
                            61 ... en la decimoquinta partición:
                              30 ... en la decimosexta partición:
                                15 ... en la decimoséptima partición:
                                  7 ... en la decimoctava partición:
                                    3 ... en la decimonovena partición:
                                      1 ... en la vigésima partición:







En 20 operaciones tengo el dato que me interesa... frente a 1M de operaciones que requiere un fullscan...
Esto si es eficiente...
De hecho... las BBDD, igual que vosotros son más eficientes que esto.
Las BBDD, igual que yo, van aprendiendo la DISTRIBUCION de los datos en la tabla.... y la primera partición la optimizan un montón.
Eso es lo que hacen en las BBDD relaciones las ESTADISTICAS !... y por eso son tan importantes.

Esto es muy eficiente!.... pero tiene una contrapartida.... o varias:
- Los índices ocupan espacio... y mucho más de lo que parece.
  DNI: 9...1M -> 9M bytes
  Ubicación: Int: 4 bytes... 1M -> 4M bytes
  TOTAL 13M bytes
  Esa es la cantidad de información que se guarda en el índice... Cuánto ocupa el índice en HDD?
  Se puede ir fácil a 40-50Mbs... y eso???? Me sobran megas o me faltan datos??? Donde están eso 27Mbs que faltan? ESPACIO EN BLANCO (huecos)... para poder meter datos nuevos según lleguen... en su sitio.

- Por eso... los índices debemos regenerarlos de poco en poco..
- En inserciones... necesito guardar no solo el dato... en el fichero de la tabla...
  Sino también la entrada en el índice... en la posición correcta. 

No obstante... llevamos usando INDICES DURANTE DECADAS ! y son muy eficientes... y muy útiles.
Y NO EXISTEN EN SNOWFLAKE !



---

Formatos de archivo que usamos mucho en el mundo BIGDATA:
- AVRO: Orientado a filas
- PARQUET: Orientado a columnas
Ambos 2 son formatos binarios.
Si quiero guardar información... el json, xml, csv.. and company son una RUINA ! son de texto plano... Van a ocupar la vida... tardo la vida en leerlos... en escribirlos...

    | id | nombre | apellidos | telefono | edad | dni       | <<< Asi se guarda en una BBDD Relacional... 
    |----|--------|-----------|----------|------|-----------|     que va orientada a filas
    | 1  | Pepe   | Pérez     | 123456   | 30   | 12345678T |
    | 2  | Juan   | García    | 654321   | 40   | 87654321T |
    | 3  | María  | López     | 987654   | 50   | 12345678T |


AVRO: 
    Documento 1: 1PepePérez123456781
    Documento 2: 2JuanGarcía6543213
    Documento 3: 3MaríaLópez98765412345678T

    Esto es útil si quiero tener la capacidad de procesar documentos de forma independiente unos de otros (Mando cosas a un KAFKA... eventos)... y alguién leerá de ese Kafka los datos para irlos procesando... 1 a 1... AVRO es mi elección.

PARQUET:
    Documento:
        METADATOS:
            columnas: id, nombre, apellidos, telefono, edad, dni
            En que posición del fichero comienza y termina cada columna
            Tipo de dato de cada columna
        id: 1,2,3
        nombre: Pepe, Juan, María
        apellidos: Pérez, García, López
        telefono: 123456, 654321, 987654
        edad: 30, 40, 50
        dni: 12345678T, 87654321T, 12345678T

FORMATO BINARIO ORIENTADO A FILAS: 
        Documento:
            1Pepe      Pérez      1234567812Federico García    6543213María    López     98765412345678T

La gracia de un formato orientado a columnas es cuando quiero usar sólo ciertas columnas de mi conjunto de datos... por ejemplo para queries... reporting... cuadros de mando.
Puedo leer del fichero solamente la columna que me interesa... y no todo el fichero... y eso es más eficiente.

Por supuesto, es un formato que no me puedo ni plantear cuando quiero trabajar con datos vivos... que están sujetos a cambios...
Hay que hacer un update... tócate las narices.

Snowflake almacena los datos en un formato binario (propietario) similar en cuanto a su estructura a parquet... ORIENTADO A COLUMNAS.

Ante lo cuál me sale una duda... Y entonces los updates? Ya os lo dije... en snowflake no hago updates.
Snowflake considera los datos inmutables. Si se quiere actualizar un dato, realmente lo que se hace es meter una versión nueva del dato... y se guardan las 2. 

Entre las funcionalidades que nos ofrece snowflake... y que se reflejan en su forma de almacenar la información (en su formato propietario) tenemos:
- time travel: Nos permite ver la BBDD ... una tabla tal y como era en un momento pasado del tiempo (90 días por defecto)
- fail safe: Nos permite recuperar la BBDD... una tabla tal y como era en un momento pasado del tiempo tras un fallo catastrófico... se joden los HDD donde estaba guardado el dato... y snowflake lo recupera de sus backups... y nos lo pone a disposición.

Entre los tipos de tablas de snowflake tenemos:
- Permanent tables: Tablas pensadas para datos críticos que requieran de persistencia... LAS MAS NORMALES PARA LOS DATALAKES
  Ofrecen: time travel, fail safe, etc. 
  Las más caras
- Transient tables: Tablas pensadas para datos que requieran persistencia... pero no sean tan criticos
  Ofrecen: time travel, no fail safe, etc. 
  - Data warehouse... puedo plantearme unas cuantas tablas de este tipo... si las construyo desde el datalake
- Temporary tables: Tablas pensadas para datos que no requieran persistencia... 
  Ofrecen: no time travel, no fail safe, etc. 
   Las uso cuando quiero generar un cuadro de mando... y sobre los resultados de una query... ejecuto otras 5 queries ---> Tablas en memoria
   Estas tablas solamente están disponibles para el usuario que las crea y durante la sesión en la que se crean.

Igual que son ficheros NO APTOS para modificaciones (UPDATES), tampoco permiten trabajar con ÍNDICES.
En un índice hago una copia ordenada de los datos... y además gurdo la ubicación!... pero si estoy en un fichero orientado a columnas... el dato (registro/fila) está repartido por todo el fichero... Además, no es posible calcular sabiendo el número de registro la posición en bytes en la que empieza un campo o acaba.... ya que tengo campos de longitud variable: en snowflake no hay VARCHAR(55) ---> String

Esto es un problemón en el rendimiento de las queries... 
Y si no puedo usar/crear índices? qué me queda? EL PUÑETERO FULLSCAN !, que es lo que usa snowflake para buscar datos!

En serio? Pero esto no era super-eficiente? ... eh....

Qué podemos hacer en snowflake?

Hay algo que no os he contado aún... O más o menos si... pero en otro sitio... os dije TOMAR NOTA DE ESTO!
Una tabla de snowflake realmente se guarda en MOGOLLON DE FICHEROS... y no en 1 solo fichero.
Ese mogollón de ficheros... lo que contienen son TROZOS de la tabla... y no la tabla entera.
Puedo procesar cada trozo del fichero de forma paralela a otros trozos del fichero... y luego consolidar los resultados.
En este sentido es que SnowFlake es muy eficiente... Siempre y cuando ponga máquinas de sobra en paralelo para procesar todos esos trocitos de fichero en paralelo.
El problema es si los tengo que procesar SECUENCIALMENTE porque no tengo máquinas suficientes .... ahí cae el rendimiento.

Esos trozos de tabla... ficheros... en snowflake reciben el nombre de MICRO-PARTICIONES.
Snowflake gestiona el solito esas micro-particiones... y las va creando y borrando según va necesitando... o le va interesando.
El punto es que tenemos una oportunidad e influir en cómo snowflake divide los datos en esos trozos... y eso es lo que se llama CLUSTERING.

Qué me va a interesar? guardar en el mismo fichero (juntos) datos que se vayan a procesar/analizar, recuperar juntos.
Imaginad:
    Tengo datos de ventas... 10M de datos de los últimos 10 años.
    Puedo guardar en 10 ficheros las ventas... en cada fichero las de un año.
    Cuando hago una query... y pido los datos del 2018 no necesito leer todos los ficheros... solamente 1.
    Esto de nuevo NO ES NADA NUEVO... no han inventado nada: PARTICIONAR UNA TABLA!
    Snowflake hace una evolución de esto... y lo llama CLUSTERING.
    El gestiona esas particiones... se encarga de todo el proceso en automático... nbosotros simplemente influenciamos ese particionado:

```sql-snowflake
CREATE TABLE ventas (
    id INT,
    fecha DATE,
    importe FLOAT,
    producto STRING,
    cliente STRING
)

ALTER TABLE ventas CLUSTER BY (fecha);
                                # Clustering key
```
No tengo npi de cuántas particiones (microparticiones) se van a generar... esto no es oracle.. que le digo, para cada valor de la columna.... o para los valores que cumplen tal condición usa la partición N.
En las BBDD relaciones este concepto existe... Con particiones FINITAS precreadas, y condiciones que indican a que partición debe ir cada dato.
En Snowflake las microparticiones suelen tener un tamaño entre 15-50Mbs... y se crean y borran según se necesiten.
VA a usar la información de clustering... para tratar de garantizar que los datos con unos campos (EN PLURAL) iguales... o similares... se guarden en la misma micropartición... y por tanto en el mismo fichero.

Si tengo 500 archivos, significa que tengo la oportunidad ed tener 500 trabajadores leyendo en paralelo esos datos... para responder bien rapidito. Esto es una exageración.

Lo normal es que tenga 500 particiones... y 5 procesadores.
Si consigo agrupar datos de manera que una query solo necesite leer datos almacenados en 25 micro-particiones... y tengo 5 procesadores... cada procesador leerá 5 micro-particiones... y no 25... y eso es más eficiente.

Si no me quiero complicar, no me complico... pero... prepara bolsillo.

Cómo podremos mejorar el rendimiento de nuestras queries:
- Almacenando los datos en una mejor estructura, más orientada al objetivo final de los datos.
- Agrupando los datos en microparticiones de forma que las queries que hagamos sean más eficientes. 
- Vistas materializadas: Son vistas que se guardan en disco... y se actualizan cada cierto tiempo... para que las queries que se ejecuten sobre ellas sean más eficientes.

- JAVA. Es un lenguaje que hace un destrozo a la RAM impresionante. 
  Eso es bueno o malo? FEATURE
  Característica de diseño de JAVA: Vamos a montar un lenguaje que haga un destrozo de la RAM!
  Coño, ya había un lenguaje practicamente igual a JAVA en sintaxis que hacia un uso que te cagas de la RAM: C++

  Pero... y entonces...
  FACIL: Una app montada en C++ haciendo uso de la RAM guay... me cuenta 500 horas de desarrollador + 50 horas de afinar la app en buscar de memory leaks.
  La misma app montada en JAVA: 500 horas de desarrollador + 0 horas de afinar la app en buscar de memory leaks.
  Ponle a la máquina 200Gbs más de RAM... y listo!... cúanto cuesta esto? menos que las horas de desarrollador... PA'LANTE
  
En Snowflake podemos usar una analogía con lo anterior...
- Pasta de admin de BBDD creando indices, analizando la forma de ejecutar las queries, etc. manteniendo esos índices... regerando estadísticas, etc.
- Desarrolladores que sepan un huevo creando particiones, vistas materializadas, etc. para mejorar el rendimiento de las queries.
O Snowflake... que pasa de todo eso... pero mete más máquinas!

---

# Terminología: Gestión del dato:

BBDD:                       Las usamos en entornos de producción para almacenar información 
                            viva (sujeta a cambios)
                            - BBDD Relacionales (Oracle, DB2, SQL Server, MySQL, MariaDB, postgresql, etc.)
                            - BBDD No Relacionales (MongoDB, Cassandra, Neo4J...)
                            Hacemos operaciones CRUD: Create, Read, Update, Delete 
ETL                         Script con varias partes: 
                            -   Extract:                Extraer datos de una fuente
                            -   Transform:              Transformarlos para que se ajusten a un modelo de datos
                            -   Load                    Cargar los datos en otro lao'
                            Hay variantes:
                                - ETL
                                - TEL
                                - TELT
                                - ETLT
                            Puedo hacer que se ejecuten:
                            - programados en el tiempo
                            - en tiempo real
Datalake:                   Repositorio de datos / Almacen de datos MUERTOS !
                                - Tengo que guardarlos por motivos legales
                                - Análisis de esos datos
                            NOTA:
                            Los de BI en general nos hemos echado muy mala fama... con eso de tirar queries monstruosas y con poco o nada de cuidado en su construcción.
                            Como esto pasa... en otras empresas... Hay veces que datos vivos también los llevo a un datalake para hacer análisis y no tocar la BBDD de producción.

                            Los datos de un datalake son datos en bruto, como me vienen de la fuente.... poca o nada transformación en ellos.
Data Warehouse              Repositorio de datos / Almacen de datos MUERTOS !
                            - Análisis de datos (reportes, cuadro de mando, etc.)
                            Los datos en un datawarehouse se estructuran de una forma diferente a cómo tengo los datos en el data lake.
                                                             Se cambia la estructura
                                                                   v 
                                BBDD ---> ETL ---> Data Lake ---> ETL ---> Data Warehouse

                            El dato se guarda de una forma diferente para facilitar y mejorar el rendimiento de los análisis.

                                BBDD -> Clientes -< Pedidos (normalizado)
                                Data warehouse -> PedidosDeClientes (desnormalizada)
Business Intelligence       Hacer un análisis superficial del dato.
                            - Cuadros de mando
                            - Reportes
                            - Gráficos
                            - Tablas
                            - etc.
Data Mining                 Hacemos un análisis en profundidad del dato... 
                            normalmente no sabemos ni lo que buscamos
Machine Learning            Una vez identificadas relaciones entre datos... 
                            montamos programas que ayuden a predecicir el futuro
                            - Predicción de ventas
                            - Predicción de riesgos
                            - Predicción de fraudes
                            - Predicción de tendencias
                            - etc.
BIGDATA:                    
    conjuntos de técnicas a las que recurro cuando las técnicas que he venido usando hasta ahora (haciendo trabajos con datos*1) ya no me son suficientes.
    *1 De la naturaleza que sean:
    - Almacenar datos
    - Analizar datos
    - Transmitir datos

    > Emjeplo: Imaginad que tengo un pincho USB de 16Gbs .. a estrenar... limpio de polvo y paja... No tengo na' dentro:
    - Y quiero grabar una peli.... perdón un archivo de 5 Gbs que he descargado de internet en el pincho... 
      puedo?  Depende del sistema de archivos: FAT16 o FAT 32... jodido voy... no puedo.
      Me puedo ir a ntfs... y ya puedo.... a no ser que quiera guardar un archivos de 12Pbs... que el ntfs se hace caquita! igual que el fat-32
    - Voy a hacer una tablita con la lista de la compra: Producto + cantidad
      - 200 productos.. en que programa lo hago? Excel
      - 50.000 productos? El EXCEL empieza a sudar... y yo también -> MySQL
      - 10M de productos? MySQL empieza a sudar... y yo también -> SQL Server
      - 200M de productos en SQL Server? SQL Server empieza a sudar... y yo también -> Oracle
      - 3000M de datos? El oracle se hace popo... y yo detrás... y ahora qué?
    - ClashRoyale... 2vs2
      En 2 seg hago 2 movimientos... -> 6 mensajes que se mandan a los otros 3 participantes
      Somos 4 jugando... 24 mensajes por segundo
      Si en un momento del tiempo hay 50k partidas... 1.2M mensajes por segundo
      NO HAY MAQUINA QUE SOPORTE ESA CARGA DE TRABAJO ! 

en este caso cambio de estrategia... me voy a una infraestructura BIGDATA... donde en lugar de usar una megamaquina... uso un cluster de máquinas de mierda (commmodity hardware) ... y uso su capacidad de cómoputo/almacenamiento conjunta para resolver mi problema. Cuando  quiero hacer esto, lo primero que necesito es un programa que me permita hacer uso de esa capacidad conjunta de recursos: Memoria RAM, CPU, HDD, etc.
Montamos un programa llamado HADOOP, que es el equivalente a un SO en el mundo Bigdata. Incluso, hadoop me ofrece su propio sistema de archivos.. un sistema de archivos distribuido... donde un archivo se guarda "a trozos" en distintas máquinas... eso me da una capacidad ed lectura / escritura aberrante (HDFS).

Eso si... como cuasi SO... no vale pa na'... necesito programas que me permitan hacer uso de esa capacidad de cómputo/almacenamiento distribuida... 
- Transmitir información: KAFKA
- Almacenamiento:
 - Ficheros: Hadoop hdfs
 - BBDD: HBase
 - BBDD NoSQL: Cassandra, MongoDB, Neo4J, etc.
 - Transformar datos: Spark, Storm  

