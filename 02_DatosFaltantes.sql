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

--======================================================================================================
-- Rellenar tabla TIPO DE ROL
--======================================================================================================

CREATE OR ALTER PROCEDURE Operaciones.CargaTiposRol
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

-- ======================================================================================================
-- Rellenar tabla FORMAS DE PAGO
-- ======================================================================================================

IF OBJECT_ID('Operaciones.SP_CrearYcargar_FormasDePago_Semilla', 'P') IS NOT NULL
    DROP PROCEDURE Operaciones.SP_CrearYcargar_FormasDePago_Semilla
GO

CREATE PROCEDURE Operaciones.SP_CrearYcargar_FormasDePago_Semilla
AS
BEGIN
    
    PRINT N'Insertando/Verificando datos semilla en Pago.FormaDePago...';

    -- Transferencia Bancaria (mas comun para el CVU/CBU)
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
        VALUES ('Mercado Pago/Billetera', 'ID de Transaccion');
    END

    PRINT N'Carga de datos de Formas de Pago finalizada.';

END
GO

-- ======================================================================================================
-- Rellenar tabla COCHERA
-- ======================================================================================================

CREATE OR ALTER PROCEDURE Operaciones.sp_RellenarCocheras
AS
BEGIN
    SET NOCOUNT ON;

    /*
        Rellena la tabla Consorcio.Cochera con datos derivados de UnidadFuncional.
        - Se crea 1 cochera por UF (si el consorcio aún no tiene cocheras).
        - El número se asigna incrementalmente por consorcio.
        - El porcentaje de expensas es proporcional al m2 de la UF / total del consorcio.
    */

    DECLARE @idConsorcio INT, @maxNum INT;

    DECLARE Consorcios CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT consorcioId FROM Consorcio.UnidadFuncional;

    OPEN Consorcios;
    FETCH NEXT FROM Consorcios INTO @idConsorcio;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Calcular base del total de m2 del consorcio
        DECLARE @totalM2 DECIMAL(18,2) = (
            SELECT SUM(ISNULL(metrosCuadrados,0))
            FROM Consorcio.UnidadFuncional
            WHERE consorcioId = @idConsorcio
        );

        -- Número actual de cocheras en este consorcio
        SET @maxNum = ISNULL(
            (SELECT MAX(10) FROM Consorcio.Cochera c
             INNER JOIN Consorcio.UnidadFuncional uf ON uf.id = c.unidadFuncionalId
             WHERE uf.consorcioId = @idConsorcio),
        0);

        INSERT INTO Consorcio.Cochera (unidadFuncionalId, numero, porcentajeExpensas)
        SELECT 
            uf.id AS unidadFuncionalId,
            ROW_NUMBER() OVER (ORDER BY uf.id) + @maxNum AS numero,
            CASE WHEN @totalM2 > 0 THEN ROUND((uf.metrosCuadrados / @totalM2) * 100, 2) ELSE 0 END AS porcentajeExpensas
        FROM Consorcio.UnidadFuncional uf
        WHERE uf.consorcioId = @idConsorcio
          AND NOT EXISTS (
              SELECT 1 FROM Consorcio.Cochera c WHERE c.unidadFuncionalId = uf.id
          );

        FETCH NEXT FROM Consorcios INTO @idConsorcio;
    END

    CLOSE Consorcios;
    DEALLOCATE Consorcios;

    PRINT '>> Cocheras generadas exitosamente.';
END;
GO
-- ======================================================================================================
-- Rellenar tabla BAULERA
-- ======================================================================================================

CREATE OR ALTER PROCEDURE Operaciones.sp_RellenarBauleras
AS
BEGIN
    SET NOCOUNT ON;

    /*
        Rellena la tabla Consorcio.Baulera con datos derivados de UnidadFuncional.
        - Se crea 1 baulera por UF (si el consorcio aún no tiene bauleras).
        - Número incremental por consorcio.
        - Porcentaje de expensas = (m2 UF / total m2) * 0.5 para que represente menor peso.
    */

    DECLARE @idConsorcio INT, @maxNum INT;

    DECLARE Consorcios CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT consorcioId FROM Consorcio.UnidadFuncional;

    OPEN Consorcios;
    FETCH NEXT FROM Consorcios INTO @idConsorcio;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @totalM2 DECIMAL(18,2) = (
            SELECT SUM(ISNULL(metrosCuadrados,0))
            FROM Consorcio.UnidadFuncional
            WHERE consorcioId = @idConsorcio
        );

        SET @maxNum = ISNULL(
            (SELECT MAX(10) FROM Consorcio.Baulera b
             INNER JOIN Consorcio.UnidadFuncional uf ON uf.id = b.unidadFuncionalId
             WHERE uf.consorcioId = @idConsorcio),
        0);

        INSERT INTO Consorcio.Baulera (unidadFuncionalId, numero, porcentajeExpensas)
        SELECT 
            uf.id AS unidadFuncionalId,
            ROW_NUMBER() OVER (ORDER BY uf.id) + @maxNum AS numero,
            CASE WHEN @totalM2 > 0 THEN ROUND((uf.metrosCuadrados / @totalM2) * 100 * 0.5, 2) ELSE 0 END AS porcentajeExpensas
        FROM Consorcio.UnidadFuncional uf
        WHERE uf.consorcioId = @idConsorcio
          AND NOT EXISTS (
              SELECT 1 FROM Consorcio.Baulera b WHERE b.unidadFuncionalId = uf.id
          );

        FETCH NEXT FROM Consorcios INTO @idConsorcio;
    END

    CLOSE Consorcios;
    DEALLOCATE Consorcios;

    PRINT '>> Bauleras generadas exitosamente.';
END;
GO

-- ======================================================================================================
-- Rellenar tabla PAGO APLICADO
-- ======================================================================================================

CREATE OR ALTER PROCEDURE Operaciones.sp_AplicarPagosACuentas
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FilasAfectadas INT = 0;

    -- Insertar en Pago.PagoAplicado relacionando el pago con su detalle de expensa
    INSERT INTO Pago.PagoAplicado (
        idPago, 
        idDetalleExpensa, 
        importeAplicado
    )
    SELECT
        P.id AS idPago,
        DE.id AS idDetalleExpensa,
        P.importe AS importeAplicado
    FROM Pago.Pago AS P -- 1. Pagos realizados
    
    -- 2. Encontrar la Unidad Funcional (UF) dueña del CVU/CBU de origen del pago
    INNER JOIN Consorcio.UnidadFuncional AS UF 
        ON P.cbuCuentaOrigen = UF.CVU_CBU 
        
    -- 3. Encontrar el Detalle de Expensa (DE) correspondiente a esa UF
    INNER JOIN Negocio.DetalleExpensa AS DE
        ON DE.idUnidadFuncional = UF.id
        
    -- 4. Encontrar la Expensa (E) para verificar el período
    INNER JOIN Negocio.Expensa AS E
        ON DE.expensaId = E.id
    
    WHERE 
        -- LÓGICA DE APLICACIÓN DEL PERÍODO (Mes de Pago = Mes de Vencimiento de Expensa)
        -- Si el pago se hace en el mes M, se aplica a la expensa generada para el periodo M-1.
        E.fechaPeriodoAnio = 
            CASE 
                -- Si el pago se hace en enero, se aplica a la expensa de diciembre del año anterior.
                WHEN MONTH(P.fecha) = 1 THEN YEAR(P.fecha) - 1 
                ELSE YEAR(P.fecha)
            END
        AND 
        E.fechaPeriodoMes = 
            CASE 
                -- Si el pago se hace en enero (1), el mes del periodo de expensa es diciembre (12).
                WHEN MONTH(P.fecha) = 1 THEN 12 
                ELSE MONTH(P.fecha) - 1 -- Si es otro mes, se aplica al mes anterior.
            END
            
        -- GUARDRAIL: Solo aplica pagos que aún NO hayan sido registrados en PagoAplicado.
        AND NOT EXISTS (
            SELECT 1 
            FROM Pago.PagoAplicado AS PA 
            WHERE PA.idPago = P.id
        );

    SET @FilasAfectadas = @@ROWCOUNT;
    
    PRINT 'Aplicación de Pagos completada.';
    PRINT 'Total de nuevos pagos aplicados a DetalleExpensa: ' + CAST(@FilasAfectadas AS VARCHAR);

END
GO

-- ======================================================================================================
-- Rellenar GASTOS EXTRAORDINARIOS
-- ======================================================================================================

CREATE OR ALTER PROCEDURE Negocio.sp_CargarGastosExtraordinarios
AS
BEGIN
    SET NOCOUNT ON;
    PRINT N' Generando gastos extraordinarios...';

    DECLARE @i INT = 1;
    DECLARE @total INT = 20; -- cantidad de registros a generar
    DECLARE @consorcioId INT;
    DECLARE @detalle NVARCHAR(200);
    DECLARE @importeTotal DECIMAL(18,2);
    DECLARE @fechaEmision DATE;
    DECLARE @nombreEmpresaOPersona NVARCHAR(100);
    DECLARE @esPagoTotal BIT;
    DECLARE @nroCuota INT;
    DECLARE @totalCuota DECIMAL(18,2);
    DECLARE @nroFactura CHAR(10);
    DECLARE @idExpensa INT;

    WHILE @i <= @total
    BEGIN
        -- Elegimos un consorcio y expensa existente
        SET @consorcioId = (SELECT TOP 1 id FROM Consorcio.Consorcio ORDER BY NEWID());
        SET @idExpensa = (SELECT TOP 1 id FROM Negocio.Expensa ORDER BY NEWID());

        -- Descripciones aleatorias
        DECLARE @detalles TABLE (detalle NVARCHAR(200));
        INSERT INTO @detalles VALUES
            ('Reparación del ascensor'),
            ('Pintura general de fachada'),
            ('Cambio de portero eléctrico'),
            ('Impermeabilización de terraza'),
            ('Renovación del hall de entrada'),
            ('Reemplazo de cañerías de gas'),
            ('Instalación de cámaras de seguridad'),
            ('Reacondicionamiento de cocheras'),
            ('Colocación de luces LED en pasillos'),
            ('Modernización del tablero eléctrico');

        SET @detalle = (SELECT TOP 1 detalle FROM @detalles ORDER BY NEWID());

        -- Empresas aleatorias
        DECLARE @empresas TABLE (nombre NVARCHAR(100));
        INSERT INTO @empresas VALUES
            ('ObraFina S.A.'), ('ConstruRed SRL'), ('TecnoPortones'),
            ('AquaService'), ('ColorSur Pinturas'), ('SafeCam Systems'),
            ('ElectroRed S.A.'), ('GasSur SRL'), ('Impermeables S.A.'), ('Mantenimiento XXI');

        SET @nombreEmpresaOPersona = (SELECT TOP 1 nombre FROM @empresas ORDER BY NEWID());

        -- Datos aleatorios
        SET @importeTotal = (RAND(CHECKSUM(NEWID())) * 500000) + 50000;
        SET @fechaEmision = DATEADD(DAY, -ABS(CHECKSUM(NEWID()) % 180), GETDATE());
        SET @esPagoTotal = CASE WHEN RAND() > 0.5 THEN 1 ELSE 0 END;
        SET @nroCuota = CASE WHEN @esPagoTotal = 1 THEN NULL ELSE (ABS(CHECKSUM(NEWID()) % 5) + 1) END;
        SET @totalCuota = CASE WHEN @esPagoTotal = 1 THEN @importeTotal ELSE @importeTotal / ISNULL(@nroCuota, 1) END;
        SET @nroFactura = RIGHT('0000000000' + CAST(ABS(CHECKSUM(NEWID()) % 9999999999) AS VARCHAR(10)), 10);

        -- Insertar en GastoExtraordinario
        INSERT INTO Negocio.GastoExtraordinario
            (idExpensa, consorcioId, nroFactura, nombreEmpresaOPersona,
             fechaEmision, importeTotal, detalle, esPagoTotal, nroCuota, totalCuota)
        VALUES
            (@idExpensa, @consorcioId, @nroFactura, @nombreEmpresaOPersona,
             @fechaEmision, @importeTotal, @detalle, @esPagoTotal, @nroCuota, @totalCuota);

        SET @i += 1;
    END;

    PRINT N'Carga de gastos extraordinarios completada.';
END;
GO


/*
INSERT INTO Negocio.GastoExtraordinario
    (detalle, importeTotal, fechaEmision, nombreEmpresaoPersona, esPagoTotal, nroCuota, totalCuota)
VALUES
-- 🔹 AZCUENAGA (id 1)
('Reparación estructural del techo', 420000.00, '2024-04-12', 'ConstruRed SRL', 1, NULL, 0),
('Reacondicionamiento de tanque de agua', 165000.00, '2024-05-18', 'AquaService', 0, 1, 55000.00),

-- 🔹 ALZAGA (id 2)
('Colocación de portón automático',  380000.00, '2024-04-28', 'TecnoPortones', 1, NULL, 0),
('Refacción del sistema pluvial', 210000.00, '2024-06-10', 'ObrasPluviales SRL', 1, NULL, 0),

-- 🔹 ALBERDI (id 3)
('Pintura integral del edificio',  295000.00, '2024-04-25', 'ColorSur Pinturas', 1, NULL, 0),
('Ampliación del salón de usos múltiples',  520000.00, '2024-06-05', 'ObraFina S.A.', 1, 2, 4),

-- 🔹 UNZUE (id 4)
('Reemplazo de tablero eléctrico principal', 360000.00, '2024-04-30', 'ElectroRed S.A.', 1, NULL, 0),
('Reparación de filtraciones en cocheras',  240000.00, '2024-05-22', 'Impermeables S.A.', 0, 1, 40000.00),

-- 🔹 PEREYRA IRAOLA (id 5)
('Colocación de cámaras de seguridad IP',  310000.00, '2024-04-14', 'SafeCam Systems', 1, NULL, 0),
('Cambio de cañerías de gas en planta baja',  415000.00, '2024-06-10', 'GasSur SRL', 1, 2, 46111.11);
GO*/


-- =============================================
-- ====cambio en la tabla de aplicar pagos======
-- =============================================



/*
    Resumen de cambios: 
    Ahora los pagos tambien van a la tabla de detalles expnesa
    La varaible quedo pero no la use (REVISAR si hace falta solamente)

    No da errores pero no la use con datos (REVISAR)

	Si alguien lo prueba y funciona bien, que vea si todos los campos de DEtallExpensa
    tienen datos con un select * from Negocio.DetalleExpensa

*/


-- ======================================================================================================
-- Rellenar PAGO APLICADO
-- ======================================================================================================
CREATE OR ALTER PROCEDURE Operaciones.sp_AplicarPagosACuentas
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FilasAfectadas INT = 0;

    -- Insertar en Pago.PagoAplicado relacionando el pago con su detalle de expensa
    INSERT INTO Pago.PagoAplicado (
        idPago, 
        idDetalleExpensa, 
        importeAplicado
    )
    SELECT
        P.id AS idPago,
        DE.id AS idDetalleExpensa,
        P.importe AS importeAplicado
    FROM Pago.Pago AS P -- 1. Pagos realizados
    
    -- 2. Encontrar la Unidad Funcional (UF) dueña del CVU/CBU de origen del pago
    INNER JOIN Consorcio.UnidadFuncional AS UF 
        ON P.cbuCuentaOrigen = UF.CVU_CBU 
        
    -- 3. Encontrar el Detalle de Expensa (DE) correspondiente a esa UF
    INNER JOIN Negocio.DetalleExpensa AS DE
        ON DE.idUnidadFuncional = UF.id
        
    -- 4. Encontrar la Expensa (E) para verificar el período
    INNER JOIN Negocio.Expensa AS E
        ON DE.expensaId = E.id
    
    WHERE 
        -- LÓGICA DE APLICACIÓN DEL PERÍODO (Mes de Pago = Mes de Vencimiento de Expensa)
        -- Si el pago se hace en el mes M, se aplica a la expensa generada para el periodo M-1.
        E.fechaPeriodoAnio = 
            CASE 
                -- Si el pago se hace en enero, se aplica a la expensa de diciembre del año anterior.
                WHEN MONTH(P.fecha) = 1 THEN YEAR(P.fecha) - 1 
                ELSE YEAR(P.fecha)
            END
        AND 
        E.fechaPeriodoMes = 
            CASE 
                -- Si el pago se hace en enero (1), el mes del periodo de expensa es diciembre (12).
                WHEN MONTH(P.fecha) = 1 THEN 12 
                ELSE MONTH(P.fecha) - 1 -- Si es otro mes, se aplica al mes anterior.
            END
            
        -- GUARDRAIL: Solo aplica pagos que aún NO hayan sido registrados en PagoAplicado.
        AND NOT EXISTS (
            SELECT 1 
            FROM Pago.PagoAplicado AS PA 
            WHERE PA.idPago = P.id
        );

    SET @FilasAfectadas = @@ROWCOUNT;
    
    PRINT 'Aplicación de Pagos completada.';
    PRINT 'Total de nuevos pagos aplicados a DetalleExpensa: ' + CAST(@FilasAfectadas AS VARCHAR);

END
GO
-- CAmbiaria nombre a aplicarPagos solamente
/*CREATE OR ALTER PROCEDURE Operaciones.sp_AplicarPagosACuentas
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FilasAfectadas INT = 0;

    --  veo los pagos a aplicar y los guardao en tabla temporal
    SELECT
        P.id AS idPago,
        P.importe AS importeAplicado,
        DE.id AS idDetalleExpensa
    INTO #PagosAAplicar
    FROM Pago.Pago AS P

        -- Encontrar la Unidad Funcional (UF) dueña del CVU/CBU de origen del pago
        INNER JOIN Consorcio.UnidadFuncional AS UF
        ON P.cbuCuentaOrigen = UF.CVU_CBU

        -- Encontrar el Detalle de Expensa (DE) correspondiente a esa UF
        INNER JOIN Negocio.DetalleExpensa AS DE
        ON DE.idUnidadFuncional = UF.id

        -- Encontrar la Expensa (E) para verificar el período
        INNER JOIN Negocio.Expensa AS E
        ON DE.expensaId = E.id

    WHERE 
        -- LÓGICA DE APLICACIÓN DEL PERÍODO (Mes de Pago = Mes de Vencimiento de Expensa)
        -- Si el pago se hace en el mes M, se aplica a la expensa generada para el periodo M-1.
        E.fechaPeriodoAnio = 
            CASE 
                -- Si el pago se hace en enero, se aplica a la expensa de diciembre del año anterior.
                WHEN MONTH(P.fecha) = 1 THEN YEAR(P.fecha) - 1 
                ELSE YEAR(P.fecha)
            END
        AND
        E.fechaPeriodoMes = 
            CASE 
                -- Si el pago se hace en enero (1), el mes del periodo de expensa es diciembre (12).
                WHEN MONTH(P.fecha) = 1 THEN 12 
                ELSE MONTH(P.fecha) - 1 -- Si es otro mes, se aplica al mes anterior.
            END

        -- GUARDRAIL: Solo aplica pagos que aún NO hayan sido registrados en PagoAplicado.
        AND NOT EXISTS (
            SELECT 1
            FROM Pago.PagoAplicado AS PA
            WHERE PA.idPago = P.id
        );

    -- Insertar en Pago.PagoAplicado desde la tabla temporal
    INSERT INTO Pago.PagoAplicado (idPago, idDetalleExpensa, importeAplicado)
    SELECT
        idPago,
        idDetalleExpensa,
        importeAplicado
    FROM #PagosAAplicar;


    -- Actualizar pagosRecibidos en DetalleExpensa
    -- Agrupamos por si una UF hizo un par de pagos que aplican al mismo DetalleExpensa
    WITH SumaPagosPorDetalle AS
    (
        SELECT
            idDetalleExpensa,
            SUM(importeAplicado) AS MontoTotalPagado
        FROM #PagosAAplicar
        GROUP BY idDetalleExpensa
    )
    UPDATE DE
    SET DE.pagosRecibidos = ISNULL(DE.pagosRecibidos, 0) + SP.MontoTotalPagado
    FROM Negocio.DetalleExpensa AS DE
    INNER JOIN SumaPagosPorDetalle AS SP ON DE.id = SP.idDetalleExpensa;

    SET @FilasAfectadas = @@ROWCOUNT;

    -- Limpiar tabla temporal
    DROP TABLE IF EXISTS #PagosAAplicar;

END
GO
*/

/*GO*/

-- ======================================================================================================
-- Rellenar tabla CUENTA BANCARIA
-- ======================================================================================================
CREATE OR ALTER PROCEDURE Operaciones.SP_generadorCuentaBancaria
AS
BEGIN
    SET NOCOUNT ON;
	--Variable con cantidad de consorcios
		DECLARE @cantidadConsorcios INT = (SELECT COUNT(*)FROM Consorcio.Consorcio)
		DECLARE @i INT=1
    -- Tablas de datos de origen (sin cambios)
	DECLARE @Nombres TABLE (nombre VARCHAR(20));
    INSERT INTO @Nombres VALUES ('Juan'),('Maria'),('Carlos'),('Monica'),('Jorge'),
    ('Lucia'),('Sofia'),('Damian'),('Martina'),('Diego'), ('Barbara'),('Franco'),('Valentina'),('Nicolas'),('Camila');

    DECLARE @Apellidos TABLE (apellido VARCHAR(20));
    INSERT INTO @Apellidos VALUES ('Perez'),('Gomez'),('Rodriguez'),('Lopez'),('Fernandez'),
    ('Garcia'),('Martinez'),('Pereira'),('Romero'),('Torres'), ('Castro'),('Maciel'),('Lipchis'),('Ramos'),('Molina');

    -- Paso1 Crear una TABLA TEMPORAL para almacenar los datos generados y el mapeo (RN)
    IF OBJECT_ID('tempdb..#CuentasGeneradasTemp') IS NOT NULL DROP TABLE #CuentasGeneradasTemp;

    CREATE TABLE #CuentasGeneradasTemp (
		rn INT IDENTITY(1,1) PRIMARY KEY,
        CVU_CBU CHAR(22) NOT NULL,
        nombreTitular VARCHAR(50)NOT NULL,
        saldo DECIMAL(10, 2)
		)
		--Paso2: genero valores aleatorios y los inserto en la tabla temporal
WHILE @i <=@cantidadConsorcios
BEGIN
		INSERT INTO  #CuentasGeneradasTemp (CVU_CBU, nombreTitular, saldo)
		VALUES (
			--Genero CVU/CBU
			RIGHT('0000000000000000000000' + CAST(ABS(CHECKSUM(NEWID())) % 1000000000000000000000 AS VARCHAR(22)), 22),

			--Genero nombre aleatorio
			(SELECT TOP 1 n.nombre FROM @Nombres AS n ORDER BY NEWID()) + ' ' + 
            (SELECT TOP 1 a.apellido FROM @Apellidos AS a ORDER BY NEWID()),

			--Genero saldo aleatorio
			CAST(ROUND(((RAND(CHECKSUM(NEWID())) * 49000) + 1000), 2) AS DECIMAL(10,2))
	);
	
	SET @i += 1;
END
	
    -- PASO 3: Insertar las cuentas en la tabla permanente
    INSERT INTO Consorcio.CuentaBancaria (CVU_CBU, nombreTitular, saldo)
    SELECT 
        CVU_CBU, 
        nombreTitular, 
        saldo
    FROM #CuentasGeneradasTemp;

    
    -- PASO 4: Asignar el CVU_CBU al Consorcio correspondiente (AHORA FUNCIONA)
    -- Usamos la tabla temporal para hacer el JOIN seguro.
    UPDATE C
    SET C.CVU_CBU = T.CVU_CBU
    FROM Consorcio.Consorcio AS C
    INNER JOIN #CuentasGeneradasTemp AS T ON C.id = T.rn
    WHERE C.CVU_CBU IS NULL;
    
    DECLARE @filasAfectadas INT = @@ROWCOUNT;
    PRINT CONCAT('Se generaron y asignaron ', @filasAfectadas, ' Cuentas Bancarias a los Consorcios.');

    DROP TABLE #CuentasGeneradasTemp;

END
GO

-- =============================================
-- Generador de expensas
/*
    Lo pude probar con muy pocos datos y andaba, hay que volver
    a testear con todas las demas tablas cargadas.

    Deberia funcioar bien. para cuaquier Enero, para otros meses me tiro error
    porque no tenia datos de mesews anteriores.

    Si alguien lo prueba y funciona bien, que vea si todos los campos de expensa
    tienen datos con un select * from Negocio.Expensa

	Ver si se puede reemplazar la linea SET @NuevaExpensaID = SCOPE_IDENTITY();
	con algo mas normal y que sepamos
*/

-- ======================================================================================================
-- Rellenar tabla DETALLE EXPENSA
-- ======================================================================================================

CREATE OR ALTER PROCEDURE Negocio.SP_GenerarExpensasMensuales
    @ConsorcioID INT,
    @Anio INT,
    @Mes INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Variables para el nuevo encabezado de Expensa
    DECLARE @NuevaExpensaID INT;
    DECLARE @SaldoAnteriorConsorcio DECIMAL(18,2);
    DECLARE @TotalIngresosMes DECIMAL(18,2);
    DECLARE @TotalGastoOrd DECIMAL(18,2);
    DECLARE @TotalGastoExt DECIMAL(18,2);
    DECLARE @EgresosTotales DECIMAL(18,2);
    DECLARE @SaldoCierre DECIMAL(18,2);

    -- Variables para buscar el mes anterior
    DECLARE @FechaMesAnterior DATE = DATEADD(MONTH, -1, DATEFROMPARTS(@Anio, @Mes, 1));
    DECLARE @AnioAnterior INT = YEAR(@FechaMesAnterior);
    DECLARE @MesAnterior INT = MONTH(@FechaMesAnterior);

    BEGIN TRY
        -- Obtener saldo anterior del consorcio
        SELECT @SaldoAnteriorConsorcio = ISNULL(saldoCierre, 0)
        FROM Negocio.Expensa
        WHERE consorcioId = @ConsorcioID
          AND fechaPeriodoAnio = @AnioAnterior
          AND fechaPeriodoMes = @MesAnterior;

        -- Busco el total de ingresos del mes anterior
        SELECT @TotalIngresosMes = ISNULL(SUM(de.pagosRecibidos), 0)
        FROM Negocio.DetalleExpensa AS de
        INNER JOIN Negocio.Expensa AS e ON de.expensaId = e.id
        WHERE e.consorcioId = @ConsorcioID
          AND e.fechaPeriodoAnio = @AnioAnterior
          AND e.fechaPeriodoMes = @MesAnterior;

        -- Gastos Ordinarios
        SELECT @TotalGastoOrd = ISNULL(SUM(importeTotal), 0)
        FROM Negocio.GastoOrdinario
        WHERE IdExpensa IS NULL
          AND consorcioId = @ConsorcioID
          AND YEAR(fechaEmision) = @Anio
          AND MONTH(fechaEmision) = @Mes;
          
        -- Gastos Extraordinarios
        SELECT @TotalGastoExt = ISNULL(SUM(importeTotal), 0)
        FROM Negocio.GastoExtraordinario
        WHERE IdExpensa IS NULL
          AND consorcioId = @ConsorcioID
          AND YEAR(fechaEmision) = @Anio
          AND MONTH(fechaEmision) = @Mes;

        SET @EgresosTotales = @TotalGastoOrd + @TotalGastoExt;
        
        -- Saldo de Cierre
        SET @SaldoCierre = @SaldoAnteriorConsorcio + @TotalIngresosMes - @EgresosTotales;

        -- CREO LA EXPENSA
        INSERT INTO Negocio.Expensa 
            (consorcioId, fechaPeriodoAnio, fechaPeriodoMes, 
             saldoAnterior, ingresosEnTermino, egresos, saldoCierre)
        VALUES 
            (@ConsorcioID, @Anio, @Mes, 
             @SaldoAnteriorConsorcio, @TotalIngresosMes, @EgresosTotales, @SaldoCierre);
        
        SET @NuevaExpensaID = SCOPE_IDENTITY(); 

        -- Gastos pendientes apuntan a la nueva expensa
        UPDATE Negocio.GastoOrdinario
        SET IdExpensa = @NuevaExpensaID
        WHERE IdExpensa IS NULL
          AND consorcioId = @ConsorcioID
          AND YEAR(fechaEmision) = @Anio
          AND MONTH(fechaEmision) = @Mes;
        
        UPDATE Negocio.GastoExtraordinario
        SET IdExpensa = @NuevaExpensaID
        WHERE IdExpensa IS NULL
          AND consorcioId = @ConsorcioID
          AND YEAR(fechaEmision) = @Anio
          AND MONTH(fechaEmision) = @Mes;

        -- Crear detalle de expensas por unidad funcional
        WITH DeudaMesAnterior AS (
            SELECT
                de.idUnidadFuncional,
                (de.totalaPagar - ISNULL(de.pagosRecibidos, 0)) AS SaldoDeudor
            FROM Negocio.DetalleExpensa AS de
            INNER JOIN Negocio.Expensa AS e ON de.expensaId = e.id
            WHERE e.consorcioId = @ConsorcioID
              AND e.fechaPeriodoAnio = @AnioAnterior
              AND e.fechaPeriodoMes = @MesAnterior
        )
        
        INSERT INTO Negocio.DetalleExpensa 
            (expensaId, idUnidadFuncional, 
             prorrateoOrdinario, prorrateoExtraordinario, 
             saldoAnteriorAbonado,
             interesMora, 
             pagosRecibidos,
             totalaPagar)
        SELECT
            @NuevaExpensaID, -- El ID de la nueva expensa
            uf.id,           -- El ID de la unidad funcional
            
            -- Prorrateo Ordinario
            ISNULL((@TotalGastoOrd * (uf.porcentajeExpensas / 100)), 0),
            
            -- Prorrateo Extraordinario
            ISNULL((@TotalGastoExt * (uf.porcentajeExpensas / 100)), 0),

            -- Deuda 
            ISNULL(dma.SaldoDeudor, 0) AS DeudaAnterior,

            -- Interés por Mora
            CASE
                WHEN ISNULL(dma.SaldoDeudor, 0) > 0 THEN (ISNULL(dma.SaldoDeudor, 0) * 0.05) 
                ELSE 0
            END AS InteresMora,
            
            -- Pagos recibidos
            0.00,

            -- Total a Pagar
            ( 
              ISNULL((@TotalGastoOrd * (uf.porcentajeExpensas / 100)), 0) +   -- Gasto Ord
              ISNULL((@TotalGastoExt * (uf.porcentajeExpensas / 100)), 0) +   -- Gasto Ext
              ISNULL(dma.SaldoDeudor, 0) +                                    -- Deuda
              (CASE WHEN ISNULL(dma.SaldoDeudor, 0) > 0 THEN (ISNULL(dma.SaldoDeudor, 0) * 0.05) ELSE 0 END) -- Interés
            ) AS TotalPagar

        FROM Consorcio.UnidadFuncional AS uf
            LEFT JOIN DeudaMesAnterior AS dma ON uf.id = dma.idUnidadFuncional
        WHERE uf.consorcioId = @ConsorcioID;

        PRINT N'Expensas generadas correctamente para ' + CAST(@Anio AS VARCHAR(4)) + '-' + CAST(@Mes AS VARCHAR(2)) + ' (ID: ' + CAST(@NuevaExpensaID AS VARCHAR(10)) + ')';

    END TRY
    BEGIN CATCH
        PRINT N'Error al generar las expensas.';
    END CATCH
END
GO


/*


-- ESTO NO VA !!!!!!!!!!!!!!!


-- ======================================================================================================
-- Rellenar tabla PAGO ?
-- ======================================================================================================

CREATE OR ALTER PROCEDURE Operaciones.sp_GenerarPagosSimulados
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT N'Generando Pagos Simulados...';

    INSERT INTO Pago.Pago (fecha, importe, cbuCuentaOrigen, idFormaPago)
    SELECT 
        DATEADD(DAY, 
                5 + (ABS(CHECKSUM(NEWID())) % 6),
                DATEFROMPARTS(
                    CASE WHEN E.fechaPeriodoMes = 12 THEN E.fechaPeriodoAnio + 1 ELSE E.fechaPeriodoAnio END,
                    CASE WHEN E.fechaPeriodoMes = 12 THEN 1 ELSE E.fechaPeriodoMes + 1 END,
                    1
                )
        ) AS fecha,
        CAST(
            DE.totalaPagar * (0.70 + (ABS(CHECKSUM(NEWID())) % 31) / 100.0)
            AS DECIMAL(18,2)
        ) AS importe,
        UF.CVU_CBU AS cbuCuentaOrigen,
        1 + (ABS(CHECKSUM(NEWID())) % 3) AS idFormaPago
    FROM Negocio.DetalleExpensa DE
    INNER JOIN Consorcio.UnidadFuncional UF ON DE.idUnidadFuncional = UF.id
    INNER JOIN Negocio.Expensa E ON DE.expensaId = E.id
    WHERE 
        (ABS(CHECKSUM(NEWID())) % 100) < 80;

    PRINT ' Pagos simulados generados';
END
GO

CREATE OR ALTER PROCEDURE Operaciones.sp_CargaConsorciosSemilla
AS
BEGIN
    SET NOCOUNT ON;

    PRINT N'Insertando datos semilla de Consorcios...';

    DECLARE @cvu CHAR(22);
	--Consorcio 1: Azcuenaga
    IF NOT EXISTS (SELECT 1 FROM Consorcio.Consorcio WHERE nombre = 'Azcuenaga')
    BEGIN
        SET @cvu = RIGHT('00000000000000000000' + CAST(ABS(CHECKSUM(NEWID())) AS VARCHAR(20)), 22);
        IF NOT EXISTS (SELECT 1 FROM Consorcio.CuentaBancaria WHERE CVU_CBU = @cvu)
            INSERT INTO Consorcio.CuentaBancaria (CVU_CBU, nombreTitular, saldo)
            VALUES (@cvu, 'Consorcio Azcuenaga', 0);

        INSERT INTO Consorcio.Consorcio (nombre, direccion, CVU_CBU, metrosCuadradosTotal)
        VALUES ('Azcuenaga', 'Belgrano 3344', @cvu, 1281);
    END

    --  Consorcio 2: Alzaga
    IF NOT EXISTS (SELECT 1 FROM Consorcio.Consorcio WHERE nombre = 'Alzaga')
    BEGIN
        SET @cvu = RIGHT('00000000000000000000' + CAST(ABS(CHECKSUM(NEWID())) AS VARCHAR(20)), 22);
        IF NOT EXISTS (SELECT 1 FROM Consorcio.CuentaBancaria WHERE CVU_CBU = @cvu)
            INSERT INTO Consorcio.CuentaBancaria (CVU_CBU, nombreTitular, saldo)
            VALUES (@cvu, 'Consorcio Alzaga', 0);

        INSERT INTO Consorcio.Consorcio (nombre, direccion, CVU_CBU, metrosCuadradosTotal)
        VALUES ('Alzaga', 'Callao 1122', @cvu, 914);
    END

    --  Consorcio 3: Alberdi
    IF NOT EXISTS (SELECT 1 FROM Consorcio.Consorcio WHERE nombre = 'Alberdi')
    BEGIN
        SET @cvu = RIGHT('00000000000000000000' + CAST(ABS(CHECKSUM(NEWID())) AS VARCHAR(20)), 22);
        IF NOT EXISTS (SELECT 1 FROM Consorcio.CuentaBancaria WHERE CVU_CBU = @cvu)
            INSERT INTO Consorcio.CuentaBancaria (CVU_CBU, nombreTitular, saldo)
            VALUES (@cvu, 'Consorcio Alberdi', 0);

        INSERT INTO Consorcio.Consorcio (nombre, direccion, CVU_CBU, metrosCuadradosTotal)
        VALUES ('Alberdi', 'Santa Fe 910', @cvu, 784);
    END

    --  Consorcio 4: Unzue
    IF NOT EXISTS (SELECT 1 FROM Consorcio.Consorcio WHERE nombre = 'Unzue')
    BEGIN
        SET @cvu = RIGHT('00000000000000000000' + CAST(ABS(CHECKSUM(NEWID())) AS VARCHAR(20)), 22);
        IF NOT EXISTS (SELECT 1 FROM Consorcio.CuentaBancaria WHERE CVU_CBU = @cvu)
            INSERT INTO Consorcio.CuentaBancaria (CVU_CBU, nombreTitular, saldo)
            VALUES (@cvu, 'Consorcio Unzue', 0);

        INSERT INTO Consorcio.Consorcio (nombre, direccion, CVU_CBU, metrosCuadradosTotal)
        VALUES ('Unzue', 'Corrientes 5678', @cvu, 1316);
    END

    -- Consorcio 5: Pereyra Iraola
    IF NOT EXISTS (SELECT 1 FROM Consorcio.Consorcio WHERE nombre = 'Pereyra Iraola')
    BEGIN
        SET @cvu = RIGHT('00000000000000000000' + CAST(ABS(CHECKSUM(NEWID())) AS VARCHAR(20)), 22);
        IF NOT EXISTS (SELECT 1 FROM Consorcio.CuentaBancaria WHERE CVU_CBU = @cvu)
            INSERT INTO Consorcio.CuentaBancaria (CVU_CBU, nombreTitular, saldo)
            VALUES (@cvu, 'Consorcio Pereyra Iraola', 0);

        INSERT INTO Consorcio.Consorcio (nombre, direccion, CVU_CBU, metrosCuadradosTotal)
        VALUES ('Pereyra Iraola', 'Rivadavia 1234', @cvu, 1691);
    END

    PRINT N' Carga de datos semilla de Consorcios finalizada exitosamente.';
END
GO

--NUEVO---
CREATE OR ALTER PROCEDURE Operaciones.sp_CargarPersonasSemilla
AS
BEGIN
    SET NOCOUNT ON;

    PRINT N'Insertando personas semilla en Consorcio.Persona...';
    -- Listas base de nombres y apellidos
    DECLARE @Nombres TABLE (nombre NVARCHAR(30));
    INSERT INTO @Nombres VALUES 
        ('Juan'),('María'),('Carlos'),('Lucía'),('Sofía'),
        ('Nicolás'),('Valentina'),('Martín'),('Camila'),('Jorge'),
        ('Mónica'),('Diego'),('Laura'),('Andrea'),('Pablo');

    DECLARE @Apellidos TABLE (apellido NVARCHAR(30));
    INSERT INTO @Apellidos VALUES 
        ('Pérez'),('Gómez'),('Rodríguez'),('López'),('Fernández'),
        ('Martínez'),('Romero'),('Molina'),('Torres'),('Ramos'),
        ('García'),('Silva'),('Pereyra'),('Vega'),('Castro');

    -- Obtener los ID reales de los tipos de rol existentes

    DECLARE @idInquilino INT = (SELECT TOP 1 idTipoRol FROM Consorcio.TipoRol WHERE nombre = 'Inquilino');
    DECLARE @idPropietario INT = (SELECT TOP 1 idTipoRol FROM Consorcio.TipoRol WHERE nombre = 'Propietario');

    IF @idInquilino IS NULL OR @idPropietario IS NULL
    BEGIN
        PRINT 'Error: No se encontraron los tipos de rol. Ejecutá primero: EXEC Operaciones.CargaTiposRol;';
        RETURN;
    END

    -- Generación de 100 personas con datos aleatorios
    DECLARE @i INT = 1;
    DECLARE @nombre NVARCHAR(50);
    DECLARE @apellido NVARCHAR(50);
    DECLARE @cvu CHAR(22);
    DECLARE @rol INT;
    DECLARE @dni INT;
    DECLARE @email NVARCHAR(100);
    DECLARE @telefono NVARCHAR(20);

    WHILE @i <= 100
    BEGIN
        SELECT @nombre = (SELECT TOP 1 nombre FROM @Nombres ORDER BY NEWID());
        SELECT @apellido = (SELECT TOP 1 apellido FROM @Apellidos ORDER BY NEWID());
        SET @cvu = RIGHT('00000000000000000000' + CAST(ABS(CHECKSUM(NEWID())) AS VARCHAR(22)), 22);

        -- Alternar entre inquilino y propietario
        SET @rol = CASE WHEN @i % 2 = 0 THEN @idInquilino ELSE @idPropietario END;

        -- Generar un DNI aleatorio (20.000.000 a 45.000.000)
        SET @dni = 20000000 + ABS(CHECKSUM(NEWID())) % 25000000;

        -- Generar email y teléfono simulados
        SET @email = LOWER(@nombre + '.' + @apellido + CAST(@i AS NVARCHAR(3)) + '@mailprueba.com');
        SET @telefono = '11' + RIGHT('00000000' + CAST(ABS(CHECKSUM(NEWID())) % 100000000 AS VARCHAR(8)), 8);

        -- Insertar solo si el CVU no existe
        IF NOT EXISTS (SELECT 1 FROM Consorcio.Persona WHERE CVU_CBU = @cvu)
        BEGIN
            INSERT INTO Consorcio.Persona (dni, nombre, apellido, CVU_CBU, idTipoRol, email, telefono)
            VALUES (@dni, @nombre, @apellido, @cvu, @rol, @email, @telefono);
        END

        SET @i += 1;
    END

    PRINT N'Carga de personas semilla finalizada correctamente (100 personas con email y teléfono).';
END;
GO

CREATE OR ALTER PROCEDURE Operaciones.sp_CargaUnidadesFuncionalesSemilla
AS
BEGIN
    SET NOCOUNT ON;
    PRINT N'Insertando unidades funcionales aleatorias por consorcio...';
    
    -- Tabla temporal con tipos de unidad
    DECLARE @tipos TABLE (tipo VARCHAR(50));
    INSERT INTO @tipos (tipo)
    VALUES ('Departamento'), ('Dúplex'), ('Local'), ('Oficina'), ('Monoambiente');
    
    -- PASO 1: Insertar UFs con porcentajes temporales en NULL
    -- (Los calcularemos después basados en m2 reales)
    INSERT INTO Consorcio.UnidadFuncional
    (
        CVU_CBU, 
        consorcioId, 
        numero, 
        piso, 
        departamento,
        metrosCuadrados, 
        porcentajeExpensas, -- Temporalmente NULL
        tipo
    )
    SELECT 
        -- CVU aleatorio de la tabla Persona
        (SELECT TOP 1 CVU_CBU 
         FROM Consorcio.Persona 
         ORDER BY NEWID()) AS CVU_CBU,
        
        c.id AS consorcioId,
        
        -- Número de unidad (1 a 10)
        CAST(n.numero AS VARCHAR(10)) AS numero,
        
        -- Piso aleatorio (1 a 5)
        CAST(CEILING(RAND(CHECKSUM(NEWID()) + n.numero + c.id) * 5) AS VARCHAR(10)) AS piso,
        
        -- Departamento (A, B, C, etc.)
        CHAR(64 + n.numero) AS departamento,
        
        -- Metros cuadrados (40 a 100)
        CAST(40 + RAND(CHECKSUM(NEWID()) + n.numero * c.id) * 60 AS DECIMAL(10,2)) AS metrosCuadrados,
        
        -- Porcentaje se calculará después
        NULL AS porcentajeExpensas,
        
        -- Tipo aleatorio
        (SELECT TOP 1 tipo FROM @tipos ORDER BY NEWID()) AS tipo
        
    FROM 
        Consorcio.Consorcio c
    CROSS JOIN
        -- Generar números del 1 al 10
        (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10)) AS n(numero)
    WHERE NOT EXISTS (
        -- Evitar duplicados si se ejecuta múltiples veces
        SELECT 1 
        FROM Consorcio.UnidadFuncional uf 
        WHERE uf.consorcioId = c.id 
          AND uf.numero = CAST(n.numero AS VARCHAR(10))
    );
    
    DECLARE @totalInsertadas INT = @@ROWCOUNT;
    
    -- PASO 2: Calcular porcentajes normalizados basados en m2
    PRINT N'Calculando porcentajes proporcionales a los metros cuadrados...';
    
    UPDATE UF
    SET porcentajeExpensas = CAST(
        (UF.metrosCuadrados * 100.0) / TotalM2.TotalMetros 
        AS DECIMAL(5,2)
    )
    FROM Consorcio.UnidadFuncional AS UF
    INNER JOIN (
        SELECT 
            consorcioId,
            SUM(metrosCuadrados) AS TotalMetros
        FROM Consorcio.UnidadFuncional
        WHERE metrosCuadrados IS NOT NULL
        GROUP BY consorcioId
    ) AS TotalM2 ON UF.consorcioId = TotalM2.consorcioId
    WHERE UF.metrosCuadrados IS NOT NULL
      AND UF.porcentajeExpensas IS NULL; -- Solo las recién insertadas
    
    -- PASO 3: Ajustar redondeo para que sume EXACTAMENTE 100%
    -- (La última UF de cada consorcio absorbe la diferencia de redondeo)
    ;WITH UFOrdenada AS (
        SELECT 
            id,
            consorcioId,
            porcentajeExpensas,
            ROW_NUMBER() OVER (PARTITION BY consorcioId ORDER BY id DESC) AS rn
        FROM Consorcio.UnidadFuncional
    ),
    SumaActual AS (
        SELECT 
            consorcioId,
            SUM(porcentajeExpensas) AS SumaTotal
        FROM Consorcio.UnidadFuncional
        GROUP BY consorcioId
    )
    UPDATE UF
    SET porcentajeExpensas = UF.porcentajeExpensas + (100 - SA.SumaTotal)
    FROM Consorcio.UnidadFuncional AS UF
    INNER JOIN UFOrdenada AS UO ON UF.id = UO.id
    INNER JOIN SumaActual AS SA ON UF.consorcioId = SA.consorcioId
    WHERE UO.rn = 1 -- Solo la última UF de cada consorcio
      AND ABS(SA.SumaTotal - 100) > 0.01; -- Solo si hay diferencia
    
    -- Mensaje final
    PRINT 'Se cargaron unidades funcionales correctamente.';
    
END;
GO


CREATE OR ALTER PROCEDURE Operaciones.sp_GenerarGastosOrdinarios
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT N'Generando Gastos Ordinarios...';

    -- Tablas de datos semilla
    DECLARE @TiposServicio TABLE (tipo VARCHAR(50));
    INSERT INTO @TiposServicio VALUES 
        ('ADMINISTRACION'),
        ('BANCARIOS'),
        ('LIMPIEZA'),
        ('SEGUROS'),
        ('GASTOS GENERALES'),
        ('SERVICIOS PUBLICOS-Agua'),
        ('SERVICIOS PUBLICOS-Luz');

    DECLARE @Proveedores TABLE (nombre VARCHAR(200), tipoServicio VARCHAR(50));
    INSERT INTO @Proveedores VALUES
        ('Administración Central SRL', 'ADMINISTRACION'),
        ('Banco Galicia', 'BANCARIOS'),
        ('Banco Nación', 'BANCARIOS'),
        ('Limpieza Express SA', 'LIMPIEZA'),
        ('Clean Pro Servicios', 'LIMPIEZA'),
        ('Seguros Rivadavia', 'SEGUROS'),
        ('La Meridional Seguros', 'SEGUROS'),
        ('Ferretería El Progreso', 'GASTOS GENERALES'),
        ('Materiales San Martín', 'GASTOS GENERALES'),
        ('AYSA', 'SERVICIOS PUBLICOS-Agua'),
        ('EDENOR', 'SERVICIOS PUBLICOS-Luz');

    -- Variables
    DECLARE @ConsorcioID INT;
    DECLARE @Mes INT;
    DECLARE @Anio INT = 2024;
    DECLARE @TipoServicio VARCHAR(50);
    DECLARE @Proveedor VARCHAR(200);
    DECLARE @Importe DECIMAL(18,2);
    DECLARE @NroFactura CHAR(10);
    DECLARE @FechaEmision DATE;
    DECLARE @Detalle VARCHAR(500);

    -- Cursor por cada consorcio
    DECLARE ConsorciosCursor CURSOR FOR
        SELECT id FROM Consorcio.Consorcio;

    OPEN ConsorciosCursor;
    FETCH NEXT FROM ConsorciosCursor INTO @ConsorcioID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Para cada mes (Enero a Octubre)
        SET @Mes = 1;
        WHILE @Mes <= 10
        BEGIN
            -- Generar 1 gasto por cada tipo de servicio
            DECLARE TiposCursor CURSOR FOR
                SELECT tipo FROM @TiposServicio;
            
            OPEN TiposCursor;
            FETCH NEXT FROM TiposCursor INTO @TipoServicio;
            
            WHILE @@FETCH_STATUS = 0
            BEGIN
                -- Seleccionar proveedor aleatorio para ese tipo
                SELECT TOP 1 @Proveedor = nombre
                FROM @Proveedores
                WHERE tipoServicio = @TipoServicio
                ORDER BY NEWID();

                -- Generar importe aleatorio según tipo
                SET @Importe = CASE @TipoServicio
                    WHEN 'ADMINISTRACION' THEN 15000 + (RAND(CHECKSUM(NEWID())) * 10000)
                    WHEN 'BANCARIOS' THEN 2000 + (RAND(CHECKSUM(NEWID())) * 3000)
                    WHEN 'LIMPIEZA' THEN 20000 + (RAND(CHECKSUM(NEWID())) * 15000)
                    WHEN 'SEGUROS' THEN 8000 + (RAND(CHECKSUM(NEWID())) * 7000)
                    WHEN 'GASTOS GENERALES' THEN 5000 + (RAND(CHECKSUM(NEWID())) * 10000)
                    WHEN 'SERVICIOS PUBLICOS-Agua' THEN 12000 + (RAND(CHECKSUM(NEWID())) * 8000)
                    WHEN 'SERVICIOS PUBLICOS-Luz' THEN 18000 + (RAND(CHECKSUM(NEWID())) * 12000)
                    ELSE 5000
                END;

                -- Generar número de factura único (10 dígitos)
                SET @NroFactura = RIGHT('0000000000' + 
                    CAST(ABS(CHECKSUM(NEWID())) % 9999999999 AS VARCHAR(10)), 10);
                
                -- Verificar unicidad del nroFactura
                WHILE EXISTS (SELECT 1 FROM Negocio.GastoOrdinario WHERE nroFactura = @NroFactura)
                BEGIN
                    SET @NroFactura = RIGHT('0000000000' + 
                        CAST(ABS(CHECKSUM(NEWID())) % 9999999999 AS VARCHAR(10)), 10);
                END

                -- Fecha de emisión: entre el día 1 y 15 del mes
                SET @FechaEmision = DATEADD(DAY, 
                    ABS(CHECKSUM(NEWID())) % 15, 
                    DATEFROMPARTS(@Anio, @Mes, 1));

                -- Detalle genérico
                SET @Detalle = 'Servicio de ' + @TipoServicio + ' - Mes ' + 
                    CAST(@Mes AS VARCHAR(2)) + '/' + CAST(@Anio AS VARCHAR(4));

                -- Insertar el gasto
                INSERT INTO Negocio.GastoOrdinario 
                    (idExpensa, consorcioId, nombreEmpresaoPersona, nroFactura, 
                     fechaEmision, importeTotal, detalle, tipoServicio)
                VALUES 
                    (NULL, @ConsorcioID, @Proveedor, @NroFactura,
                     @FechaEmision, @Importe, @Detalle, @TipoServicio);

                FETCH NEXT FROM TiposCursor INTO @TipoServicio;
            END
            
            CLOSE TiposCursor;
            DEALLOCATE TiposCursor;
            
            SET @Mes = @Mes + 1;
        END
        
        FETCH NEXT FROM ConsorciosCursor INTO @ConsorcioID;
    END

    CLOSE ConsorciosCursor;
    DEALLOCATE ConsorciosCursor;

    DECLARE @TotalGenerados INT = @@ROWCOUNT;
    PRINT CONCAT('✓ ', @TotalGenerados, ' Gastos Ordinarios generados');
    PRINT '  (7 tipos × 10 meses × 5 consorcios = 350 gastos)';
END
GO

*/
