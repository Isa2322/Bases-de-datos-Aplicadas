/*Base de datos aplicadas
Com:3641
Fecha de entrega: 7/11
Grupo 11

Miembros:
Hidalgo, Eduardo - 41173099
Quispe, Milagros Soledad - 45064110
Puma, Florencia - 42945609
Fontanet Caniza, Camila - 44892126
Altamiranda, Isaias Taiel - 43094671
Pastori, Ximena - 42300128*/


-- servicios.servicios.json

use [Com5600G11];
go 

DROP TABLE IF EXISTS #PagosConsorcio
GO
CREATE TABLE #PagosConsorcio (idPago int , fecha VARCHAR(10),CVU_CBU VARCHAR(22),valor varchar (12));
GO

BULK INSERT #PagosConsorcio
FROM 'D:\edu\uni\base de datos aplicada\tp-2\consorcios\pagos_consorcios.csv'
WITH(
FIELDTERMINATOR = ',', -- Especifica el delimitador de campo (coma en un archivo CSV)
ROWTERMINATOR = '\n', -- Especifica el terminador de fila (salto de línea en un archivo CSV)
CODEPAGE = 'ACP',-- Especifica la página de códigos del archivo
FIRSTROW=2
)
GO

DELETE FROM #PagosConsorcio-- Elimino las filas nulas en caso de que se generen
WHERE 
    idPago IS NULL
    AND fecha IS NULL
    AND CVU_CBU IS NULL
	AND valor IS NULL;
GO

--Preparo los valores para cargar la tabla Pago.Pago 
UPDATE #PagosConsorcio
	SET valor = REPLACE(Valor, '$', '')
go

UPDATE #PagosConsorcio
	SET valor = CAST(valor AS DECIMAL(18,2))
go

UPDATE #PagosConsorcio
	SET fecha = CONVERT(DATE, fecha, 103)
GO

SELECT* FROM #PagosConsorcio
select *from pago.pago


   INSERT INTO Pago.Pago(fecha ,importe , cbuCuentaOrigen )
   select fecha, valor,CVU_CBU
   from #PagosConsorcio
   where idPago IS NOT NULL



