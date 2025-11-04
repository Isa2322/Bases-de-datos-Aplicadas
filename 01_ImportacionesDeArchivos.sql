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

-- Función de Limpieza: Crea un nuevo lote con GO
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
    
    -- Manejo de valores vacíos o NULL antes de la conversión
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

    -- tabla temporal
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


 
    -- 2- almacenar a Negocio.GastoOrdinario (Búsqueda de FK y Mapeo)
    
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
        
        -- fechaEmision (asumo que el año es actual)
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
        -- Se asume que el idExpensa es la clave del período
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


use [Com5600G11];
GO
DROP PROCEDURE IF EXISTS sp_ImportarInquilinosPropietarios;
GO

CREATE PROCEDURE sp_ImportarInquilinosPropietarios
    @RutaArchivo VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT 'Iniciando importación de: ' + @RutaArchivo;

-- Se eliminan las tablas si existen
    DROP TABLE IF EXISTS Persona.CuentaBancaria;
    DROP TABLE IF EXISTS Persona.Persona;

-- Se crean de nuevo
    CREATE TABLE Persona.Persona (
        ID INT IDENTITY(1,1) PRIMARY KEY, 
        DNI INT,
        Nombre VARCHAR(30),
        Apellido VARCHAR(30),
        CBU VARCHAR(22),
        Telefono INT,
        Email VARCHAR(50),
        Tipo VARCHAR(20),
    );
    CREATE TABLE Persona.CuentaBancaria (
        CBU VARCHAR(22) PRIMARY KEY,
        Banco VARCHAR(100) NULL,
        TitularId INT NULL,
        CONSTRAINT FK_Cuenta_Titular
        FOREIGN KEY (TitularId) REFERENCES Persona.Persona(ID)
    );

-- Tabla temporal para importacion
    DROP TABLE IF EXISTS ImportTemp;

    CREATE TABLE ImportTemp (
        Nombre VARCHAR(30),
        Apellido VARCHAR(30),
        DNI INT,
        Email VARCHAR(50),
        Telefono INT,
        CBU VARCHAR(22),
        Tipo VARCHAR(20)
    );

-- bulk insert
    DECLARE @sql NVARCHAR(MAX);

    SET @sql = '
        BULK INSERT ImportTemp
        FROM ''' + @RutaArchivo + '''
        WITH
        (
            FIELDTERMINATOR = '';'',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''ACP'',
            FIRSTROW = 2
        );';

    EXEC(@sql);

--borrar nulos
    DELETE FROM ImportTemp
WHERE 
    (Nombre IS NULL OR Nombre = '') AND
    (Apellido IS NULL OR Apellido = '') AND
    (DNI IS NULL OR DNI = '') AND
    (Email IS NULL OR Email = '') AND
    (Telefono IS NULL OR Telefono = '') AND
    (CBU IS NULL OR CBU = '') AND
    (Tipo IS NULL OR Tipo = '');

-- Se insertan los archivos en las tablas correspondientes
    INSERT INTO Persona.Persona (DNI, Nombre, Apellido, CBU, Telefono, Email, Tipo)
    SELECT DNI, Nombre, Apellido, CBU, Telefono, Email, Tipo
    FROM ImportTemp;

    -- join de persona y cuenta bancaria por CBU para insertar con la FK
    INSERT INTO Persona.CuentaBancaria (CBU, TitularId)
    SELECT DISTINCT it.CBU, p.ID
    FROM dbo.ImportTemp it
    JOIN Persona.Persona p ON p.CBU = it.CBU
    WHERE it.CBU IS NOT NULL AND it.CBU <> '';

END;
GO

EXEC sp_ImportarInquilinosPropietarios 
    @RutaArchivo = 'C:\Users\Abigail\Downloads\consorcios\Inquilino-propietarios-datos.csv';


    select * from Persona.Persona