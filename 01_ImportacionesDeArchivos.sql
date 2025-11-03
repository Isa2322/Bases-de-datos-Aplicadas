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

CREATE OR ALTER PROCEDURE Pago.ImportacionPago
	AS
	BEGIN

	SET NOCOUNT ON;

	CREATE TABLE #PagosConsorcio (idPago int , fecha VARCHAR(10),CVU_CBU VARCHAR(22),valor varchar (12))

	BULK INSERT #PagosConsorcio
	FROM 'C:\consorcios\pagos_consorcios.csv'
	WITH(
		FIELDTERMINATOR = ',', -- Especifica el delimitador de campo (coma en un archivo CSV)
		ROWTERMINATOR = '\n', -- Especifica el terminador de fila (salto de línea en un archivo CSV)
		CODEPAGE = 'ACP',-- Especifica la página de códigos del archivo
		FIRSTROW=2
		)
		

DELETE FROM #PagosConsorcio-- Elimino las filas nulas en caso de que se generen
WHERE 
    idPago IS NULL
    AND fecha IS NULL
    AND CVU_CBU IS NULL
	AND valor IS NULL;


--Preparo los valores para cargar la tabla Pago.Pago 
UPDATE #PagosConsorcio
	SET valor = REPLACE(Valor, '$', '')


UPDATE #PagosConsorcio
	SET valor = CAST(valor AS DECIMAL(18,2))


UPDATE #PagosConsorcio
	SET fecha = CONVERT(DATE, fecha, 103)

ALTER TABLE #PagosConsorcio
	ADD idFormaPago INT

--inserto un valor provisorio para importar a la tabla Pago.FormaDePago
UPDATE P
SET P.idFormaPago = (
    SELECT TOP 1 idFormaPago
    FROM Pago.FormaDePago
)
FROM #PagosConsorcio AS P;

   INSERT INTO Pago.Pago(fecha ,importe , cbuCuentaOrigen, idFormaPago)
   select fecha, valor,CVU_CBU,idFormaPago
   from #PagosConsorcio
   where idPago IS NOT NULL
--select *from pago.pago
--SELECT* FROM #PagosConsorcio
DROP TABLE #PagosConsorcio	
END
GO

CREATE OR ALTER	PROCEDURE Pago.generadorFormasDePago 
AS
BEGIN
	IF NOT EXISTS (
	SELECT descripcion
	FROM Pago.FormaDePago a
	WHERE a.descripcion='Transferencia' OR a.descripcion='Debito automatico'
					)
					BEGIN
						INSERT INTO Pago.FormaDePago(descripcion)
							VALUES('Transferencia'),
							('Debito automatico')
					END

END

EXEC Pago.generadorFormasDePago
EXEC Pago.ImportacionPago

select * from Pago.FormaDePago