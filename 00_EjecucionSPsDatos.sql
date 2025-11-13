/*
Base de datos aplicadas
Com:3641
Fecha de entrega: 7/11
Grupo 11

Miembros:
Hidalgo, Eduardo - 41173099
Quispe, Milagros Soledad - 45064110
Puma, Florencia - 42945609
Fontanet Caniza, Camila - 44892126
Altamiranda, Isaias Taiel - 43094671
Pastori, Ximena - 42300128
*/

/*
	En este script se ejecutan todos los stored procedures que importan datos directamente de los archivos provistos
	y los que rellenan las tablas con los datos faltantes, estan en orden para no generar problemas en la insercion de datos
	Reemplazar la ruta del archivo por la correspondiente segun quien este ejecutando.
*/

USE [Com5600G11]; 
GO

EXEC Operaciones.sp_CargaTiposRol
SELECT * FROM Consorcio.TipoRol

EXEC Operaciones.sp_CrearYcargar_FormasDePago
SELECT * FROM Pago.FormaDePago

EXEC Operaciones.sp_ImportacionPago @rutaArchivo  = 'C:\Users\Milagros quispe\Documents\GitHub\Bases-de-datos-Aplicadas\consorcios\pagos_consorcios.csv';
SELECT * FROM Pago.Pago;

EXEC Operaciones.sp_ImportarDatosConsorcios @rutaArch= 'C:\Users\Milagros quispe\Documents\GitHub\Bases-de-datos-Aplicadas\consorcios\datos varios - Consorcios.csv';
SELECT * FROM Consorcio.Consorcio

EXEC Operaciones.SP_generadorCuentaBancaria;
SELECT * FROM Consorcio.CuentaBancaria

EXEC Operaciones.sp_ImportarGastosMensuales @ruta = 'C:\Users\Milagros quispe\Documents\GitHub\Bases-de-datos-Aplicadas\consorcios\Servicios.Servicios.json';
SELECT * FROM Negocio.GastoOrdinario;

EXEC Operaciones.sp_ImportarDatosProveedores @rutaArch = 'C:\Users\Milagros quispe\Documents\GitHub\Bases-de-datos-Aplicadas\consorcios\datos varios - Proveedores.csv';
SELECT * FROM Negocio.GastoOrdinario;

EXEC Operaciones.sp_ImportarInquilinosPropietarios @RutaArchivo = 'C:\Users\Milagros quispe\Documents\GitHub\Bases-de-datos-Aplicadas\consorcios\Inquilino-propietarios-datos.csv';
SELECT * FROM Consorcio.Persona;

EXEC Operaciones.sp_CargarUF_Inquilinos @RutaArchivo = 'C:\Users\Milagros quispe\Documents\GitHub\Bases-de-datos-Aplicadas\consorcios\Inquilino-propietarios-UF.csv';
SELECT * FROM Consorcio.Persona

EXEC Operaciones.sp_ImportarUFporConsorcio @RutaArchivo = 'C:\Users\Milagros quispe\Documents\GitHub\Bases-de-datos-Aplicadas\consorcios\UF por consorcio.txt';
SELECT * FROM Consorcio.UnidadFuncional

EXEC Operaciones.sp_CargarGastosExtraordinarios
SELECT * FROM Negocio.GastoExtraordinario

--Los parametros de esta ejecucion deben cambiar segun lo q se quiera generar
EXEC Negocio.SP_GenerarLoteDeExpensas
SELECT * FROM Negocio.DetalleExpensa

EXEC Operaciones.sp_RellenarCocheras
SELECT * FROM Consorcio.Cochera

EXEC Operaciones.sp_RellenarBauleras
SELECT * FROM Consorcio.Baulera


--Reporte 1
EXEC Reporte.sp_Reporte1_FlujoSemanal 1,2025,5

--Reporte 2
--El ultimo valor filtra los departamentos que no tienen pagos ese ano
EXEC Reporte.sp_Reporte2_RecaudacionMesDepto 1,2025,0

--Reporte 3
--Aunque no lo use, pongan el dia a las fechas si la cambian o les tira error
EXEC Reporte.sp_Reporte3_RecaudacionPorProcedencia 1,'2025-05-01','2025-06-30'

--Reporte 4
--Puede filtrar por consorcio, ano y cambiar el top
EXEC Reporte.SP_ObtenerTopNMesesGastosIngresos 

--Reporte 5
--Puede tener una fecha limite para limitar el periodo de los valores
EXEC Reporte.sp_Reporte5_MayoresMorosos_XML 1,'2025-05-01'

--Reporte 6
--Puede filtrar por Consocio, Unidad Funcional y periodo(usando 2 fechas)
EXEC Reporte.sp_Reporte6_PagosOrdinarios_XML