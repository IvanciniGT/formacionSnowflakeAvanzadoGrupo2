
Por defecto ya hemos dicho que snow flake va metiendo registros de una tabla en un montón de fichero.
¿Cuántos ficheros? NPI a priori... a posteriori lo puedo consultar... Como anécdota!

Snowflake va a intentar generar ficheros (micro-particiones) de un determinado tamaño máximo... Irá teniendo en cuenta:
- La cantidad de datos que hay en la tabla
- La naturaleza de esos datos

    TABLA USUARIOS

    FICHERO 1                                       FICHERO 2
    registro1                                       registro101
    registro2                                       registro102
    registro3                                       registro103
    ...                                             ...
    registro100
    ----- Lo cierro y abro otro fichero
    Es un poco más complejo... o puede serlo.
    Una limitación que tiene esto es que si solo hay un fichero donde voy escribiendo: CUELLAZO DE BOTELLA
    Si tengo que escribir 1000 datos... pues espera

    Si tuviera 2 ficheros donde ir escribiendo... puedo poner a 2 individuos a escribir a la vez... y tardo la mitad.
    Snowflake GILIPOLLAS NO ES...

En cada fichero tengo todas las columnas de los registros.

La aventura nos viene cuando le pido a Snowflake:
DAME TODOS LOS REGISTROS [QUE...] ---> FULLSCAN (FICHERO1+FICHERO2+FICHERO3...FICHERON)

Si tengo una tabla muy grande y por ende tiene muchas micro-particiones (50k)
Y mis queries suelen hacer uso más o menos de los mismos [QUE...]

QUE = WHERE = comunidad autónoma del usuario = "Asturias"
Si yo supiera de antemano que los datos de Asturias se han almacenado en los ficheros4 y 7...
El resto de ficheros me evito leerlos....gasto menos tiempo... menos computación... y va más rápido!

En nuestros casos habituales, no filtraremos solo por una columna... sino por varias... y en ese caso, la clave de clustering sería una concatenación de esas columnas.

---

Lo del clustering... y las microparticiones tampoco es que sea el invento del siglo. ElasticSearch lo usa desde hace años... y años.... Herramientas como rabbitMQ también.

   Comunidad autónoma:
   17 valores posibles (textos) -> HASH numérica
                        números
                        fechas

    Madrid  -> mad .... La "m" que es la primera letra de la palabra es la letra número 13 del abecedario
                        La "a" que es la segunda letra de la palabra es la letra número 1 del abecedario
                        La "d" que es la tercera letra de la palabra es la letra número 4 del abecedario
                                                                                ----> 13+1+4 = 18 << ES UNA     HUELLA DEL DATO
    Valencia -> val .... La "v" que es la primera letra de la palabra es la letra número 22 del abecedario
                         La "a" que es la segunda letra de la palabra es la letra número  1 del abecedario
                         La "l" que es la tercera letra de la palabra es la letra número 12 del abecedario
                                                                                ----> 22+1+12 = 35 << ES OTRA    HUELLA DEL DATO

Si tengo 1M de datos... y cada dato ocupa... de media .. 20Kb ---> 20Gb / 10 ... 2Gb por fichero (Estas cuentas las echa el SnowFlake)

Si tengo 10 ficheros (10 micro-particiones):
    Cuando llega un dato de Madrid...   Hago el cálculo de la huella... 18 % número de fichero = 18 % 10 = 8 < FICHERO
    Cuando llega un dato de Valencia... Hago el cálculo de la huella... 35 % número de fichero = 35 % 10 = 5 < FICHERO

---

NO SIEMPRE me interesa definir mis clustering keys.
Por defecto, si no defino Clustering keys, Snowflake usa un algoritmo trivial para guardar la información en los ficheros.
Eso me va a funcionar muy bien... si tengo tablas con pocos datos.
También me va bien si la mayor parte de las consultas las hago en base al orden de inserción de los datos.

El problema es cuando tengo muuuchos datos... o cuando mis consultas son más arbitrarias... y no van tan influenciadas (al menos exclusivamente) por el orden de inserción (que habitualmente guarda relación con la FECHA)

Y en esos escenarios me interesa montar mis propias clustering keys.... eso me puede mejorar el rendimiento de las consultas... y por ende, el coste de las mismas.... pero complica el mantenimiento de los ficheros (que se lo come la capa de procesamiento de datos)... lo cuál incrementa el coste de procesamiento en inserciones.

# Consideraciones para elegir buenas Clustering Keys

- Necesito campos que tengan una cardinalidad (entendiendo este concepto como el número de valores distintos que puede tomar un campo) que no sea ni muy baja (boolean) , ni muy alta (timestamp, DNI)
- A veces quiero usar ciertos campos... pero de manera sensata: TIMESTAMP -> Año, Mes, Día, Hora, Minuto, Segundo
  - Lo que hago es una transformación del campo a la hora de usarlo como clustering key -> TIMESTAMP -> DATE
- En los campos de tipo texto solo se tienen en cuenta los primero 5 caracteres.
  - A tener en cuenta... si tengo campos de tipo texto donde los primeros 5-200 valores son iguales... RUINA (Substring... o algo así)
    CODIGOS DE PRODUCTO: TIPOA1029374583
                         TIPOA2038475983
                         TIPOA2923789237
                         TIPOB1029374583
                         TIPOB2038475983
                         TIPOB2923789237
- "Siempre" usamos un campo de tipo fecha en las clusterizaciones.
- Si uso varios campos... el orden de los campos es importante.
  - La regla GENERAL es que primero pongo los campos de menor cardinalidad... y luego los de mayor cardinalidad.
  - Las reglas GENERALES ya sabéis que están ahí para que las pueda romper cuando me de la gana.
  - Los campos usados en clausulas WHERE se benefician mucho más de la clusterización que los campos usados en clausulas ORDER BY

# ORDER BY 

Los ORDER BY en Snowflake son una puñeta... en las BBDD relacionales cuando se pone un ORDER BY, normalmente vtengo por detrás un INDICE que tiene los datos preordenados.

Ya dijimos ayer, que los ORDER BY es lo peor que puedo pedirle a un ORDENADOR... y a cualquier BBDD.

En Snowflake, no hay índices... por tanto TODAS LAS ORDENACIONES SE EJECUTAN CUANDO SE RESUELVE UNA QUERY... siempre se ordenan los datos = MEGA CONSUMO DE RECURSOS

Los order by los voy a tener muy cuiditos en Snowflake... y si puedo evitarlos... mejor.... aunque rara vez podré evitarlos.

Y digo esto porque un ORDER BY en una BBDD no solamente se ejecuta cuando escribo en la SQL ORDER BY:
- DISTINCT: Lo primero que hace la BBDD es un ORDER BY... pero el más cruel posible.... POR TODOS LOS CAMPOS,
            para luego hacer un fullscan y mirar si un dato es igual al anterior... si es igual, lo descarta.
- UNION: Después de concatenar los datos de 2 tablas(queries), hace un DISTINCT... y ya sabemos lo que hace el DISTINCT
  - NOTA: El UNION ALL es vuestro aliado!... este es guay... no hace DISTINCT
- GROUP BY: Lo primero que hace es un ORDER BY del campo del GROUP BY... Oye... si necesito un GROUP BY, pues lo necesito
  - HAVING

Las ordenaciones se van a beneficiar ALGO de los clustering keys... aunque no tanto como las clausulas WHERE.
Si tengo datos agrupados, las ordenaciones las hago sobre conjuntos más pequeños de datos en paralelo... y eso me beneficia... luego concateno datos y punto.

> Ejemplo 1: No tengo datos agrupados por ningún campo

        TABLA:
        MP1             MP2
        1 A             6 A
        2 B             7 B
        3 C             8 C
        4 D             9 D
        5 E             10 E


Y quiero ahora los datos ordenados por LETRA
El sistema (SF) debe leer todos los datos, juntarlos en memoria (concatenarlos) y luego ordenarlos (y eso se haría en un único nodo/proceso = LA ORDENACION ES UN CUELLO DE BOTELLA)

> Ejemplo 2: Tengo los datos agrupados por letra

        MP1             MP2         MP3 
        1 A             3C          5E
        2 B             4D          10E
        6 A             8C
        7 B             9D
        (A,B)           (C,D)       (E)

Y ahora quiero los datos ordenados por LETRA
En este caso, SF puede leer los datos de cada fichero... y ordenarlos entre si... antes de concatenar... Para después hacer la concatenación:
    MP1: 1, 6, 2, 7
    MP2: 3, 8, 4, 9
    MP3: 5, 10
    (1,6,2,7) (3,8,4,9) (5,10) -> (1,2,5,6,7,10,3,4,8,9)

    En un escenario como éste: Puedo poner a 3 nodos paralelos haciendo las ordenaciones de cada partición... y luego concatenar los resultados en un nodo final.
    No ahorro pasta... el trabajo se sigue teniendo que hacer... pero ahorro un huevo de tiempo.

---

# Consideraciones adicionales para el diseño de tablas en Snowflake

- Nunca usar campos de texto para albergar fechas.
- Las restricciones de integridad referencial (FK, PK).... están en Snowflake a modo de documentación.
    Dicho de otra forma, SF pasa olimpicamente de ellas. NO VALIDA NADA !
    - CUIDADO: Esto no significa que no vaya yo a definir esas restricciones, que puedo:
      - Documentación
      - Cuando usamos herramientas de BI, estas herramientas pueden usar leer esas restricciones para ayudarnos con las queries... al comprender mejor la estructura de la BBDD (las relaciones)
- Similar a lo anterior... los campos de tipo texto: CHAR, NCHAR, VARCHAR, NVARCHAR, STRING, TEXT
  Para snowflake todo es la misma mierda. Solo mantiene esas palabras para facilitar la compatibilidad de los scripts con BBDD externas. 
  Si le pongo restricciones de longitud, SF pasa de ellas 3 pueblos.
    - OJO: Igual que con las restricciones de integridad referencial, si conozco las longitudes de los campos, se los pondré... por aquello de facilitar a TERCERAS HERRAMIENTAS que puedan usar esa información.