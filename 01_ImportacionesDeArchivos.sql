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

IF OBJECT_ID('SP_CrearYcargar_FormasDePago_Semilla', 'P') IS NOT NULL
    DROP PROCEDURE SP_CrearYcargar_FormasDePago_Semilla
GO

CREATE PROCEDURE SP_CrearYcargar_FormasDePago_Semilla
AS
BEGIN
    
    PRINT N'Insertando/Verificando datos semilla en Pago.FormaDePago...';

    -- Transferencia Bancaria (m�s com�n para el CVU/CBU)
    IF NOT EXISTS (SELECT 1 FROM Pago.FormaDePago WHERE descripcion = 'Transferencia Bancaria')
    BEGIN
        INSERT INTO Pago.FormaDePago (descripcion, confirmacion) 
        VALUES ('Transferencia Bancaria', 'Comprobante');
    END

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

EXEC SP_CrearYcargar_FormasDePago_Semilla;
GO



-- servicios.servicios.json

-- Funci�n de Limpieza: Crea un nuevo lote con GO
IF OBJECT_ID('Negocio.LimpiarNumero') IS NOT NULL DROP FUNCTION Operaciones.LimpiarNumero;
GO

CREATE FUNCTION Operaciones.LimpiarNumero (@ImporteVarchar VARCHAR(50))
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

CREATE OR ALTER PROCEDURE Operaciones.sp_ImportarGastosMensuales
( 
    @ruta VARCHAR(500) 
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX);

    -- Tabla temporal
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

    -- La variable @ruta debe concatenarse para formar la cadena literal del BULK
    SET @sql = N'
    INSERT INTO #TemporalDatosServicio (NombreConsorcio, Mes, TipoGastoBruto, Importe)
    SELECT
        J.NombreConsorcio,
        J.Mes,
        T.TipoGastoBruto,
        Negocio.LimpiarNumero(T.ImporteBruto) 
    FROM OPENROWSET (BULK ''' + @ruta + ''', SINGLE_CLOB) AS jr
    CROSS APPLY OPENJSON(BulkColumn)
    WITH (
        NombreConsorcio VARCHAR(100) ''$."Nombre del consorcio"'',
        Mes             VARCHAR(20)  ''$.Mes'',
        BANCARIOS       VARCHAR(50)  ''$.BANCARIOS'',
        LIMPIEZA        VARCHAR(50)  ''$.LIMPIEZA'',
        ADMINISTRACION  VARCHAR(50)  ''$.ADMINISTRACION'',
        SEGUROS         VARCHAR(50)  ''$.SEGUROS'',
        GASTOS_GRALES   VARCHAR(50)  ''$."GASTOS GENERALES"'',
        AGUA            VARCHAR(50)  ''$."SERVICIOS PUBLICOS-Agua"'',
        LUZ             VARCHAR(50)  ''$."SERVICIOS PUBLICOS-Luz"''
    ) AS J
    CROSS APPLY (VALUES 
        (''BANCARIOS'', J.BANCARIOS),
        (''LIMPIEZA'', J.LIMPIEZA),
        (''ADMINISTRACION'', J.ADMINISTRACION),
        (''SEGUROS'', J.SEGUROS),
        (''GASTOS GENERALES'', J.GASTOS_GRALES),
        (''SERVICIOS PUBLICOS-Agua'', J.AGUA), 
        (''SERVICIOS PUBLICOS-Luz'', J.LUZ)     
    ) AS T (TipoGastoBruto, ImporteBruto)
    WHERE Negocio.LimpiarNumero(T.ImporteBruto) IS NOT NULL 
        AND Negocio.LimpiarNumero(T.ImporteBruto) > 0;

    SELECT * FROM #TemporalDatosServicio;';

    EXEC sp_executesql @sql
    
    -- almacenar a Negocio.GastoOrdinario
    
    INSERT INTO Negocio.GastoOrdinario (
        idExpensa, 
        nombreEmpresaoPersona, 
        nroFactura, 
        fechaEmision, 
        importeTotal, 
        detalle, 
        tipoServicio
    )
    SELECT
        -- idExpensa: Búsqueda de FK
        E.id AS idExpensa, 

        -- nombreEmpresaoPersona: Lógica de proveedor
        S.TipoGastoBruto AS nombreEmpresaoPersona,

        -- nroFactura: Generación de factura (aleatoria/checksum)
        CAST(ABS(CHECKSUM(NEWID() + CAST(@@SPID AS VARCHAR(10)))) AS VARCHAR(50)) AS nroFactura,
    
        -- fechaEmision: Calculo de fecha
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
        null AS detalle,
    
        -- tipoServicio
        S.TipoGastoBruto AS tipoServicio

    FROM #TemporalDatosServicio AS S

    -- unir la tabla temporal con la Expensa para obtener el id
    CROSS APPLY (
        SELECT TOP 1 E.id, CM.nombre 
        FROM Negocio.Expensa AS E
        INNER JOIN Consorcio.Consorcio AS CM ON E.consorcio_id = CM.idConsorcio 
        WHERE CM.nombre = S.NombreConsorcio and
        E.fechaPeriodo = E.periodo = LTRIM(RTRIM(S.Mes))
    ) AS E (id, NombreConsorcio_FK)

    -- evita duplicados si los encuentra ya en la tabla
    WHERE NOT EXISTS (
        SELECT 1 
        FROM Negocio.GastoOrdinario AS GO
        -- Condición de unicidad: Debe coincidir el idExpensa
        WHERE GO.idExpensa = E.id
        -- Y debe coincidir el tipo de servicio para el mismo período
        AND GO.tipoServicio = S.TipoGastoBruto
    )
    -- Se asegura de que la FK (E.id) se haya encontrado
    AND E.id IS NOT NULL;    
    
    -- eliminar la tabla temporal
    DROP TABLE #TemporalDatosServicio;

END
GO

-- Ejemplo de ejecución:
 EXEC Operaciones.sp_ImportarGastosMensuales @ruta = 'C:\Users\Milagros quispe\Documents\GitHub\Bases-de-datos-Aplicadas\consorcios\Servicios.Servicios.json';
 go
 select * from [Negocio].[GastoOrdinario];



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
GO
 -- FIN IMPORTACION DE PERSONAS



--IMPORTAR DATOS DE CONSORCIO (del archivo de datos varios)
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
