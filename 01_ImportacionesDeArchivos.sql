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

USE [Com5600G11]; 
GO

-- FORMAS DE PAGO

CREATE OR ALTER PROCEDURE Pago.ImportacionPago
	AS
	BEGIN

    -- Pago en Efectivo (si aplica en la administraci�n)
    IF NOT EXISTS (SELECT 1 FROM Pago.FormaDePago WHERE descripcion = 'Efectivo en Oficina')
    BEGIN
        INSERT INTO Pago.FormaDePago (descripcion, confirmacion) 
        VALUES ('Efectivo en Oficina', 'Recibo Manual');
    END

    -- Pago Electr�nico (Mercado Pago, otros)
    IF NOT EXISTS (SELECT 1 FROM Pago.FormaDePago WHERE descripcion = 'Mercado Pago/Billetera')
    BEGIN
        INSERT INTO Pago.FormaDePago (descripcion, confirmacion) 
        VALUES ('Mercado Pago/Billetera', 'ID de Transacci�n');
    END

    PRINT N'Carga de datos de Formas de Pago finalizada.';

END
GO

-- Función para determinar el N-ésimo día hábil de un mes _________________________________________________  
-- PONERLO ANTES DE  CARGAR EXPENSA O CUALQUIER OTRA QUE LA UTILICE!!!!!

--IF OBJECT_ID('Operaciones.ObtenerDiaHabil') IS NOT NULL DROP FUNCTION Operaciones.ObtenerDiaHabil;
--GO

CREATE or alter FUNCTION Operaciones.ObtenerDiaHabil
(
    @Año INT,
    @Mes INT,
    @DiaHabilNro INT
)
RETURNS DATE
AS
BEGIN
    DECLARE @FechaActual DATE;
    DECLARE @DiasHabilesContados INT = 0;
    
    -- Inicia el conteo desde el primer día del mes
    SET @FechaActual = DATEFROMPARTS(@Año, @Mes, 1);
    
    -- Bucle para iterar y contar días hábiles
    WHILE @DiasHabilesContados < @DiaHabilNro
    BEGIN
        -- Usamos DATEPART(dw, @FechaActual) para obtener el día de la semana.
        -- Nota: La numeración del día de la semana depende de la configuración de DATEFIRST.
        -- Por defecto (usando @@DATEFIRST=7, que es Domingo=1, Lunes=2, ..., Sábado=7):
        -- Sábado es 7 y Domingo es 1.
        
        -- Si no es Sábado (7) ni Domingo (1), es un día hábil
        IF DATEPART(dw, @FechaActual) NOT IN (1, 7) -- 1=Domingo, 7=Sábado (para DATEFIRST=7)
        BEGIN
            SET @DiasHabilesContados = @DiasHabilesContados + 1;
        END
        
        -- Si ya encontramos el día hábil buscado, salimos
        IF @DiasHabilesContados = @DiaHabilNro
        BEGIN
            BREAK;
        END
        
        -- Avanzamos al día siguiente
        SET @FechaActual = DATEADD(day, 1, @FechaActual);

        -- Si la fecha actual pasa al siguiente mes, y no encontramos el día, salimos (caso extremo)
        IF MONTH(@FechaActual) != @Mes
        BEGIN
            -- Devolvemos NULL o el último día encontrado si no se pudo cumplir el requisito
            RETURN NULL; 
        END
    END
    
    RETURN @FechaActual;
END
GO

-- Funcion de Limpieza _______________________________________________________________________________
--IF OBJECT_ID('Operaciones.LimpiarNumero') IS NOT NULL DROP FUNCTION Operaciones.LimpiarNumero;
--GO

CREATE or alter FUNCTION Operaciones.LimpiarNumero (@ImporteVarchar VARCHAR(50))
RETURNS DECIMAL(18, 2)
AS
BEGIN
    DECLARE @ImporteLimpio VARCHAR(50);
    SET @ImporteLimpio = REPLACE(@ImporteVarchar, '.', '');
    SET @ImporteLimpio = REPLACE(@ImporteLimpio, ',', '.');
    IF ISNUMERIC(@ImporteLimpio) = 1
    BEGIN
        RETURN CONVERT(DECIMAL(18, 2), @ImporteLimpio);
    END
    RETURN NULL;
END;
GO

-- servicios.servicios.json _______________________________________________________________________________


CREATE OR ALTER PROCEDURE Operaciones.sp_ImportarGastosMensuales
( 
    @ruta VARCHAR(500) 
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX);
    DECLARE @AnoActual INT = YEAR(GETDATE());
    
    -- 1. Tabla temporal (MODIFICADA: AÑADE MesNumerico INT)
    IF OBJECT_ID('tempdb..#TemporalDatosServicio') IS NOT NULL DROP TABLE #TemporalDatosServicio;
    
    CREATE TABLE #TemporalDatosServicio (
        NombreConsorcio VARCHAR(100),
        Mes VARCHAR(20),
        TipoGastoBruto VARCHAR(50), 
        Importe DECIMAL(18, 2),
        MesNumerico INT
    );


-- Bloque de verificación de ruta y carga de datos
    IF CHARINDEX('''', @ruta) > 0 OR
        CHARINDEX('--', @ruta) > 0 OR
        CHARINDEX('/*', @ruta) > 0 OR 
        CHARINDEX('*/', @ruta) > 0 OR
        CHARINDEX(';', @ruta) > 0
    BEGIN
        RAISERROR('La ruta contiene caracteres no permitidos ('' , -- , /*, */ , ;).', 16, 1);
        RETURN;
    END
    ELSE
    BEGIN

        SET @sql = N'
        INSERT INTO #TemporalDatosServicio (NombreConsorcio, Mes, TipoGastoBruto, Importe, MesNumerico)
        SELECT
            J.NombreConsorcio, J.Mes, T.TipoGastoBruto, Operaciones.LimpiarNumero(T.ImporteBruto),
            CASE LTRIM(RTRIM(LOWER(J.Mes)))
                WHEN ''enero'' THEN 1 WHEN ''febrero'' THEN 2 WHEN ''marzo'' THEN 3
                WHEN ''abril'' THEN 4 WHEN ''mayo'' THEN 5 WHEN ''junio'' THEN 6
                WHEN ''julio'' THEN 7 WHEN ''agosto'' THEN 8 WHEN ''septiembre'' THEN 9
                WHEN ''octubre'' THEN 10 WHEN ''noviembre'' THEN 11 WHEN ''diciembre'' THEN 12
                ELSE MONTH(GETDATE()) END
        FROM OPENROWSET (BULK ''' + @ruta + ''', SINGLE_CLOB) AS jr
        CROSS APPLY OPENJSON(BulkColumn)
        WITH (
            NombreConsorcio VARCHAR(100) ''$."Nombre del consorcio"'', Mes  VARCHAR(20)  ''$.Mes'',
            BANCARIOS  VARCHAR(50)  ''$.BANCARIOS'', LIMPIEZA  VARCHAR(50)  ''$.LIMPIEZA'',
            ADMINISTRACION  VARCHAR(50)  ''$.ADMINISTRACION'', SEGUROS  VARCHAR(50)  ''$.SEGUROS'',
            GASTOS_GRALES  VARCHAR(50)  ''$."GASTOS GENERALES"'', AGUA  VARCHAR(50)  ''$."SERVICIOS PUBLICOS-Agua"'',
            LUZ  VARCHAR(50)  ''$."SERVICIOS PUBLICOS-Luz"''
        ) AS J
        CROSS APPLY (VALUES 
            (''BANCARIOS'', J.BANCARIOS), (''LIMPIEZA'', J.LIMPIEZA), (''ADMINISTRACION'', J.ADMINISTRACION),
            (''SEGUROS'', J.SEGUROS), (''GASTOS GENERALES'', J.GASTOS_GRALES),
            (''SERVICIOS PUBLICOS-Agua'', J.AGUA), (''SERVICIOS PUBLICOS-Luz'', J.LUZ)     
        ) AS T (TipoGastoBruto, ImporteBruto)
        WHERE Operaciones.LimpiarNumero(T.ImporteBruto) IS NOT NULL 
            AND Operaciones.LimpiarNumero(T.ImporteBruto) > 0;';
        EXEC sp_executesql @sql
    end
    
    -- Bloque de Inserción
    BEGIN TRY
        INSERT INTO Negocio.GastoOrdinario (
            idExpensa, 
            nombreEmpresaoPersona,
            fechaEmision, 
            importeTotal, 
            detalle, 
            tipoServicio,
            nroFactura
        )
        SELECT
            E.id AS idExpensa, 
            S.TipoGastoBruto AS nombreEmpresaoPersona,
        
            -- Se usa una fecha simplificada para la emisión (Día 1 del mes y Año actual)
            DATEFROMPARTS(
                @AnoActual,
                S.MesNumerico,
                1 -- Día 1
            ) AS fechaEmision, 
            S.Importe AS importeTotal,
            null AS detalle,
            S.TipoGastoBruto AS tipoServicio,

            -- Generación de nroFactura (10 dígitos: 4 + 4 + 2)
            RIGHT('0000' + CAST(E.id AS VARCHAR(4)), 4) + -- idExpensa (4 dígitos)
            RIGHT(
                CAST((@AnoActual * 100) + 
                (
                    S.MesNumerico
                ) AS VARCHAR(6))
            , 4) + -- YYMM (4 dígitos)
            RIGHT('00' + CAST(ABS(CHECKSUM(S.TipoGastoBruto)) % 100 AS VARCHAR(2)), 2) -- Hash (2 dígitos)
            AS nroFactura

        FROM #TemporalDatosServicio AS S
            CROSS APPLY (
            SELECT TOP 1 E.id, CM.nombre
            FROM Negocio.Expensa AS E
            INNER JOIN Consorcio.Consorcio AS CM ON E.consorcio_id = CM.id
            WHERE CM.nombre = S.NombreConsorcio 
            
            -- FILTRO ADAPTADO A COLUMNAS INT (Ahora usa S.MesNumerico)
            AND E.fechaPeriodoAnio = @AnoActual
            AND E.fechaPeriodoMes = S.MesNumerico 
            ) AS E (id, NombreConsorcio_FK)
        
            -- evitar duplicado por Tipo de Gasto/Expensa
            WHERE NOT EXISTS (
                SELECT 1 
                FROM Negocio.GastoOrdinario AS GO
                WHERE GO.idExpensa = E.id 
                AND GO.tipoServicio = S.TipoGastoBruto
            )
            AND E.id IS NOT NULL;  
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 2627 
        BEGIN
             RAISERROR('Error: Se encontró un número de factura duplicado al generar datos. La inserción falló parcialmente.', 16, 1);
        END
        ELSE
        BEGIN
             THROW;
        END
    END CATCH
    
    DROP TABLE #TemporalDatosServicio;

END
GO

-- IMPORTACION DE PERSONAS ___________________________________________________________________________________________________

use [Com5600G11];
GO
DROP PROCEDURE IF EXISTS sp_ImportarInquilinosPropietarios;
GO

CREATE PROCEDURE sp_ImportarInquilinosPropietarios
    @RutaArchivo VARCHAR(255)
AS
BEGIN

DECLARE @Carpeta VARCHAR(255) = 'C:\Users\Abigail\Downloads\consorcios\';
DECLARE @RutaCompleta  NVARCHAR(4000);
    SET NOCOUNT ON;

    IF CHARINDEX('..', @RutaArchivo) > 0
    OR CHARINDEX(';', @RutaArchivo) > 0
    OR CHARINDEX('--', @RutaArchivo) > 0
    OR CHARINDEX('/*', @RutaArchivo) > 0
    OR CHARINDEX('/', @RutaArchivo) > 0 
    OR CHARINDEX('\', @RutaArchivo) > 0 
    OR PATINDEX('%[;''"%]%', @RutaArchivo) > 0 
BEGIN
    RAISERROR('Nombre de archivo contiene caracteres invalidos.', 16, 1); RETURN;
END
IF RIGHT(LOWER(@RutaArchivo),4) <> '.csv'
BEGIN
    RAISERROR('Solo se permiten archivos .csv', 16, 1); RETURN;
END

    PRINT 'Iniciando importaci�n de: ' + @RutaArchivo;


---------------------------- ESTO NO VA !!!!!!!------------------------
-- Se eliminan las tablas si existen
    DROP TABLE IF EXISTS Persona.CuentaBancaria;
    DROP TABLE IF EXISTS Persona.Persona;

-- Se crean de nuevo
    CREATE TABLE Persona.Persona (
        ID INT IDENTITY(1,1) PRIMARY KEY, 
        DNI BIGINT,
        Nombre VARCHAR(30),
        Apellido VARCHAR(30),
        CBU VARCHAR(22),
        Telefono BIGINT,
        Email NVARCHAR(60),
        Tipo VARCHAR(20)
    );
    CREATE TABLE Persona.CuentaBancaria (
        CBU VARCHAR(22) PRIMARY KEY,
        Banco VARCHAR(100) NULL,
        TitularId INT NULL,
        CONSTRAINT FK_Cuenta_Titular
        FOREIGN KEY (TitularId) REFERENCES Persona.Persona(ID)
    );

-- Tabla temporal para importacion
    DROP TABLE IF EXISTS TemporalPersonas;

    CREATE TABLE TemporalPersonas (
        Nombre VARCHAR(30),
        Apellido VARCHAR(30),
        DNI BIGINT,
        Email VARCHAR(50),
        Telefono BIGINT,
        CBU VARCHAR(22),
        Tipo VARCHAR(20)
    );

    SET @RutaCompleta = @Carpeta + @RutaArchivo;

-- bulk insert
    DECLARE @sql NVARCHAR(MAX);

    PRINT 'Iniciando importaci�n de: ' + @RutaCompleta;

    SET @sql = '
        BULK INSERT TemporalPersonas
        FROM ''' + REPLACE(@RutaCompleta, '''', '''''') + '''
        WITH
        (
            FIELDTERMINATOR = '';'',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''ACP'',
            FIRSTROW = 2
        );';

    EXEC(@sql);

--borrar nulos
    DELETE FROM TemporalPersonas
        WHERE 
        (Nombre IS NULL OR Nombre = '') AND
        (Apellido IS NULL OR Apellido = '') AND
        (DNI IS NULL OR DNI = '') AND
        (Email IS NULL OR Email = '') AND
        (Telefono IS NULL OR Telefono = '') AND
        (CBU IS NULL OR CBU = '') AND
        (Tipo IS NULL OR Tipo = '');


-- Se insertan los archivos en las tablas correspondientes

    DELETE FROM TemporalPersonas
    WHERE CBU IN (
        SELECT CBU
        FROM TemporalPersonas
        GROUP BY CBU
        HAVING COUNT(*) > 1
);

    INSERT INTO Persona.Persona (DNI, Nombre, Apellido, CBU, Telefono, Email, Tipo)
    SELECT 
        DNI,
        LTRIM(RTRIM(Nombre)) AS Nombre,
        LTRIM(RTRIM(Apellido)) AS Apellido,
        LTRIM(RTRIM(CBU)) AS CBU,
        Telefono,
        REPLACE(LTRIM(RTRIM(Email)), ' ', '') AS Email,
        LTRIM(RTRIM(Tipo)) AS Tipo
    FROM TemporalPersonas;

    -- join de persona y cuenta bancaria por CBU para insertar con la FK
   INSERT INTO Persona.CuentaBancaria (CBU, TitularId)
    SELECT DISTINCT 
        LTRIM(RTRIM(it.CBU)) AS CBU,
        p.ID
    FROM TemporalPersonas it
    JOIN Persona.Persona p ON LTRIM(RTRIM(p.CBU)) = LTRIM(RTRIM(it.CBU))
    WHERE it.CBU IS NOT NULL AND it.CBU <> '';


    DROP TABLE IF EXISTS dbo.TemporalPersonas
END;
GO

EXEC sp_ImportarInquilinosPropietarios 
    @RutaArchivo = 'Inquilino-propietarios-datos.csv';


   select * from Persona.Persona
    select * from persona.CuentaBancaria
GO
 -- FIN IMPORTACION DE PERSONAS



--IMPORTAR DATOS DE CONSORCIO (del archivo de datos varios)____________________________________________________________________________
CREATE OR ALTER PROCEDURE Operaciones.sp_ImportarDatosConsorcios @rutaArch VARCHAR(1000)
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
GO

--____________________________________________________________________________________________________

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
GO

-- ___________________________________________________________________________

CREATE OR ALTER PROCEDURE Consorcio.sp_ImportarUFporConsorcio
@RutaArchivo VARCHAR(500)
AS
BEGIN
SET NOCOUNT ON;

RAISERROR('--- INICIO: Importación de Unidades Funcionales por Consorcio ---', 0, 1) WITH NOWAIT;

IF CHARINDEX('..', @RutaArchivo) > 0 OR
   CHARINDEX(';', @RutaArchivo) > 0 OR
   CHARINDEX('--', @RutaArchivo) > 0 OR
   CHARINDEX('/*', @RutaArchivo) > 0 OR
   CHARINDEX('*/', @RutaArchivo) > 0
BEGIN
    RAISERROR('Error: Ruta contiene caracteres no permitidos.', 16, 1);
    RETURN;
END;

IF RIGHT(LOWER(@RutaArchivo), 4) <> '.csv'
BEGIN
    RAISERROR('Error: Solo se permiten archivos con extensión .csv', 16, 1);
    RETURN;
END;

IF OBJECT_ID('tempdb..#TemporalUF') IS NOT NULL DROP TABLE #TemporalUF;

CREATE TABLE #TemporalUF (
    CVU_CBU CHAR(22),
    nombreConsorcio VARCHAR(100),
    nroUnidadFuncional INT,
    piso VARCHAR(10),
    departamento VARCHAR(10)
);

DECLARE @SQL NVARCHAR(MAX);
SET @SQL = '
    BULK INSERT #TemporalUF
    FROM ''' + @RutaArchivo + '''
    WITH (
        FIELDTERMINATOR = ''|'',
        ROWTERMINATOR = ''0x0a'',
        FIRSTROW = 2,
        CODEPAGE = ''65001''
    );
';
EXEC sp_executesql @SQL;

RAISERROR('Carga en tabla temporal completada. Insertando/actualizando datos...', 0, 1) WITH NOWAIT;

INSERT INTO Consorcio.Consorcio (nombre, direccion, metrosCuadradosTotal)
SELECT DISTINCT T.nombreConsorcio, 'Dirección desconocida', 0
FROM #TemporalUF AS T
WHERE NOT EXISTS (
    SELECT 1
    FROM Consorcio.Consorcio AS C
    WHERE C.nombre = T.nombreConsorcio
);

MERGE Consorcio.UnidadFuncional AS target
USING (
    SELECT 
        T.CVU_CBU,
        C.id AS consorcioId,
        CAST(T.nroUnidadFuncional AS VARCHAR(10)) AS numero,
        T.piso,
        T.departamento
    FROM #TemporalUF AS T
    INNER JOIN Consorcio.Consorcio AS C ON T.nombreConsorcio = C.nombre
) AS source
ON target.CVU_CBU = source.CVU_CBU
WHEN MATCHED THEN
    UPDATE SET 
        target.consorcioId = source.consorcioId,
        target.numero = source.numero,
        target.piso = source.piso,
        target.departamento = source.departamento
WHEN NOT MATCHED THEN
    INSERT (CVU_CBU, consorcioId, numero, piso, departamento, metrosCuadrados, porcentajeExpensas)
    VALUES (source.CVU_CBU, source.consorcioId, source.numero, source.piso, source.departamento, 50, 10); -- valores de prueba

RAISERROR('Importación completada correctamente.', 0, 1) WITH NOWAIT;

DROP TABLE #TemporalUF;

RAISERROR('--- FIN: Importación de Unidades Funcionales por Consorcio ---', 0, 1) WITH NOWAIT;


END;
GO