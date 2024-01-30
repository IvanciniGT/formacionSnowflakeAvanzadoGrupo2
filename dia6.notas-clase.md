
# PROCEDIMIENTOS ALMACENADOS, TASKS, STREAMS

## PROCEDIMIENTOS ALMACENADOS

Me permiten ejecutar un script de código contra Snowflake, 
Podemos definirles datos de entyrada y salida.

Igual que en cualquier BBDD Relacional.
No tenemos PL/SQL como lenguaje de programación. Tenemos a nuestra disposición:
- **JS**
- Java
- Python
- Scala
- SF Script

### Creación de un procedimiento almacenado

```sql
CREATE OR REPLACE PROCEDURE
    nombre_procedimiento(
        <param1> TIPO,
        <param2> TIPO,
        <param3> TIPO
    )
RETURNS <TIPO>
LANGUAGE <LANGUAGE> -- JS, Java, Python, Scala, SF Script
AS
$$
    <CODIGO>
$$
;
```
### Cuerpo en JS

Cuando trabajamos en lenguaje JS tenemos que tener en cuenta:
- Tipos de datos. Podemos usar solo aquellos que existen en JS: string, double, boolean (no existe un tipo especial para enteros)
- En js, dentro de un procedimiento podemos hacer uso de la palabra snowflake. Esa palabra apunta a un objeto que tiene una serie de funciones:
  - execute({sqlText: 'QUERY', binds: [param1, param2, param3]})   
  - createStatement({sqlText: 'QUERY', binds: [param1, param2, param3]})   
        -  QUERY: 'SELECT * FROM tabla WHERE columna1 = ? AND columna2 = ?'   -- Se usa el parámetro en la posición del ?.
        -  QUERY: 'SELECT * FROM tabla WHERE columna1 = :2 AND columna2 = :1' -- Con esta notación indicamos el la posición del parámetros que queremos usar, dentro del array suministrado en binds.
     Esta función createStatement devuelve un objeto de tipo Statement, al que posteriormente le podre pedir que se ejecute: .execute() -> Recibo un conjunto iterable de datos: ResultSet, que tiene sus propias funciones:
           - next() -> boolean
           - getColumnName(<posicion>) -> string
           - getColumnValue(<posicion>) -> TIPO (Empezando en 1)
  - log('info', 'mensaje') -> Para escribir en el log de snowflake. 
      Tenemos distintos niveles de log: info, warning, error, debug, trace, fatal.
- El procedimiento debe terminar con un `return` de un valor del tipo que hemos indicado en el `RETURNS` del procedimiento.

```js
var texto = "hola";
// Esa linea hace 3 cosas:
// 1. Colocar un objeto de tipo texto "STRING" en memoria RAM, con el valor "hola"... NPI de donde.
// 2. Crear una variable llamada texto, variable que puede apuntar a datos(objetos) de cualquier tipo.
// Eso ocurre por ser JS un lenguaje de tipado dinámico.
// 3. Asigno la variable al dato.
```

```java
String texto = "hola";
// Esa linea hace 3 cosas:
// 1. Colocar un objeto de tipo texto "STRING" en memoria RAM, con el valor "hola"... NPI de donde.
// 2. Crear una variable llamada texto, variable que solo puede apuntar a datos(objetos) de tipo String.
// Esto ocurre por ser JAVA un lenguaje de tipado estático.
// 3. Asigno la variable al dato.
```

### Ejemplo de procedimiento

Tenemos una tabla de ventas.
Queremos un procedimiento que cuando se ejecutado:
- Cree una tabla de nombre "ventas_AÑO_MES", AÑO y MES anterior al actual
- Si la tabla ya existía, no la recrea,.. pero si elimina su contenido
- Esa tabla va a tener la misma estructura que la tabla ventas
- Una vez cargados los datos en esa tabla, crearemos una VIEW (a lo mejor ya existe ... y la reemplazaremos), que apunte a la tabla recién creada.

#### CODIGO:

1. Calcular el AÑO y MES ANTERIOR A HOY... SQL (Lo podríamos hacer en JS... de hecho yo os lo haré)
2. Mirar si la tabla existe:
   1. SI: La borro (el contenido)
   2. NO: La creo
3. Le copio los datos que me interesen de la tabla ventas
4. Creo una VIEW que apunte a la tabla recién creada. ventas_mes_anterior


## TASKS

1 query que ejecuto de forma programada en el tiempo:
- Intervalos de tiempo : 1hora, 1 día, 1 semana, 1 mes, 1 año
- **CRON**

## STREAMS

Los streams nos permiten MONITORIZAR una tabla en busca de cambio:
- Inserts
- Updates
- Deletes
Esa información la uso después para montar ETLs.


---

```sql

CREATE OR REPLACE PROCEDURE
    extraer_datos_mes_anterior()
RETURNS DOUBLE
LANGUAGE JAVASCRIPT
AS
$$
    // Paso 1: Calcular el mes y el año del mes anterior al actual

    var queryMesAnterior = "SELECT DATEADD(MONTH, -1, CURRENT_DATE()) as mes_anterior, MONTH(mes_anterior) as mes, YEAR(mes_anterior) as anio, 'ventas_' || anio || '_' || LPAD(mes,2,'0') as nombre_tabla" ;
    var resultadoMesAnterior = snowflake.execute( {sqlText: queryMesAnterior} ) ;
    // Recibo una tabla de datos
    resultadoMesAnterior.next() ;
    // Me ubica en la primera fila... en conrceto esta query solo devuelve una fila... pero podría devolver más... y cada .next() avanzaría de fila.
    var mesAnterior = resultadoMesAnterior.getColumnValue(2) ;
    var anioAnterior = resultadoMesAnterior.getColumnValue(3) ;
    var nombreNuevaTabla = resultadoMesAnterior.getColumnValue(4) ;





$$
;

```