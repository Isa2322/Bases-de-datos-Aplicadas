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

/* ================================================================================================
   CONFIGURACIÓN NECESARIA PARA USAR LOS STORED PROCEDURES CON ARCHIVOS EXCEL (.XLSX):

   Los procedures de importacion "Operaciones.sp_ImportarDatosConsorcios_excel" y 
   "Operaciones.sp_ImportarDatosProveedores_excel" requieren que SQL Server pueda acceder 
   al archivo de Excel usando el proveedor OLE DB de Microsoft (ACE). 

   Si el proveedor no está instalado o habilitado, utilizar los SP "Operaciones.sp_ImportarDatosConsorcios" y
   "Operaciones.sp_ImportarDatosProveedores" para la importacion.

   El procedimiento usa el proveedor `Microsoft.ACE.OLEDB.16.0` (versión moderna y más estable)

   Si está instalado, previo a la ejecucion de los SP ejecutar las siguientes sentencias:
   (Ejecutar con permisos de sysadmin en la base master)

       ```sql
       EXEC sp_configure 'show advanced options', 1;  
       RECONFIGURE;
       EXEC sp_configure 'Ad Hoc Distributed Queries', 1;  
       RECONFIGURE;
       EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.16.0', N'AllowInProcess', 1;
       EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.16.0', N'DynamicParameters', 1;
       ```
   ================================================================================================ */

CREATE OR ALTER PROCEDURE Operaciones.ImportarTiposRol
AS
BEGIN
    SET NOCOUNT ON;

    -- Inserta el tipo "Inquilino" si no existe
    IF NOT EXISTS (SELECT 1 FROM Consorcio.TipoRol WHERE nombre = 'Inquilino')
    BEGIN
        INSERT INTO Consorcio.TipoRol (nombre, descripcion)
        VALUES ('Inquilino', 'Persona que alquila una unidad funcional dentro del consorcio.');
    END

    -- Inserta el tipo "Propietario" si no existe
    IF NOT EXISTS (SELECT 1 FROM Consorcio.TipoRol WHERE nombre = 'Propietario')
    BEGIN
        INSERT INTO Consorcio.TipoRol (nombre, descripcion)
        VALUES ('Propietario', 'Dueño de una o más unidades funcionales dentro del consorcio.');
    END

    PRINT N'Carga de datos de Tipos de Rol finalizada.';
END
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

--Funcion para cargar el archivo pagos_consorcios.csv
CREATE OR ALTER PROCEDURE Operaciones.sp_ImportacionPago @RutaArchivo VARCHAR(255)
AS
BEGIN

IF OBJECT_ID('Operaciones.PagosConsorcioTemp') IS NOT NULL DROP TABLE Operaciones.PagosConsorcioTemp; 
CREATE TABLE Operaciones.PagosConsorcioTemp (
				idPago int , 
				fecha VARCHAR(10),
				CVU_CBU VARCHAR(22),
				valor varchar (12))

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
	PRINT('IMPORTANDO DATOS...')
        DECLARE @SQL NVARCHAR(MAX);
    SET @SQL = '
        BULK INSERT Operaciones.PagosConsorcioTemp
        FROM ''' + @RutaArchivo+ '''
        WITH
        (
            FIELDTERMINATOR = '','',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''ACP'',
            FIRSTROW = 2
        );';

    EXEC(@SQL);
	END	

DELETE FROM Operaciones.PagosConsorcioTemp-- Elimino las filas nulas en caso de que se generen
WHERE 
    idPago IS NULL
    AND fecha IS NULL
    AND CVU_CBU IS NULL
	AND valor IS NULL;


--Preparo los valores para cargar la tabla Pago.Pago 
UPDATE Operaciones.PagosConsorcioTemp
	SET valor = REPLACE(Valor, '$', '')


UPDATE Operaciones.PagosConsorcioTemp
	SET valor = CAST(valor AS DECIMAL(18,2))


UPDATE Operaciones.PagosConsorcioTemp
	SET fecha = CONVERT(DATE, fecha, 103)

ALTER TABLE Operaciones.PagosConsorcioTemp
	ADD idFormaPago INT

--inserto un valor provisorio para importar a la tabla Pago.FormaDePago
UPDATE P
SET P.idFormaPago = (
    SELECT TOP 1 idFormaPago
    FROM Pago.FormaDePago
)
FROM Operaciones.PagosConsorcioTemp AS P;


   INSERT INTO Pago.Pago(fecha ,importe , cbuCuentaOrigen, idFormaPago)
   select fecha, valor,CVU_CBU,idFormaPago
   from Operaciones.PagosConsorcioTemp
   where idPago IS NOT NULL

--SELECT *from pago.pago
--SELECT *from pago.FormaDepago
--SELECT* FROM Operaciones.PagosConsorcio

DROP TABLE Operaciones.PagosConsorcioTemp	
END
GO

-- Función para determinar el N-ésimo día hábil de un mes _________________________________________________  
-- PONERLO ANTES DE  CARGAR EXPENSA O CUALQUIER OTRA QUE LA UTILICE!!!!!

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

-- servicios.servicios.json 

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


-- ===============================================================================================================
-- IMPORTACION DE PERSONAS 

CREATE OR ALTER PROCEDURE Operaciones.sp_ImportarInquilinosPropietarios
    @RutaArchivo VARCHAR(255)
AS
BEGIN

    SET NOCOUNT ON;

    IF CHARINDEX('''', @RutaArchivo) > 0 OR
        CHARINDEX('--', @RutaArchivo) > 0 OR
        CHARINDEX('/*', @RutaArchivo) > 0 OR 
        CHARINDEX('*/', @RutaArchivo) > 0 OR
        CHARINDEX(';', @RutaArchivo) > 0
  
BEGIN
    RAISERROR('Nombre de archivo contiene caracteres invalidos.', 16, 1); RETURN;
END

    PRINT 'Iniciando importaci�n de: ' + @RutaArchivo;

-- Tabla temporal para importacion
    DROP TABLE IF EXISTS #TemporalPersonas;

    CREATE TABLE #TemporalPersonas (
        Nombre VARCHAR(30),
        Apellido VARCHAR(30),
        DNI BIGINT,
        Email VARCHAR(50),
        Telefono BIGINT,
        CVU_CBU VARCHAR(22),
        Tipo BIT
    );


-- bulk insert
    DECLARE @sql NVARCHAR(MAX);

    PRINT 'Iniciando importaci�n de: ' + @RutaArchivo;

    SET @sql = '
        BULK INSERT #TemporalPersonas
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
    DELETE FROM #TemporalPersonas
        WHERE 
        (Nombre IS NULL OR Nombre = '') AND
        (Apellido IS NULL OR Apellido = '') AND
        (DNI IS NULL OR DNI = '') AND
        (Email IS NULL OR Email = '') AND
        (Telefono IS NULL OR Telefono = '') AND
        (CVU_CBU IS NULL OR CVU_CBU = '') AND
        (Tipo IS NULL OR Tipo = '');


-- Se insertan los archivos en las tablas correspondientes

    DELETE FROM #TemporalPersonas
    WHERE CVU_CBU IN (
        SELECT CVU_CBU
        FROM #TemporalPersonas
        GROUP BY CVU_CBU
        HAVING COUNT(*) > 1
);


    INSERT INTO Consorcio.Persona (dni, nombre, apellido, CVU_CBU, telefono, email, idTipoRol)
    SELECT 
        LTRIM(RTRIM(tp.DNI)),
        LTRIM(RTRIM(tp.Nombre)),
        LTRIM(RTRIM(tp.Apellido)),
        LTRIM(RTRIM(tp.CVU_CBU)),
        LTRIM(RTRIM(tp.Telefono)),
        REPLACE(LTRIM(RTRIM(tp.Email)), ' ', ''),
        CASE tp.Tipo 
            WHEN 1 THEN 1  
            WHEN 0 THEN 2  
        END AS idTipoRol
    FROM #TemporalPersonas tp
    WHERE NOT EXISTS (
        SELECT 1 FROM Consorcio.Persona p WHERE p.DNI = tp.DNI
    );

    -- join de persona y cuenta bancaria por CBU para insertar con la FK
   INSERT INTO Consorcio.CuentaBancaria (CVU_CBU, nombreTitular)
    SELECT DISTINCT 
        LTRIM(RTRIM(it.CVU_CBU)) AS cbu,
        p.nombre
    FROM #TemporalPersonas it
    JOIN Consorcio.Persona p ON LTRIM(RTRIM(p.CVU_CBU)) = LTRIM(RTRIM(it.CVU_CBU))
    WHERE it.CVU_CBU IS NOT NULL AND it.CVU_CBU <> '';


    DROP TABLE IF EXISTS dbo.#TemporalPersonas
END;
GO


--==================================================================================================================
--IMPORTAR DATOS DE CONSORCIO (del archivo de datos varios en CSV)
CREATE OR ALTER PROCEDURE Operaciones.sp_ImportarDatosConsorcios @rutaArch VARCHAR(1000)
AS
BEGIN
    --esto es para verificar q la ruta venga bien escrita
       IF CHARINDEX('''', @rutaArch) > 0 OR
       CHARINDEX('--', @rutaArch) > 0 OR
       CHARINDEX('/*', @rutaArch) > 0 OR 
       CHARINDEX('*/', @rutaArch) > 0 OR
       CHARINDEX(';', @rutaArch) > 0
    BEGIN
        RAISERROR('La ruta contiene caracteres no permitidos ('' , -- , /*, */ , ;).', 16, 1);
        RETURN;
    END
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

/*  PRUEBO SP
DECLARE @rutaArchCSV VARCHAR(1000)
SET @rutaArchCSV = 'C:\Users\camil\OneDrive\Escritorio\Facultad\BDD\datos varios(Consorcios).csv'
EXEC Operaciones.sp_ImportarDatosProveedores @rutaArch = @rutaArchCSV
*/

--==================================================================================================================
--IMPORTAR DATOS DE PROVEEDORES (del archivo de datos varios en CSV)

CREATE OR ALTER PROCEDURE Operaciones.sp_ImportarDatosProveedores @rutaArch VARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    --esto es para verificar q la ruta venga bien escrita
       IF CHARINDEX('''', @rutaArch) > 0 OR
       CHARINDEX('--', @rutaArch) > 0 OR
       CHARINDEX('/*', @rutaArch) > 0 OR 
       CHARINDEX('*/', @rutaArch) > 0 OR
       CHARINDEX(';', @rutaArch) > 0
    BEGIN
        RAISERROR('La ruta contiene caracteres no permitidos ('' , -- , /*, */ , ;).', 16, 1);
        RETURN;
    END
    --tabla para el bulk insert del archivo
    CREATE TABLE #TempProveedoresGastoOriginal 
    (
        tipoGasto VARCHAR(100),
        columnaMixta VARCHAR(200),    
        detalleAlternativo VARCHAR(200),
        nomConsorcio VARCHAR(100)  
    )

    --tabla para los datos procesados
    CREATE TABLE #TempProveedoresGastoProcesado 
    (
        tipoGasto VARCHAR(100),
        nomEmpresa VARCHAR(200),    
        detalle VARCHAR(200),
        nomConsorcio VARCHAR(100)  
    )

    BEGIN TRY
        --bulkeo asi como vino el archivo (sql dinamico para no hardcodear la ruta)
        DECLARE @sqlBulk VARCHAR(2000);
        SET @sqlBulk = '
            BULK INSERT #TempProveedoresGastoOriginal
            FROM ''' + @rutaArch + '''
            WITH (
                FIELDTERMINATOR = '';'',
                ROWTERMINATOR = ''\n'',
                FIRSTROW = 2, -- Asumo que tu CSV tiene encabezados
                CODEPAGE = ''65001''
            )'
        EXEC (@sqlBulk)

        --procesamiento para extraer el detalle o poner lo q dice en la 3 columna
        INSERT INTO #TempProveedoresGastoProcesado 
        (
            tipoGasto,
            nomEmpresa,
            detalle,
            nomConsorcio
        )
        SELECT tipoGasto,
            -- el segundo campo (tipo gasto) esta en la columna 2 antes del guion, lo extraigo
            CASE
                WHEN CHARINDEX('-', columnaMixta) > 0 
                --si encuentra un - devuelve algo mayor a cero
                THEN TRIM(LEFT(columnaMixta, CHARINDEX('-', columnaMixta) - 1))
                --le indico con trim hasta donde cortar el dato, desde la izquierda hasta donde este el guion
                ELSE columnaMixta 
                --si no hay guion se usa el nombre en la columna nomas
            END AS nomEmpresa,
            -- el tercer campo (detalle) es o lo q viene dsps del guion o la columna 3
            CASE
                WHEN CHARINDEX('-', columnaMixta) > 0 
                THEN TRIM(RIGHT(columnaMixta, LEN(columnaMixta) - CHARINDEX('-', columnaMixta)))
                --si hay guion corto lo q haya a la derecha de el y ese es el detalle
                ELSE detalleAlternativo 
                -- si no hay guion, el detalle es la col 3
            END AS detalle,
            nomConsorcio
        FROM
            #TempProveedoresGastoOriginal
        
        --guardo en la tabla q corresponde usando la tabla procesada
        UPDATE Negocio.GastoOrdinario
        SET
            GastoOrdinario.nombreEmpresaoPersona = T_Proc.nomEmpresa,
            GastoOrdinario.detalle = T_Proc.detalle
        FROM
            Negocio.GastoOrdinario
        JOIN
            Negocio.Expensa ON GastoOrdinario.idExpensa = Expensa.id
        JOIN
            Consorcio.Consorcio ON Expensa.consorcio_id = Consorcio.id
        JOIN
            -- join con tabla procesada
            #TempProveedoresGastoProcesado AS T_Proc 
            -- Usamos el tipoGasto que extrajimos para el JOIN
            ON GastoOrdinario.tipoServicio = T_Proc.tipoGasto
            AND Consorcio.nombre = T_Proc.nomConsorcio;

    END TRY
    BEGIN CATCH
        PRINT 'Error durante la importacion de datos de Proveedores:';
        PRINT ERROR_MESSAGE();
    END CATCH
    -- limpio las temps
    DROP TABLE #TempProveedoresGastoOriginal;
    DROP TABLE #TempProveedoresGastoProcesado;
    SET NOCOUNT OFF;
END;
GO

/*  PRUEBO SP
DECLARE @rutaArchCSV VARCHAR(1000)
SET @rutaArchCSV = 'C:\Users\camil\OneDrive\Escritorio\Facultad\BDD\datos varios(Proveedores).csv'
EXEC Operaciones.sp_ImportarDatosProveedores @rutaArch = @rutaArchCSV
*/

--===============================================================================================================
-- IMPORTACION DIRECTAMENTE DESDE EL EXCEL PARA CONSORCIOS
CREATE OR ALTER PROCEDURE Operaciones.sp_ImportarDatosConsorcios_excel
    @rutaExcel VARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;

    -- valido ruta
    IF CHARINDEX('''', @rutaExcel) > 0 
    OR CHARINDEX('--', @rutaExcel) > 0 
    OR CHARINDEX('/', @rutaExcel) > 0 
    OR CHARINDEX('/', @rutaExcel) > 0
    OR CHARINDEX(';', @rutaExcel) > 0
    BEGIN
        RAISERROR('La ruta contiene caracteres no permitidos.', 16, 1);
        RETURN;
    END;

    -- tabla temporal para los datos
    IF OBJECT_ID('tempdb..#TempConsorcios') IS NOT NULL DROP TABLE #TempConsorcios
    --si existe la borro para evitar problemas
    CREATE TABLE #TempConsorcios 
    (
        nombre VARCHAR(200) NULL,
        direccion VARCHAR(300) NULL,
        superficieTotal DECIMAL(18,2) NULL
    )

    -- importo los datos desde el excel
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'
        INSERT INTO #TempConsorcios (nombre, direccion, superficieTotal)
        SELECT 
            CAST([Nombre]    AS VARCHAR(200)) AS nombre,
            CAST([Direccion] AS VARCHAR(300)) AS direccion,
            TRY_CAST([SuperficieTotal] AS DECIMAL(18,2)) AS superficieTotal
        FROM OPENROWSET(
            ''Microsoft.ACE.OLEDB.12.0'',
            ''Excel 12.0;HDR=YES;IMEX=1;Database=' + @rutaExcel + ''',
            ''SELECT * FROM [Consorcios$]''
        );';
    EXEC sys.sp_executesql @sql;

    -- elimino filas vacías
    DELETE FROM #TempConsorcios WHERE LTRIM(RTRIM(nombre)) = '';

    -- actualizo los consorcios existentes
    UPDATE c
    SET 
        c.direccion = ISNULL(t.direccion, c.direccion),
        c.superficieTotal = ISNULL(t.superficieTotal, c.superficieTotal)
    FROM Consorcio.Consorcio c
    INNER JOIN #TempConsorcios t ON c.nombre = t.nombre;

    -- inserto los nuevos consorcios que no existan todavía
    INSERT INTO Consorcio.Consorcio (nombre, direccion, superficieTotal)
    SELECT 
        t.nombre, 
        t.direccion, 
        t.superficieTotal
    FROM #TempConsorcios t
    WHERE NOT EXISTS (
        SELECT 1 
        FROM Consorcio.Consorcio c 
        WHERE c.nombre = t.nombre
    );

    DROP TABLE #TempConsorcios;
END;
GO
--===============================================================================================================
-- IMPORTACION DIRECTAMENTE DESDE EL EXCEL PARA PROVEEDORES

CREATE OR ALTER PROCEDURE Operaciones.sp_ImportarDatosProveedores_excel
    @rutaExcel VARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;

    -- valido ruta
    IF CHARINDEX('''', @rutaExcel) > 0 
    OR CHARINDEX('--', @rutaExcel) > 0 
    OR CHARINDEX('/', @rutaExcel) > 0 
    OR CHARINDEX('/', @rutaExcel) > 0
    OR CHARINDEX(';', @rutaExcel) > 0
    BEGIN
        RAISERROR('La ruta contiene caracteres no permitidos.', 16, 1);
        RETURN;
    END;


    -- tabla temporal original
    IF OBJECT_ID('tempdb..#TempProveedoresGastoOriginal') IS NOT NULL DROP TABLE #TempProveedoresGastoOriginal;
    CREATE TABLE #TempProveedoresGastoOriginal 
    (
        tipoGasto VARCHAR(100),
        columnaMixta VARCHAR(200),
        detalleAlternativo VARCHAR(200),
        nomConsorcio VARCHAR(100)
    );

    -- importo la hoja Proveedores$
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'
        INSERT INTO #TempProveedoresGastoOriginal (tipoGasto, columnaMixta, detalleAlternativo, nomConsorcio)
        SELECT 
            CAST([TipoGasto]    AS VARCHAR(100)),
            CAST([ColumnaMixta] AS VARCHAR(200)),
            CAST([DetalleAlt]   AS VARCHAR(200)),
            CAST([Consorcio]    AS VARCHAR(100))
        FROM OPENROWSET(
            ''Microsoft.ACE.OLEDB.12.0'',
            ''Excel 12.0;HDR=YES;IMEX=1;Database=' + @rutaExcel + ''',
            ''SELECT * FROM [Proveedores$]''
        );';
    EXEC sys.sp_executesql @sql;

    -- tabla temporal para procesar dastos antes de mandarlo a la tabla original
    IF OBJECT_ID('tempdb..#TempProveedoresGastoProcesado') IS NOT NULL DROP TABLE #TempProveedoresGastoProcesado;
    CREATE TABLE #TempProveedoresGastoProcesado 
    (
        tipoGasto VARCHAR(100),
        nomEmpresa VARCHAR(200),
        detalle VARCHAR(200),
        nomConsorcio VARCHAR(100)
    );

    -- proceso los datos para separar la columna mixta
    INSERT INTO #TempProveedoresGastoProcesado (tipoGasto, nomEmpresa, detalle, nomConsorcio)
    SELECT
        tipoGasto,
        CASE
            WHEN CHARINDEX('-', columnaMixta) > 0 
            --si hay guion me quedo con lo q tenga del lado izquierdo para el nombre de empresa
                THEN LTRIM(RTRIM(LEFT(columnaMixta, CHARINDEX('-', columnaMixta) - 1)))
            ELSE LTRIM(RTRIM(columnaMixta))
        END AS nomEmpresa,
        CASE
            WHEN CHARINDEX('-', columnaMixta) > 0 
            --si hay guion me quedo con el lado derecho para el detalle
                THEN LTRIM(RTRIM(SUBSTRING(columnaMixta, CHARINDEX('-', columnaMixta) + 1, 200)))
            ELSE LTRIM(RTRIM(detalleAlternativo))
        END AS detalle,
        LTRIM(RTRIM(nomConsorcio)) AS nomConsorcio
    FROM #TempProveedoresGastoOriginal;

    -- actualizo los gastos existentes
    UPDATE go
    SET 
        go.nombreEmpresaoPersona = p.nomEmpresa,
        go.detalle = p.detalle
    FROM Negocio.GastoOrdinario go
    INNER JOIN Negocio.Expensa e ON e.id = go.idExpensa
    INNER JOIN Consorcio.Consorcio c ON c.id = e.consorcio_id
    INNER JOIN #TempProveedoresGastoProcesado p
        ON p.tipoGasto = go.tipoServicio
       AND p.nomConsorcio = c.nombre;

    DROP TABLE #TempProveedoresGastoOriginal;
    DROP TABLE #TempProveedoresGastoProcesado;
END;
GO

--===============================================================================================================
CREATE OR ALTER PROCEDURE Operaciones.sp_CargaInquilinoPropietariosUF
    @RutaArchivo VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON; 

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
    SELECT 
		cd.CVU_CBUPersona,
        c.id,
        cd.numero,
        cd.piso,
        cd.departamento
    FROM #CargaDatosTemp AS cd
    JOIN Consorcio AS c ON cd.consorcio = c.nombre;

    -- UPDATE para registros existentes
    UPDATE UF
    SET 
        UF.numero = Ctemp.numero,
        UF.piso = Ctemp.piso,
        UF.departamento = Ctemp.departamento,
        UF.consorcioId = Ctemp.ID_Consorcio
    FROM UnidadFuncional AS UF
    INNER JOIN #ConsorcioTemp AS Ctemp ON UF.CVU_CBU = Ctemp.CVU_CBUPersona
    WHERE 
        UF.numero <> Ctemp.numero OR
        UF.piso <> Ctemp.piso OR
        UF.departamento <> Ctemp.departamento OR
        UF.consorcioId <> Ctemp.ID_Consorcio;
	
	INSERT INTO UnidadFuncional (CVU_CBU, numero, piso, departamento, consorcioId, metrosCuadrados, porcentajeExpensas)
    SELECT 
        Ctemp.CVU_CBUPersona, 
        Ctemp.numero, 
        Ctemp.piso, 
        Ctemp.departamento, 
        Ctemp.ID_Consorcio, 
        0, 
        0
    FROM #ConsorcioTemp AS Ctemp
    WHERE NOT EXISTS (
        SELECT 1 
        FROM UnidadFuncional AS UF 
        WHERE UF.CVU_CBU = Ctemp.CVU_CBUPersona
    );


	DROP TABLE IF EXISTS #CargaDatosTemp;
	DROP TABLE IF EXISTS #ConsorcioTemp;
END
GO

--_______________________________________________________________________________________________________________________

CREATE OR ALTER PROCEDURE Operaciones.sp_ImportarUFporConsorcio
    @RutaArchivo VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    -- Validación de caracteres peligrosos
    IF CHARINDEX('''', @RutaArchivo) > 0 OR
       CHARINDEX('--', @RutaArchivo) > 0 OR
       CHARINDEX('/*', @RutaArchivo) > 0 OR 
       CHARINDEX('*/', @RutaArchivo) > 0 OR
       CHARINDEX(';', @RutaArchivo) > 0
    BEGIN
        RAISERROR('La ruta contiene caracteres no permitidos ('' , -- , /*, */ , ;).', 16, 1);
        RETURN;
    END

    -- Crear tabla temporal
    IF OBJECT_ID('tempdb..#TemporalUF') IS NOT NULL 
        DROP TABLE #TemporalUF;

    CREATE TABLE #TemporalUF (
        CVU_CBU CHAR(22),
        nombreConsorcio VARCHAR(100),
        nroUnidadFuncional INT,
        piso VARCHAR(10),
        departamento VARCHAR(10)
    );

    -- BULK INSERT con SQL dinámico
    DECLARE @SQL NVARCHAR(MAX);

    SET @SQL = '
        BULK INSERT #TemporalUF
        FROM ''' + @RutaArchivo + '''
        WITH (
            FIELDTERMINATOR = ''|'',
            ROWTERMINATOR = ''\n'',
            FIRSTROW = 2,
            CODEPAGE = ''65001''
        );';
    
    EXEC sp_executesql @SQL;

    -- Borrar filas completamente nulas
    DELETE FROM #TemporalUF
    WHERE 
        (CVU_CBU IS NULL OR CVU_CBU = '') AND
        (nombreConsorcio IS NULL OR nombreConsorcio = '') AND
        (nroUnidadFuncional IS NULL) AND
        (piso IS NULL OR piso = '') AND
        (departamento IS NULL OR departamento = '');

    -- Insertar consorcios nuevos si no existen
    INSERT INTO Consorcio.Consorcio (nombre, direccion)
    SELECT DISTINCT 
        T.nombreConsorcio, 
        'Dirección desconocida'
    FROM #TemporalUF AS T
    WHERE NOT EXISTS (
        SELECT 1
        FROM Consorcio.Consorcio AS C
        WHERE C.nombre = T.nombreConsorcio
    );

    -- UPDATE de UF existentes
    UPDATE Consorcio.UnidadFuncional
    SET 
        consorcioId = C.id,
        numero = CAST(T.nroUnidadFuncional AS VARCHAR(10)),
        piso = T.piso,
        departamento = T.departamento
    FROM Consorcio.UnidadFuncional AS UF
    INNER JOIN #TemporalUF AS T ON UF.CVU_CBU = T.CVU_CBU
    INNER JOIN Consorcio.Consorcio AS C ON T.nombreConsorcio = C.nombre;

    -- INSERT de UF nuevas
    INSERT INTO Consorcio.UnidadFuncional (
        CVU_CBU, 
        consorcioId, 
        numero, 
        piso, 
        departamento
    )
    SELECT 
        T.CVU_CBU,
        C.id,
        CAST(T.nroUnidadFuncional AS VARCHAR(10)),
        T.piso,
        T.departamento
    FROM #TemporalUF AS T
    INNER JOIN Consorcio.Consorcio AS C ON T.nombreConsorcio = C.nombre
    WHERE NOT EXISTS (
        SELECT 1
        FROM Consorcio.UnidadFuncional AS UF
        WHERE UF.CVU_CBU = T.CVU_CBU
    );

    -- Limpiar tabla temporal
    DROP TABLE #TemporalUF;

END;
GO
