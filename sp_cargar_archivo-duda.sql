CREATE OR ALTER PROCEDURE CargaInquilinoPropietariosUF
    @RutaArchivo VARCHAR(255)
AS
BEGIN
    CREATE TABLE #CargaDatosTemp (
        CVU_CBUPersona CHAR(22),
        consorcio VARCHAR(50), 
        numero VARCHAR(10),
        piso VARCHAR(10),
        departamento VARCHAR(10)   
    );


    IF CHARINDEX('''', @RutaArchivo) > 0 OR
        CHARINDEX('--', @RutaArchivo) > 0 OR
        CHARINDEX('/*', @RutaArchivo) > 0 OR 
        CHARINDEX('*/', @RutaArchivo) > 0 OR
        CHARINDEX(';', @RutaArchivo) > 0
    BEGIN
        RAISERROR('La ruta contiene caracteres no permitidos ('' , -- , /*, */ , ;).', 16, 1);
        RETURN;
    END
    ELSE
    BEGIN
        DECLARE @SQL NVARCHAR(MAX);
    
        SET @SQL = N'
            BULK INSERT #CargaDatosTemp
            FROM ''' + @RutaArchivo + '''
            WITH (
                FIELDTERMINATOR = ''|'',
                ROWTERMINATOR = ''\n'',
                FIRSTROW = 2
            );';

        EXEC sp_executesql @SQL;
    END

    CREATE TABLE #ConsorcioTemp (
        CVU_CBUPersona CHAR(22),
        ID_Consorcio INT,
        numero VARCHAR(10),
        piso VARCHAR(10),
        departamento VARCHAR(10)
    );

    INSERT INTO #ConsorcioTemp (CVU_CBUPersona, ID_Consorcio, numero, piso, departamento)
    SELECT c.CVU_CBUPersona,
        c.id,
        cd.numero,
        cd.piso,
        cd.departamento
    FROM #CargaDatosTemp AS cd
    JOIN Consorcio.Consorcio AS c ON cd.consorcio = c.nombre;

    MERGE INTO Consorcio.UnidadFuncional AS target
    USING #ConsorcioTemp AS source
    ON target.CVU_CBUPersona = source.CVU_CBUPersona
    WHEN MATCHED AND(
        target.numero <> source.numero AND
        target.piso <> source.piso AND
        target.departamento <> source.departamento AND
        target.consorcioId <> source.ID_Consorcio
    ) THEN
    UPDATE SET
        target.numero = source.numero,
        target.piso = source.piso,
        target.departamento = source.departamento,
        target.consorcioId = source.ID_Consorcio
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (CVU_CBUPersona, numero, piso, departamento, consorcioId)
        VALUES (source.CVU_CBUPersona,  source.numero, source.piso, source.departamento, source.ID_Consorcio);
END