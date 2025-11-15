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

--==================================================================================================================
--Importar "pagos_consorcios"
--==================================================================================================================
CREATE OR ALTER PROCEDURE Operaciones.sp_ImportarPago (@RutaArchivo VARCHAR(255))
AS
BEGIN
    SET NOCOUNT ON;
    
    -- 1. Declaración de variable para la Forma de Pago por defecto
    DECLARE @DefaultFormaPagoID INT;

    -- 2. Verificar la existencia de Formas de Pago antes de continuar
    SELECT TOP 1 @DefaultFormaPagoID = idFormaPago
    FROM Pago.FormaDePago;

    IF @DefaultFormaPagoID IS NULL
    BEGIN
        -- Error si no hay formas de pago predefinidas
        RAISERROR('Error 515: La tabla Pago.FormaDePago está vacía. Por favor, inserte al menos una forma de pago antes de importar.', 16, 1);
        RETURN;
    END

    -- 3. Creación de la tabla temporal
    IF OBJECT_ID('Operaciones.PagosConsorcioTemp') IS NOT NULL 
        DROP TABLE Operaciones.PagosConsorcioTemp; 

    CREATE TABLE Operaciones.PagosConsorcioTemp (
        idPago INT, 
        fecha VARCHAR(10),
        CVU_CBU VARCHAR(22),
        valor VARCHAR(12)
    );

    -- 4. Validación de ruta de archivo
    IF CHARINDEX('''', @RutaArchivo) > 0 OR
        CHARINDEX('--', @RutaArchivo) > 0 OR
        CHARINDEX('/*', @RutaArchivo) > 0 OR 
        CHARINDEX('*/', @RutaArchivo) > 0 OR
        CHARINDEX(';', @RutaArchivo) > 0
    BEGIN
        RAISERROR('La ruta contiene caracteres no permitidos ('' , -- , /*, */ , ;).', 16, 1);
        RETURN;
    END
    
    -- 5. Carga masiva (BULK INSERT) con manejo de errores
    BEGIN TRY
        PRINT('IMPORTANDO DATOS...');
        DECLARE @SQL NVARCHAR(MAX);
        
        SET @SQL = N'
            BULK INSERT Operaciones.PagosConsorcioTemp
            FROM ''' + @RutaArchivo + N'''
            WITH
            (
                FIELDTERMINATOR = '','',
                ROWTERMINATOR = ''\n'',
                CODEPAGE = ''ACP'',
                FIRSTROW = 2
            );';

        EXEC sp_executesql @SQL;
    END TRY
    BEGIN CATCH
        -- Captura errores como Mens. 4861 (archivo no encontrado o bloqueado)
        PRINT CONCAT('Error durante BULK INSERT: ', ERROR_MESSAGE());
        -- Se aborta la ejecución si la carga falla
        IF OBJECT_ID('Operaciones.PagosConsorcioTemp') IS NOT NULL DROP TABLE Operaciones.PagosConsorcioTemp;
        RETURN;
    END CATCH

    -- 6. Limpieza de filas nulas (manteniendo tu lógica)
    DELETE FROM Operaciones.PagosConsorcioTemp
    WHERE 
        idPago IS NULL
        AND fecha IS NULL
        AND CVU_CBU IS NULL
        AND valor IS NULL;

    -- 7. Preparación y Transformación de datos
    -- Quitar '$' (asumiendo que es un reemplazo directo)
    UPDATE Operaciones.PagosConsorcioTemp
        SET valor = REPLACE(Valor, '$', '');

    -- Conversión a DECIMAL
    UPDATE Operaciones.PagosConsorcioTemp
        SET valor = CAST(valor AS DECIMAL(18,2));

    -- Conversión de fecha (asumiendo formato 103 = dd/mm/yyyy)
    UPDATE Operaciones.PagosConsorcioTemp
        SET fecha = CONVERT(DATE, fecha, 103);

    -- 8. Asignar idFormaPago y realizar la inserción
    
    -- Agregar la columna para la FK
    ALTER TABLE Operaciones.PagosConsorcioTemp
        ADD idFormaPago INT NULL; -- Temporalmente permitimos NULLs en la temporal

    -- Asignar el ID de forma de pago pre-validado (no será NULL)
    UPDATE P
    SET P.idFormaPago = @DefaultFormaPagoID
    FROM Operaciones.PagosConsorcioTemp AS P;

    -- Inserción final en la tabla principal
    INSERT INTO Pago.Pago(fecha, importe, cbuCuentaOrigen, idFormaPago)
    SELECT fecha, valor, CVU_CBU, idFormaPago
    FROM Operaciones.PagosConsorcioTemp
    WHERE idPago IS NOT NULL
    
    PRINT CONCAT('Importación finalizada. Filas insertadas: ', @@ROWCOUNT);

    -- 9. Limpieza de la tabla temporal
    IF OBJECT_ID('Operaciones.PagosConsorcioTemp') IS NOT NULL 
        DROP TABLE Operaciones.PagosConsorcioTemp;
        
END
GO

IF OBJECT_ID('Operaciones.sp_ImportarPago', 'P') IS NOT NULL
PRINT 'Stored Procedure: Operaciones.sp_ImportarPago creado exitosamente, las modificaciones seran insertadas en la tabla "Pago.Pago"'
GO

--========================================================
-- Función para determinar el N-ésimo día hábil de un mes
--========================================================

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

--============================================
--Funcion de Limpieza SP Importar Servicios
--============================================

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

--==================================================================================================================
--Importar "Servicios.Servicios"
--==================================================================================================================

CREATE OR ALTER PROCEDURE Operaciones.sp_ImportarGastosMensuales
( 
    @ruta VARCHAR(500) 
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX);
    DECLARE @AnoActual INT = YEAR(GETDATE());
    
    -- PASO 1: Obtener el último ID de la tabla para usarlo como base.
    -- El + 1 se agregará implícitamente al sumar el ConteoUnico (que empieza en 1)
    DECLARE @UltimoIDBase INT;
    SELECT @UltimoIDBase = ISNULL(IDENT_CURRENT('Negocio.GastoOrdinario'), 0);
    
    -- 1. Tabla temporal (Resto del código de carga sin cambios)
    IF OBJECT_ID('tempdb..#TemporalDatosServicio') IS NOT NULL DROP TABLE #TemporalDatosServicio;
    CREATE TABLE #TemporalDatosServicio (
        NombreConsorcio VARCHAR(100),
        Mes VARCHAR(20),
        TipoGastoBruto VARCHAR(25), 
        Importe DECIMAL(18, 2),
        MesNumerico INT
    );

    IF CHARINDEX('''', @ruta) > 0 OR CHARINDEX('--', @ruta) > 0 OR
        CHARINDEX('/*', @ruta) > 0 OR CHARINDEX('*/', @ruta) > 0 OR
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
    END;
    
    WITH CTE_GastosPreparados AS (
        SELECT
            CM.id AS consorcioId,
            S.TipoGastoBruto,
            S.MesNumerico,
            S.Importe,
            -- Genera un contador único global para este lote de inserción
            @UltimoIDBase + ROW_NUMBER() OVER (ORDER BY CM.id, S.MesNumerico, S.TipoGastoBruto) AS IDUnicoBase
        FROM #TemporalDatosServicio AS S
        INNER JOIN Consorcio.Consorcio AS CM
            ON CM.nombre = S.NombreConsorcio
    )
    
    INSERT INTO Negocio.GastoOrdinario (
        idExpensa, 
        consorcioId,
        nombreEmpresaoPersona,
        fechaEmision, 
        importeTotal, 
        detalle, 
        tipoServicio,
        nroFactura
    )
    SELECT
        NULL AS idExpensa, 
        GP.consorcioId,
        NULL AS nombreEmpresaoPersona,
    
        DATEFROMPARTS(
            @AnoActual,
            GP.MesNumerico,
            1 -- Día 1
        ) AS fechaEmision, 
        GP.Importe AS importeTotal,
        null AS detalle,
        GP.TipoGastoBruto AS tipoServicio,

        -- Generación de nroFactura (4 Consorcio ID + 4 YYMM + 3 ID Base Unico = 11 dígitos)
        RIGHT('0000' + CAST(GP.consorcioId AS VARCHAR(4)), 3) + -- Consorcio ID (4 dígitos)
        RIGHT(
            CAST((@AnoActual * 100) + GP.MesNumerico AS VARCHAR(6))
        , 4) + -- YYMM (4 dígitos)
        -- Se usa un hash simple del ID Único Base para mantener 3 dígitos
        RIGHT('000' + CAST(ABS(CHECKSUM(GP.IDUnicoBase)) % 1000 AS VARCHAR(3)), 3) 
        AS nroFactura

    FROM CTE_GastosPreparados AS GP;
    END 
GO

IF OBJECT_ID('Operaciones.sp_ImportarGastosMensuales', 'P') IS NOT NULL
PRINT 'Stored Procedure: Operaciones.sp_ImportarGastosMensuales creado exitosamente, las modificaciones seran insertadas en la tabla "Negocio.GastoOrdinario"'
GO

--==================================================================================================================
--Importar "Inquilino-propietarios-datos"
--==================================================================================================================

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
        SELECT 1 FROM Consorcio.Persona p 
        WHERE p.DNI = tp.DNI
        AND p.CVU_CBU = tp.CVU_CBU
    );


    DROP TABLE IF EXISTS dbo.#TemporalPersonas
END;
GO

IF OBJECT_ID('Operaciones.sp_ImportarInquilinosPropietarios', 'P') IS NOT NULL
PRINT 'Stored Procedure: Operaciones.sp_ImportarInquilinosPropietarios creado exitosamente, las modificaciones seran insertadas en la tabla "Consorcio.Persona"'
GO

--==================================================================================================================
--Importar "datos varios (Consorcios)"
--==================================================================================================================

CREATE OR ALTER PROCEDURE Operaciones.sp_ImportarDatosConsorcios
    @rutaArch VARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;

    -- Validación básica de ruta
    IF CHARINDEX('''', @rutaArch) > 0 
    OR CHARINDEX('--', @rutaArch) > 0 
    OR CHARINDEX('/*', @rutaArch) > 0 
    OR CHARINDEX('*/', @rutaArch) > 0 
    OR CHARINDEX(';',  @rutaArch) > 0
    BEGIN
        RAISERROR('La ruta contiene caracteres no permitidos ('' , -- , /*, */ , ;).', 16, 1);
        RETURN;
    END;

    -- tabla temporal para importar los datos de consorcio
    IF OBJECT_ID('tempdb..#TempConsorciosBulk') IS NOT NULL DROP TABLE #TempConsorciosBulk;
    CREATE TABLE #TempConsorciosBulk
    (
        consorcioCSV        VARCHAR(100) NULL,
        nombreCSV           VARCHAR(200) NULL,
        direccionCSV        VARCHAR(300) NULL,
        cantUnidadesCSV     INT          NULL,
        superficieTotalCSV  DECIMAL(18,2) NULL
    );

    -- traigo todos los datos del archivo a la tabla temporal, uso sql dinamico pq no se puede hardcodear la ruta
    DECLARE @sqlBulk NVARCHAR(MAX) = N'
        BULK INSERT #TempConsorciosBulk
        FROM ''' + @rutaArch + N'''
        WITH (
            FIELDTERMINATOR = '','',
            ROWTERMINATOR   = ''0x0a'', 
            FIRSTROW        = 2,
            CODEPAGE        = ''65001'',
            TABLOCK, KEEPNULLS
        );';
    EXEC(@sqlBulk);

    -- aca voy a actualizar
    UPDATE c
    SET
        c.direccion = ISNULL(t.direccionCSV, c.direccion),
        c.metrosCuadradosTotal = ISNULL(t.superficieTotalCSV, c.metrosCuadradosTotal)
    FROM Consorcio.Consorcio AS c
    INNER JOIN #TempConsorciosBulk AS t
        ON LTRIM(RTRIM(c.nombre)) = LTRIM(RTRIM(t.nombreCSV))
    WHERE t.nombreCSV IS NOT NULL AND LTRIM(RTRIM(t.nombreCSV)) <> ''; -- Solo actualizar si el nombre es válido

    -- aca inserto si el consorcio no estaba entre los ya registrados
    --el criterio para esto es q el consorcio q tenga nombre distinto es nuevo
    INSERT INTO Consorcio.Consorcio (nombre, direccion, metrosCuadradosTotal, CVU_CBU)
    SELECT
        t.nombreCSV,
        t.direccionCSV,
        t.superficieTotalCSV,
        NULL AS CVU_CBU
    FROM #TempConsorciosBulk AS t
    WHERE 
        t.nombreCSV IS NOT NULL 
        AND LTRIM(RTRIM(t.nombreCSV)) <> '' -- chequeo q no sea vacio el name
        AND NOT EXISTS --y q no existe en la tabla antes
        (
            SELECT 1
            FROM Consorcio.Consorcio AS c
            WHERE LTRIM(RTRIM(c.nombre)) = LTRIM(RTRIM(t.nombreCSV))
        );

    -- dropeo la tabla temporal
    DROP TABLE #TempConsorciosBulk;
    SET NOCOUNT OFF;
END
GO

IF OBJECT_ID('Operaciones.sp_ImportarDatosConsorcios', 'P') IS NOT NULL
PRINT 'Stored Procedure: Operaciones.sp_ImportarDatosConsorcios creado exitosamente, las modificaciones seran insertadas en la tabla "Consorcio.Consorcio"'
GO

--==================================================================================================================
--Importar "datos varios (Proveedores)"
--==================================================================================================================

CREATE OR ALTER PROCEDURE  Operaciones.sp_ImportarDatosProveedores
(
    @rutaArch VARCHAR(500) 
)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Validar la ruta de entrada para evitar inyección SQL
    IF CHARINDEX('''', @rutaArch) > 0 OR CHARINDEX('--', @rutaArch) > 0 OR
       CHARINDEX('/*', @rutaArch) > 0 OR CHARINDEX('*/', @rutaArch) > 0 OR
       CHARINDEX(';', @rutaArch) > 0
    BEGIN
        RAISERROR('La ruta contiene caracteres no permitidos.', 16, 1);
        RETURN;
    END;

    -- 2. Tabla temporal para cargar los datos crudos del CSV
    IF OBJECT_ID('tempdb..#TemporalProveedores') IS NOT NULL DROP TABLE #TemporalProveedores;
    CREATE TABLE #TemporalProveedores (
        TipoGasto VARCHAR(100),
        NombreEmpresaDetalle VARCHAR(255),
        DetalleAdicional VARCHAR(255),
        NombreConsorcio VARCHAR(100)
    );

    -- 3. Cargar datos desde el CSV
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'
    BULK INSERT #TemporalProveedores
            FROM ''' + @rutaArch + N'''
            WITH (
                FIELDTERMINATOR = '';'',
                ROWTERMINATOR   = ''0x0a'',
                FIRSTROW        = 2,
                CODEPAGE        = ''65001'',
                TABLOCK, KEEPNULLS
            );';

    BEGIN TRY
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        PRINT 'Error al cargar el CSV. Detalles:';
        PRINT ERROR_MESSAGE();
        RAISERROR('No se pudieron cargar los datos del CSV. Verifique la ruta, permisos y formato.', 16, 1);
        RETURN;
    END CATCH;

   -- select * from #TemporalProveedores;
    -- 4. CTE procesa la tabla
    WITH CTE_ProveedoresProcesados AS (
    SELECT
        TP.NombreConsorcio as NombreConsorcio,

        -- Normalización del tipoServicio
        CASE
            WHEN UPPER(TP.TipoGasto) LIKE 'GASTOS BANCARIOS%' THEN 'BANCARIOS'
            WHEN UPPER(TP.TipoGasto) LIKE 'GASTOS DE ADMINISTRACION%' THEN 'ADMINISTRACION'
            WHEN UPPER(TP.TipoGasto) LIKE 'GASTOS DE LIMPIEZA%' THEN 'LIMPIEZA'
            WHEN UPPER(TP.TipoGasto) LIKE 'SEGUROS%' THEN 'SEGUROS'
            WHEN UPPER(TP.TipoGasto) LIKE 'SERVICIOS PUBLICOS%' THEN 'SERVICIOS PUBLICOS'
            ELSE UPPER(TP.TipoGasto)
        END AS tipoServicio_Normalizado,

        -- Nuevo tipoServicio (solo para AYSA/EDENOR)
        CASE 
            WHEN UPPER(TP.NombreEmpresaDetalle) = 'AYSA' THEN 'SERVICIOS PUBLICOS'
            WHEN UPPER(TP.NombreEmpresaDetalle) = 'EDENOR' THEN 'SERVICIOS PUBLICOS'
            ELSE NULL
        END AS tipoServicio_Nuevo,

        -- Nombre de empresa/persona (normal)
        LTRIM(RTRIM(LEFT(TP.NombreEmpresaDetalle, CHARINDEX('-', TP.NombreEmpresaDetalle + '-') - 1)))
            AS nombreEmpresaoPersona,

        -- Detalle (normal)
        ISNULL(
            NULLIF(LTRIM(RTRIM(TP.DetalleAdicional)), ''), 
            NULLIF(
                LTRIM(RTRIM(SUBSTRING(TP.NombreEmpresaDetalle, CHARINDEX('-', TP.NombreEmpresaDetalle) + 1, 8000))),
                ''
            )
        ) AS detalle
    FROM #TemporalProveedores TP
    )
    --/*
    -- 1) Actualizaciones NORMALES con CTE

    
    UPDATE GA
    SET
        GA.nombreEmpresaoPersona = PP.nombreEmpresaoPersona,
        GA.detalle               = PP.detalle,
        GA.tipoServicio          = ISNULL(PP.tipoServicio_Nuevo, GA.tipoServicio)
    FROM Negocio.GastoOrdinario GA

    JOIN Consorcio.Consorcio C
        ON C.id = GA.consorcioId
       
    JOIN CTE_ProveedoresProcesados PP
    ON UPPER(LTRIM(RTRIM(GA.tipoServicio)))
        LIKE UPPER(LTRIM(RTRIM(PP.tipoServicio_Normalizado))) + '%'

    WHERE NULLIF(LTRIM(RTRIM(GA.detalle)), '') IS NULL AND  GA.tipoServicio <> 'GASTOS GENERALES';



    -- 6. Limpieza
    IF OBJECT_ID('tempdb..#TemporalProveedores') IS NOT NULL DROP TABLE #TemporalProveedores;

    SET NOCOUNT OFF;
END
GO

IF OBJECT_ID('Operaciones.sp_ImportarDatosProveedores', 'P') IS NOT NULL
PRINT 'Stored Procedure: Operaciones.sp_ImportarDatosProveedores creado exitosamente, las modificaciones seran insertadas en la tabla "Consorcio.Proveedores"'
GO

--===============================================================================================================
--Importar "Inquilinos-Propietarios-UF"
--===============================================================================================================

CREATE OR ALTER PROCEDURE Operaciones.sp_ImportarUFInquilinos
    @RutaArchivo VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    DROP TABLE IF EXISTS #TempUFInquilinos;

    CREATE TABLE #TempUFInquilinos (
        CVU_CBUPersona VARCHAR(22),
        nombreConsorcio VARCHAR(100),
        numero INT,
        piso char(4),
        departamento CHAR
    );

        -- sanity check de ruta
    IF CHARINDEX('''', @RutaArchivo ) > 0 OR
       CHARINDEX('--', @RutaArchivo ) > 0 OR
       CHARINDEX('/*', @RutaArchivo ) > 0 OR 
       CHARINDEX('*/', @RutaArchivo ) > 0 OR
       CHARINDEX(';',  @RutaArchivo ) > 0
    BEGIN
        RAISERROR('La ruta contiene caracteres no permitidos ('' , -- , /*, */ , ;).', 16, 1);
        RETURN;
    END;

    DECLARE @SQL NVARCHAR(MAX) = N'
        BULK INSERT #TempUFInquilinos
        FROM ''' + @RutaArchivo + '''
        WITH (
            FIELDTERMINATOR = ''|'',
            -- CAMBIO CLAVE: Usamos 0x0a (Line Feed) para mayor compatibilidad
            ROWTERMINATOR = ''\n'', 
            FIRSTROW = 2
        );';
    EXEC sp_executesql @SQL;

    -- DIAGNÓSTICO 1: Filas cargadas en la tabla temporal
    DECLARE @CargasTemp INT = @@ROWCOUNT;

    IF @CargasTemp = 0 
    BEGIN
        PRINT CONCAT('ERROR CRÍTICO: BULK INSERT cargó 0 filas. Verifique la ruta del archivo (', @RutaArchivo, ') y los permisos de SQL Server.');
        DROP TABLE IF EXISTS #TempUFInquilinos;
        RETURN;
    END
    ELSE
    BEGIN
        PRINT CONCAT('Filas cargadas en la temporal: ', @CargasTemp);
    END
    
    DECLARE @FilasInsertadas INT;
    
    INSERT INTO Consorcio.UnidadFuncional (
        CVU_CBU,
        consorcioId,
        numero,
        piso,
        departamento,
        metrosCuadrados,    
        porcentajeExpensas, 
        tipo                
    )
    SELECT
        LTRIM(RTRIM(I.CVU_CBUPersona)) AS CVU_CBU,
        (
            SELECT C.id 
            FROM Consorcio.Consorcio AS C 
            WHERE LTRIM(RTRIM(I.nombreConsorcio)) = C.nombre
        )  AS consorcioId,
        LTRIM(RTRIM(I.numero)),
        I.piso,
        LTRIM(RTRIM(I.departamento)),
        NULL, -- m2
        NULL, -- coeficiente
        NULL  -- tipo
    FROM #TempUFInquilinos AS I

    -- WHERE EXISTS: Validar Clave Foránea (falla si el CVU/CBU no existe en CuentaBancaria)
    WHERE NOT EXISTS (
        SELECT 1 
        FROM Consorcio.UnidadFuncional AS ExistingUF 
        WHERE ExistingUF.CVU_CBU = LTRIM(RTRIM(I.CVU_CBUPersona))
    );
   
    SET @FilasInsertadas = @@ROWCOUNT;

    PRINT CONCAT('Filas insertadas en UnidadFuncional: ', @FilasInsertadas);
    DROP TABLE #TempUFInquilinos;
END
GO

IF OBJECT_ID('Operaciones.sp_ImportarUFInquilinos', 'P') IS NOT NULL
PRINT 'Stored Procedure: Operaciones.sp_ImportarUFInquilinos creado exitosamente, las modificaciones seran insertadas en la tabla "Consorcio.UnidadFuncional"'
GO

--===============================================================================================================
--Importar "UF por Consorcio"
--===============================================================================================================

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

    -- 1. Crear tabla temporal de importación
    IF OBJECT_ID('tempdb..#TemporalUF') IS NOT NULL 
        DROP TABLE #TemporalUF;

    CREATE TABLE #TemporalUF (
        nombreConsorcio VARCHAR(100), 
        nroUnidadFuncional VARCHAR(50), 
        piso VARCHAR(10), 
        departamento VARCHAR(10), 
        coeficiente_txt VARCHAR(10), 
        m2_uf_txt VARCHAR(10),
        bauleras_txt VARCHAR(10), 
        cochera_txt VARCHAR(10), 
        m2_baulera_txt VARCHAR(10), 
        m2_cochera_txt VARCHAR(10)
    );

    -- BULK INSERT
    DECLARE @SQL NVARCHAR(MAX);
    SET @SQL = '
        BULK INSERT #TemporalUF
        FROM ''' + @RutaArchivo + '''
        WITH (
            FIELDTERMINATOR = ''\t'',
            ROWTERMINATOR = ''0x0a'',
            FIRSTROW = 2,
            CODEPAGE = ''65001''
        );';
    
    EXEC sp_executesql @SQL;

    -- Limpieza inicial de nulos/vacíos
    DELETE FROM #TemporalUF
    WHERE 
        (LTRIM(RTRIM(nombreConsorcio)) IS NULL OR LTRIM(RTRIM(nombreConsorcio)) = '')
        OR
        (LTRIM(RTRIM(nroUnidadFuncional)) IS NULL OR LTRIM(RTRIM(nroUnidadFuncional)) = '');

    -- Insertar consorcios nuevos si no existen (necesario para obtener el consorcioId)
    INSERT INTO Consorcio.Consorcio (nombre, direccion)
    SELECT DISTINCT 
        LTRIM(RTRIM(T.nombreConsorcio)), 
        'Dirección desconocida'
    FROM #TemporalUF AS T
    WHERE NOT EXISTS (
        SELECT 1
        FROM Consorcio.Consorcio AS C
        WHERE C.nombre = LTRIM(RTRIM(T.nombreConsorcio))
    );

    IF OBJECT_ID('tempdb..#UFDataLimpia') IS NOT NULL 
        DROP TABLE #UFDataLimpia;
    
    CREATE TABLE #UFDataLimpia (
        consorcioId INT NOT NULL,
        nroUnidadFuncional VARCHAR(50),
        coeficiente DECIMAL(5, 2),
        m2_unidad_funcional DECIMAL(10, 2),
        tipo VARCHAR(20) NOT NULL -- Campo generado
    );

    -- Insertar datos limpios en la tabla temporal, generando el campo 'tipo'
    INSERT INTO #UFDataLimpia (consorcioId, nroUnidadFuncional, coeficiente, m2_unidad_funcional, tipo)
    SELECT
        C.id AS consorcioId,
        T.nroUnidadFuncional,
        CAST(REPLACE(T.coeficiente_txt, ',', '.') AS DECIMAL(5, 2)) AS coeficiente,
        CAST(REPLACE(T.m2_uf_txt, ',', '.') AS DECIMAL(10, 2)) AS m2_unidad_funcional,
        -- Lógica de generación de TIPO
        CASE ABS(CHECKSUM(NEWID())) % 3
        WHEN 0 THEN 'local'
        WHEN 1 THEN 'departamento'
        ELSE 'duplex'
        END AS tipo
    FROM #TemporalUF AS T
    INNER JOIN Consorcio.Consorcio AS C 
        ON LTRIM(RTRIM(T.nombreConsorcio)) = C.nombre;
    
    DECLARE @UF_Limpias INT = @@ROWCOUNT;
    PRINT CONCAT('Filas limpias listas para actualizar: ', @UF_Limpias);

    UPDATE UF
    SET 
        -- Rellena metrosCuadrados solo si es NULL
        metrosCuadrados = ISNULL(UF.metrosCuadrados, UFL.m2_unidad_funcional),
        
        -- Rellena coeficiente (porcentajeExpensas) solo si es NULL
        porcentajeExpensas = ISNULL(UF.porcentajeExpensas, UFL.coeficiente), 
        
        -- Rellena tipo solo si es NULL (usa el valor generado)
        tipo = ISNULL(UF.tipo, UFL.tipo)
        
    FROM Consorcio.UnidadFuncional AS UF
    INNER JOIN #UFDataLimpia AS UFL 
        ON UF.consorcioId = UFL.consorcioId 
        AND UF.numero = UFL.nroUnidadFuncional
        
    -- Condición para asegurar que solo actualizamos UFs que aún no tienen estos datos
    -- Esto es opcional, pero hace el UPDATE más eficiente si solo se quiere rellenar NULLs.
    WHERE UF.metrosCuadrados IS NULL 
       OR UF.porcentajeExpensas IS NULL 
       OR UF.tipo IS NULL;
    
    DECLARE @UF_Actualizadas INT = @@ROWCOUNT;
    PRINT CONCAT('Unidades Funcionales actualizadas: ', @UF_Actualizadas);

    -- 4. Limpiar tablas temporales
    DROP TABLE #TemporalUF;
    DROP TABLE #UFDataLimpia;
    
    PRINT 'Proceso de relleno de campos de Unidades Funcionales finalizado.';

END
GO

IF OBJECT_ID('Operaciones.sp_ImportarUFporConsorcio', 'P') IS NOT NULL
PRINT 'Stored Procedure: Operaciones.sp_ImportarUFporConsorcio creado exitosamente, las modificaciones seran insertadas en la tabla "Consorcio.UnidadFuncional"'
GO


