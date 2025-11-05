CREATE OR ALTER PROCEDURE sp_ImportarDatosConsorcios @rutaArch VARCHAR(1000)
AS
BEGIN
	--armo una temporal para guardar los datos
	CREATE TABLE #TempConsorciosBulk 
	( 
		consorcioCSV VARCHAR(100),
        nombreCSV VARCHAR(100),
        direccionCSV VARCHAR(200),
		cantUnidadesCSV INT,
        superficieTotalCSV DECIMAL(10, 2)
    );

	--sql dinamico para encontrar la ruta
	DECLARE @sqlBulk VARCHAR(1000)

	SET @sqlBulk = 
			'
            BULK INSERT #TempConsorciosBulk
            FROM ''' + @rutaArch + '''
            WITH (
                FIELDTERMINATOR = '';'',
                ROWTERMINATOR = ''\n'',
                FIRSTROW = 2,
                CODEPAGE = ''65001''   
            )
			'
    EXEC(@sqlBulk)
	--Dsps de esto ya tendria todo insertado en la tabla temporal
	--Ahora tengo q pasar las cosas a la tabla real
	--Esta actualizacion se hace comparando con el nombre, si no encuentra una coincidencia del nombre en la tabla considera q tenes un consorcio nuevo y lo inserta
	UPDATE Consorcio
    SET direccion = Fuente.direccionCSV, metrosCuadradosTotal = Fuente.superficieTotalCSV
    FROM Consorcio AS Final INNER JOIN #TempConsorciosBulk AS Fuente
    ON Final.nombre = Fuente.nombreCSV
    INSERT INTO Consorcio 
	(
         nombre,
         direccion,
         metrosCuadradosTotal
    )
    SELECT Fuente.nombreCSV, Fuente.direccionCSV, Fuente.superficieTotalCSV
    FROM #TempConsorciosBulk AS Fuente
	WHERE NOT EXISTS 
			(
                SELECT 1
                FROM Consorcio AS Final
                WHERE Final.nombre = Fuente.nombreCSV AND Final.direccion = Fuente.direccionCSV
            ) --basicamente aca se fija q para actualizar ya exista un consorcio con el mismo nombre y direccion y sino inserta uno nuevo

END