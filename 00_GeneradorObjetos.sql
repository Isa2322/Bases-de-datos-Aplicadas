/*
Base de datos aplicadas
Com:3641
Fecha de entrega: 7/11
Grupo 11

Mienbros:
Hidalgo, Eduardo - 41173099
Quispe, Milagros Soledad - 45064110
Puma, Florencia - 42945609
Fontanet Caniza, Camila - 44892126
Altamiranda, Isaias Taiel - 43094671
Pastori, Ximena - 42300128

Enunciado:
Base de datos lineamientos generales
Se requiere que importe toda la información antes mencionada a la base de datos:
• Genere los objetos necesarios (store procedures, funciones, etc.) para importar los
archivos antes mencionados. Tenga en cuenta que cada mes se recibirán archivos de
novedades con la misma estructura, pero datos nuevos para agregar a cada maestro.
• Considere este comportamiento al generar el código. Debe admitir la importación de
novedades periódicamente sin eliminar los datos ya cargados y sin generar
duplicados.
• Cada maestro debe importarse con un SP distinto. No se aceptarán scripts que
realicen tareas por fuera de un SP. Se proveerán archivos para importar en MIEL.
• La estructura/esquema de las tablas a generar será decisión suya. Puede que deba
realizar procesos de transformación sobre los maestros recibidos para adaptarlos a la
estructura requerida. Estas adaptaciones deberán hacerla en la DB y no en los
archivos provistos.
• Los archivos CSV/JSON no deben modificarse. En caso de que haya datos mal
cargados, incompletos, erróneos, etc., deberá contemplarlo y realizar las correcciones
en la fuente SQL. (Sería una excepción si el archivo está malformado y no es posible
interpretarlo como JSON o CSV, pero los hemos verificado cuidadosamente).
• Tener en cuenta que para la ampliación del software no existen datos; se deben
preparar los datos de prueba necesarios para cumplimentar los requisitos planteados.
• El código fuente no debe incluir referencias hardcodeadas a nombres o ubicaciones
de archivo. Esto debe permitirse ser provisto por parámetro en la invocación. En el
código de ejemplo se verá dónde el grupo decidió ubicar los archivos, pero si cambia
el entorno de ejecución debería adaptarse sin modificar el fuente (sí obviamente el
script de testing). La configuración escogida debe aparecer en comentarios del
módulo.
• El uso de SQL dinámico no está exigido en forma explícita… pero puede que
encuentre que es la única forma de resolver algunos puntos. No abuse del SQL
dinámico, deberá justificar su uso siempre.
• Respecto a los informes XML: no se espera que produzcan un archivo nuevo en el
filesystem, basta con que el resultado de la consulta sea XML.
• Se espera que apliquen en todo el trabajo las pautas consignadas en la Unidad 3
respecto a optimización de código y de tipos de datos.
*/

EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'Com5600G11'
GO
USE [master]
GO

-- Forzar desconexion de la base de datos
ALTER DATABASE Com5600G11 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
go
DROP DATABASE [Com5600G11]
GO

CREATE DATABASE Com5600G11;
go

use [Com5600G11];
go 

CREATE SCHEMA Operaciones;
go

CREATE SCHEMA Negocio;
go

CREATE SCHEMA Consorcio;
go

CREATE SCHEMA Pago;
go

/*
SELECT
    name AS NombreEsquema
FROM
    sys.schemas
WHERE
    schema_id < 16000 -- Generalmente filtra los esquemas temporales y del sistema
    AND name NOT IN ('sys', 'INFORMATION_SCHEMA', 'guest', 'db_owner')
ORDER BY
    name; 
