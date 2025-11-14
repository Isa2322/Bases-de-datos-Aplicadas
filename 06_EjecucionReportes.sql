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
	En este script se ejecutan todos los reportes y los reportes ... devuelven un xml
*/

USE [Com5600G11]; 
GO



 --Reporte 1
EXEC Reporte.sp_Reporte1_FlujoSemanal Azcuenaga,2025,5

--Reporte 2
--El ultimo valor filtra los departamentos que no tienen pagos ese ano
EXEC Reporte.sp_Reporte2_RecaudacionMesDepto 1,2025,0

--Reporte 3
--Aunque no lo use, pongan el dia a las fechas si la cambian o les tira error
EXEC Reporte.sp_Reporte3_RecaudacionPorProcedencia 1,'2025-05-01','2025-06-30'

--Reporte 4
--Puede filtrar por consorcio, ano y cambiar el top
EXEC Reporte.sp_Reporte4_ObtenerTopNMesesGastosIngresos 

--Reporte 5
--Puede tener una fecha limite para limitar el periodo de los valores
EXEC Reporte.sp_Reporte5_MayoresMorosos_XML 1,'2025-05-01'

--Reporte 6
--Puede filtrar por Consocio, Unidad Funcional y periodo(usando 2 fechas)
EXEC Reporte.sp_Reporte6_PagosOrdinarios_XML