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

-- servicios.servicios.json

-- Funci�n de Limpieza: Crea un nuevo lote con GO
IF OBJECT_ID('Negocio.LimpiarNumero') IS NOT NULL DROP FUNCTION Negocio.LimpiarNumero;
GO

CREATE FUNCTION Negocio.LimpiarNumero (@ImporteVarchar VARCHAR(50))
RETURNS DECIMAL(18, 2)
AS
BEGIN
    DECLARE @ImporteLimpio VARCHAR(50);

    -- 1. Eliminar puntos
    SET @ImporteLimpio = REPLACE(@ImporteVarchar, '.', '');

    -- 2. Reemplazar la coma 
    SET @ImporteLimpio = REPLACE(@ImporteLimpio, ',', '.');
    
    -- Manejo de valores vac�os o NULL antes de la conversi�n
    IF ISNUMERIC(@ImporteLimpio) = 1
    BEGIN
        RETURN CONVERT(DECIMAL(18, 2), @ImporteLimpio);
    END
    
    RETURN NULL;
END;
GO

CREATE or ALTER PROCEDURE Negocio.sp_ImportarGastosMensuales
--( @ruta VARCHAR(500) )
AS
BEGIN
    SET NOCOUNT ON;

    -- tabla temporal para datos del json
    IF OBJECT_ID('tempdb..#TemporalDatosServicio') IS NOT NULL
    BEGIN
        DROP TABLE #TemporalDatosServicio;
    END

    CREATE TABLE #TemporalDatosServicio (
        NombreConsorcio VARCHAR(100),
        Mes VARCHAR(20),
        TipoGastoBruto VARCHAR(50), 
        Importe DECIMAL(18, 2)
    );
    
    -- 1- importar el archivo json
    INSERT INTO #TemporalDatosServicio (NombreConsorcio, Mes, TipoGastoBruto, Importe)
    SELECT
        J.NombreConsorcio,
        J.Mes,
        T.TipoGastoBruto,
        Negocio.LimpiarNumero(T.ImporteBruto) 
        FROM OPENROWSET (BULK 'C:\Users\Milagros quispe\Documents\GitHub\Bases-de-datos-Aplicadas\consorcios\Servicios.Servicios.json', SINGLE_CLOB) as jr
        CROSS APPLY OPENJSON(BulkColumn)
        WITH (
            NombreConsorcio VARCHAR(100) '$."Nombre del consorcio"',
            Mes             VARCHAR(20)  '$.Mes',

            -- aca se encuentra el importe d cada servicio
            BANCARIOS       VARCHAR(50)  '$.BANCARIOS',
            LIMPIEZA        VARCHAR(50)  '$.LIMPIEZA',
            ADMINISTRACION  VARCHAR(50)  '$.ADMINISTRACION',
            SEGUROS         VARCHAR(50)  '$.SEGUROS',
            GASTOS_GRALES   VARCHAR(50)  '$."GASTOS GENERALES"',
            AGUA            VARCHAR(50)  '$."SERVICIOS PUBLICOS-Agua"',
            LUZ             VARCHAR(50)  '$."SERVICIOS PUBLICOS-Luz"'
        ) AS J
    CROSS APPLY (VALUES 
        ('BANCARIOS', J.BANCARIOS),
        ('LIMPIEZA', J.LIMPIEZA),
        ('ADMINISTRACION', J.ADMINISTRACION),
        ('SEGUROS', J.SEGUROS),
        ('GASTOS GENERALES', J.GASTOS_GRALES),
        ('SERVICIOS PUBLICOS-Agua', J.AGUA), 
        ('SERVICIOS PUBLICOS-Luz', J.LUZ)    
    ) AS T (TipoGastoBruto, ImporteBruto)
    WHERE Negocio.LimpiarNumero(T.ImporteBruto) IS NOT NULL 
          AND Negocio.LimpiarNumero(T.ImporteBruto) > 0;

    select * from #TemporalDatosServicio;


 
    -- 2- almacenar a Negocio.GastoOrdinario (B�squeda de FK y Mapeo)
    
    INSERT INTO Negocio.GastoOrdinario (
        idExpensa, nombreEmpresaoPersona, nroFactura, fechaEmision, importeTotal, detalle, tipoServicio
    )
    SELECT
        -- idExpensa
        (
            SELECT TOP 1 E.id
            FROM Negocio.Expensa AS E
            INNER JOIN Consorcio.Consorcio AS CM ON E.idConsorcio = CM.idConsorcio
            WHERE CM.NombreConsorcio = S.NombreConsorcio 
              AND E.PeriodoMes = LTRIM(RTRIM(S.Mes)) -- elimina espacios en blanco 
        ) AS idExpensa, 
        
        /*
        -- idConsorcio
        (
            SELECT TOP 1 CM.idConsorcio
            FROM Consorcio.Consorcio AS CM
            WHERE CM.NombreConsorcio = S.NombreConsorcio
        ) AS idConsorcio, */
        
        -- nombreEmpresaoPersona
        CASE S.TipoGastoBruto
            WHEN 'SERVICIOS PUBLICOS-Agua' THEN 'AYSA' 
            WHEN 'SERVICIOS PUBLICOS-Luz'  THEN 'EDENOR' 
            ELSE S.TipoGastoBruto 
        END AS nombreEmpresaoPersona,

        -- nroFactura
        CAST(ABS(CHECKSUM(NEWID() + CAST(@@SPID AS VARCHAR(10)))) AS VARCHAR(50)) AS nroFactura,
        
        -- fechaEmision (asumo que el a�o es actual)
        DATEFROMPARTS(YEAR(GETDATE()), 
                      CASE LTRIM(RTRIM(LOWER(S.Mes)))
                          WHEN 'enero' THEN 1 WHEN 'febrero' THEN 2 WHEN 'marzo' THEN 3
                          WHEN 'abril' THEN 4 WHEN 'mayo' THEN 5 WHEN 'junio' THEN 6
                          WHEN 'julio' THEN 7 WHEN 'agosto' THEN 8 WHEN 'septiembre' THEN 9
                          WHEN 'octubre' THEN 10 WHEN 'noviembre' THEN 11 WHEN 'diciembre' THEN 12
                          ELSE MONTH(GETDATE()) 
                      END, 
                      1) AS fechaEmision, 

        -- importeTotal
        S.Importe AS importeTotal,

        -- detalle
        'Gasto mensual - ' + S.TipoGastoBruto AS detalle,
        
        -- tipoServicio (unificado el servicio publico)
        CASE S.TipoGastoBruto
            WHEN 'SERVICIOS PUBLICOS-Agua' THEN 'SERVICIOS PUBLICOS'
            WHEN 'SERVICIOS PUBLICOS-Luz'  THEN 'SERVICIOS PUBLICOS'
            ELSE S.TipoGastoBruto 
        END AS tipoServicio

    FROM #TemporalDatosServicio AS S
    WHERE NOT EXISTS (

       -- busca duplicados
        SELECT 1 
        FROM Negocio.GastoOrdinario AS GO
        WHERE GO.nombreEmpresaoPersona = (
             CASE S.TipoGastoBruto WHEN 'SERVICIOS PUBLICOS-Agua' THEN 'AYSA' 
                                   WHEN 'SERVICIOS PUBLICOS-Luz' THEN 'EDENOR' 
                                   ELSE S.TipoGastoBruto END)
        -- Se asume que el idExpensa es la clave del per�odo
        AND GO.idExpensa = (
            SELECT TOP 1 E.id FROM Negocio.Expensa AS E
            INNER JOIN Consorcio.Consorcio AS CM ON E.idConsorcio = CM.idConsorcio
            WHERE CM.NombreConsorcio = S.NombreConsorcio AND E.PeriodoMes = LTRIM(RTRIM(S.Mes))
        )

    )
    -- Se inserta solo si ambas FK (idExpensa) se encuentran
    AND (SELECT TOP 1 E.id FROM Negocio.Expensa AS E 
         INNER JOIN Consorcio.ConsorcioAS CM ON E.idConsorcio = CM.idConsorcio
         WHERE CM.NombreConsorcio = S.NombreConsorcio AND E.PeriodoMes = LTRIM(RTRIM(S.Mes))) IS NOT NULL;
    


    -- 3- eliminar la tabla temporal
    DROP TABLE #TemporalDatosServicio;

END
GO

EXEC Negocio.sp_ImportarGastosMensuales;
go

-- IMPORTACION DE PERSONAS

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

 -- FIN IMPORTACION DE PERSONAS

--IMPORTAR DATOS DE CONSORCIO (del archivo de datos varios)
CREATE OR ALTER PROCEDURE Operaciones.sp_ImportarDatosConsorcio @rutaArch VARCHAR(1000)
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
--IMPORTAR DATOS DE PROVEEDORES
CREATE PROCEDURE Operaciones.sp_ImportarDatosProveedores @rutaArch VARCHAR(1000) 
AS
BEGIN
	SET NOCOUNT ON
	--pongo el nocount p q no salgan los mensajes de actualizacion
	--tabla temporal p dropear los datos del archivo 
    CREATE TABLE #TempProveedoresGasto 
	(
        tipoGastoCSV VARCHAR(100),
        nombreConsorcioCSV VARCHAR(100),
        nomEmpresaCSV VARCHAR(100),
        detalleCSV VARCHAR(200)
    );

    BEGIN TRY
        -- insert en sql dinamico pq sino no hay forma de hacer la ruta dinamica
        DECLARE @sqlBulk VARCHAR(MAX);
        SET @sqlBulk = '
            BULK INSERT #TempProveedoresGasto
            FROM ''' + @rutaArch + '''
            WITH (
                FIELDTERMINATOR = '';'',
                ROWTERMINATOR = ''\n'',
                FIRSTROW = 2, -- Asumo que tu CSV tiene encabezados
                CODEPAGE = ''ACP''
            );';
        EXEC(@sqlBulk);

        -- conexion de tablas para ver donde meter los datos

        UPDATE GastoOrdinario
        SET GastoOrdinario.nomEmpresaoPersona = T.nomEmpresaCSV, GastoOrdinario.detalle = T.detalleCSV
        FROM 
			GastoOrdinario
        -- de GastoOrdinario a Expensa
        JOIN
            Expensa ON GastoOrdinario.idExpensa = Expensa.id
        -- de Expensa a Consorcio
        JOIN
            Consorcio ON Expensa.consorcioId = Consorcio.id
        -- de Consorcio y GastoOrdinario a la tabla temporal
        JOIN
            #TempProveedoresGasto AS T 
            ON GastoOrdinario.tipoGasto = T.tipoGastoCSV  
            AND Consorcio.nombre = T.nombreConsorcioCSV
			--con esto me fijo q coincida el tipo de gasto con el nombre del consorcio para q identifique la expensa
    END TRY
	--cositas de seguridad por si se rompe algo
    BEGIN CATCH
        PRINT 'Error durante la actualización de gastos:' 
        PRINT ERROR_MESSAGE();
    END CATCH
    DROP TABLE #TempProveedoresGasto;
    SET NOCOUNT OFF;
END;
GO