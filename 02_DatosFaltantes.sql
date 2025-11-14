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
Pastori, Ximena - 42300128
*/

USE [Com5600G11]; 
GO

--======================================================================================================
-- Rellenar tabla Gatos Ordinarios (gastos generales)
--======================================================================================================

CREATE OR ALTER PROCEDURE Operaciones.CargarGastosGeneralesOrdinarios
as
begin
    UPDATE GA
        SET
            GA.nombreEmpresaoPersona = ISNULL(GA.nombreEmpresaoPersona,
            CHOOSE(ABS(CHECKSUM(NEWID())) % 5 + 1,
                'Fumigadora La Rápida',
                'Iluminación LED S.A.',
                'Llaves Express',
                'Servicios de Mantenimiento Integral',
                'Piscinas del Sur'
            )),
        -- Asigna el detalle aleatorio
        GA.detalle = isnull(GA.detalle ,
            CHOOSE(ABS(CHECKSUM(NEWID())) % 6 + 1,
                'Reposición de lámparas LED',
                'Duplicado de llaves',
                'Fumigación mensual',
                'Mantenimiento de extinguidores',
                'Limpieza de tanque de agua',
                'Mantenimiento de jardines'
            ))
        FROM Negocio.GastoOrdinario GA
        WHERE UPPER(GA.tipoServicio) = 'GASTOS GENERALES'
        AND (NULLIF(LTRIM(RTRIM(GA.detalle)), '') IS NULL or NULLIF(LTRIM(RTRIM(GA.nombreEmpresaoPersona)), '') IS NULL );

end
go

--======================================================================================================
-- Rellenar tabla TIPO DE ROL
--======================================================================================================

CREATE OR ALTER PROCEDURE Operaciones.sp_CargaTiposRol
AS
BEGIN
    SET NOCOUNT ON;

    -- Inserta el tipo "Inquilino" si no existe
    IF NOT EXISTS (SELECT 1
    FROM Consorcio.TipoRol
    WHERE nombre = 'Inquilino')
    BEGIN
        INSERT INTO Consorcio.TipoRol
            (nombre, descripcion)
        VALUES
            ('Inquilino', 'Persona que alquila una unidad funcional dentro del consorcio.');
    END

    -- Inserta el tipo "Propietario" si no existe
    IF NOT EXISTS (SELECT 1
    FROM Consorcio.TipoRol
    WHERE nombre = 'Propietario')
    BEGIN
        INSERT INTO Consorcio.TipoRol
            (nombre, descripcion)
        VALUES
            ('Propietario', 'Dueño de una o más unidades funcionales dentro del consorcio.');
    END

    PRINT N'Carga de datos de Tipos de Rol finalizada.';
END
GO

IF OBJECT_ID('Operaciones.sp_CargaTiposRol', 'P') IS NOT NULL
PRINT 'Stored Procedure: Operaciones.sp_CargaTiposRol creado exitosamente'
GO

-- ======================================================================================================
-- Rellenar tabla FORMAS DE PAGO
-- ======================================================================================================

CREATE OR ALTER PROCEDURE Operaciones.sp_CrearYcargar_FormasDePago
AS
BEGIN

    PRINT N'Insertando/Verificando datos semilla en Pago.FormaDePago...';

    -- Transferencia Bancaria (mas comun para el CVU/CBU)
    IF NOT EXISTS (SELECT 1
    FROM Pago.FormaDePago
    WHERE descripcion = 'Transferencia Bancaria')
    BEGIN
        INSERT INTO Pago.FormaDePago
            (descripcion, confirmacion)
        VALUES
            ('Transferencia Bancaria', 'Comprobante');
    END

    -- Pago en Efectivo (si aplica en la administraci�n)
    IF NOT EXISTS (SELECT 1
    FROM Pago.FormaDePago
    WHERE descripcion = 'Efectivo en Oficina')
    BEGIN
        INSERT INTO Pago.FormaDePago
            (descripcion, confirmacion)
        VALUES
            ('Efectivo en Oficina', 'Recibo Manual');
    END

    -- Pago Electr�nico (Mercado Pago, otros)
    IF NOT EXISTS (SELECT 1
    FROM Pago.FormaDePago
    WHERE descripcion = 'Mercado Pago/Billetera')
    BEGIN
        INSERT INTO Pago.FormaDePago
            (descripcion, confirmacion)
        VALUES
            ('Mercado Pago/Billetera', 'ID de Transaccion');
    END

    PRINT N'Carga de datos de Formas de Pago finalizada.';

END
GO

IF OBJECT_ID('Operaciones.sp_CrearYcargar_FormasDePago', 'P') IS NOT NULL
PRINT 'Stored Procedure: Operaciones.sp_CrearYcargar_FormasDePago creado exitosamente'
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
        SELECT DISTINCT consorcioId
    FROM Consorcio.UnidadFuncional;

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
            (SELECT MAX(10)
        FROM Consorcio.Cochera c
            INNER JOIN Consorcio.UnidadFuncional uf ON uf.id = c.unidadFuncionalId
        WHERE uf.consorcioId = @idConsorcio),
        0);

        INSERT INTO Consorcio.Cochera
            (unidadFuncionalId, numero, porcentajeExpensas)
        SELECT
            uf.id AS unidadFuncionalId,
            ROW_NUMBER() OVER (ORDER BY uf.id) + @maxNum AS numero,
            CASE WHEN @totalM2 > 0 THEN ROUND((uf.metrosCuadrados / @totalM2) * 100, 2) ELSE 0 END AS porcentajeExpensas
        FROM Consorcio.UnidadFuncional uf
        WHERE uf.consorcioId = @idConsorcio
            AND NOT EXISTS (
              SELECT 1
            FROM Consorcio.Cochera c
            WHERE c.unidadFuncionalId = uf.id
          );

        FETCH NEXT FROM Consorcios INTO @idConsorcio;
    END

    CLOSE Consorcios;
    DEALLOCATE Consorcios;

    PRINT '>> Cocheras generadas exitosamente.';
END;
GO

IF OBJECT_ID('Operaciones.sp_RellenarCocheras', 'P') IS NOT NULL
PRINT 'Stored Procedure: Operaciones.sp_RellenarCocheras creado exitosamente'
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
        SELECT DISTINCT consorcioId
    FROM Consorcio.UnidadFuncional;

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
            (SELECT MAX(10)
        FROM Consorcio.Baulera b
            INNER JOIN Consorcio.UnidadFuncional uf ON uf.id = b.unidadFuncionalId
        WHERE uf.consorcioId = @idConsorcio),
        0);

        INSERT INTO Consorcio.Baulera
            (unidadFuncionalId, numero, porcentajeExpensas)
        SELECT
            uf.id AS unidadFuncionalId,
            ROW_NUMBER() OVER (ORDER BY uf.id) + @maxNum AS numero,
            CASE WHEN @totalM2 > 0 THEN ROUND((uf.metrosCuadrados / @totalM2) * 100 * 0.5, 2) ELSE 0 END AS porcentajeExpensas
        FROM Consorcio.UnidadFuncional uf
        WHERE uf.consorcioId = @idConsorcio
            AND NOT EXISTS (
              SELECT 1
            FROM Consorcio.Baulera b
            WHERE b.unidadFuncionalId = uf.id
          );

        FETCH NEXT FROM Consorcios INTO @idConsorcio;
    END

    CLOSE Consorcios;
    DEALLOCATE Consorcios;

    PRINT '>> Bauleras generadas exitosamente.';
END;
GO

IF OBJECT_ID('Operaciones.sp_RellenarBauleras', 'P') IS NOT NULL
PRINT 'Stored Procedure: Operaciones.sp_RellenarBauleras creado exitosamente'
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
    INSERT INTO Pago.PagoAplicado
        (
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

IF OBJECT_ID('Operaciones.sp_AplicarPagosACuentas', 'P') IS NOT NULL
PRINT 'Stored Procedure: Operaciones.sp_AplicarPagosACuentas creado exitosamente'
GO

-- ======================================================================================================
-- Rellenar GASTOS EXTRAORDINARIOS
-- ======================================================================================================

CREATE OR ALTER PROCEDURE Operaciones.sp_CargarGastosExtraordinarios
AS
BEGIN
    SET NOCOUNT ON;
    PRINT N' Generando gastos extraordinarios...';

    DECLARE @i INT = 1;
    DECLARE @total INT = 20;
    -- cantidad de registros a generar
    DECLARE @consorcioId INT;
    DECLARE @detalle NVARCHAR(200);
    DECLARE @importeTotal DECIMAL(18,2);
    DECLARE @fechaEmision DATE;
    DECLARE @nombreEmpresaOPersona NVARCHAR(100);
    DECLARE @esPagoTotal BIT;
    DECLARE @nroCuota INT;
    DECLARE @totalCuota DECIMAL(18,2);
    DECLARE @nroFactura CHAR(10);
    DECLARE @FechaInicio DATE = '2025-04-01';
    DECLARE @FechaFin DATE = '2025-07-01';
    DECLARE @TotalDias INT = DATEDIFF(DAY, @FechaInicio, @FechaFin);


    WHILE @i <= @total
    BEGIN
        -- Elegimos un consorcio y expensa existente
        SELECT TOP 1
            @consorcioId = c.id
        FROM
            Consorcio.Consorcio AS c
        ORDER BY 
                NEWID();

        -- Descripciones aleatorias
        DECLARE @detalles TABLE (detalle NVARCHAR(200));
        INSERT INTO @detalles
        VALUES
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

        SET @detalle = (SELECT TOP 1
            detalle
        FROM @detalles
        ORDER BY NEWID());

        -- Empresas aleatorias
        DECLARE @empresas TABLE (nombre NVARCHAR(100));
        INSERT INTO @empresas
        VALUES
            ('ObraFina S.A.'),
            ('ConstruRed SRL'),
            ('TecnoPortones'),
            ('AquaService'),
            ('ColorSur Pinturas'),
            ('SafeCam Systems'),
            ('ElectroRed S.A.'),
            ('GasSur SRL'),
            ('Impermeables S.A.'),
            ('Mantenimiento XXI');

        SET @nombreEmpresaOPersona = (SELECT TOP 1
            nombre
        FROM @empresas
        ORDER BY NEWID());

        -- Datos aleatorios
        SET @importeTotal = (RAND(CHECKSUM(NEWID())) * 500000) + 50000;
        SET @fechaEmision = DATEADD(DAY, (ABS(CHECKSUM(NEWID())) % @TotalDias), @FechaInicio);
        SET @esPagoTotal = CASE WHEN RAND() > 0.5 THEN 1 ELSE 0 END;
        SET @nroCuota = CASE WHEN @esPagoTotal = 1 THEN NULL ELSE (ABS(CHECKSUM(NEWID()) % 5) + 1) END;
        SET @totalCuota = CASE WHEN @esPagoTotal = 1 THEN @importeTotal ELSE @importeTotal / ISNULL(@nroCuota, 1) END;
        SET @nroFactura = RIGHT('0000000000' + CAST(ABS(CHECKSUM(NEWID()) % 9999999999) AS VARCHAR(10)), 10);

        -- Insertar en GastoExtraordinario
        INSERT INTO Negocio.GastoExtraordinario
            (consorcioId, nroFactura, nombreEmpresaOPersona,
            fechaEmision, importeTotal, detalle, esPagoTotal, nroCuota, totalCuota)
        VALUES
            (@consorcioId, @nroFactura, @nombreEmpresaOPersona,
                @fechaEmision, @importeTotal, @detalle, @esPagoTotal, @nroCuota, @totalCuota);

        SET @i += 1;
    END

    PRINT N'Carga de gastos extraordinarios completada.';
END
GO

IF OBJECT_ID('Operaciones.sp_CargarGastosExtraordinarios', 'P') IS NOT NULL
PRINT 'Stored Procedure: Operaciones.sp_CargarGastosExtraordinarios creado exitosamente'
GO

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
-- Rellenar tabla CUENTA BANCARIA
-- ======================================================================================================
CREATE OR ALTER PROCEDURE Operaciones.SP_generadorCuentaBancaria
AS
BEGIN
    SET NOCOUNT ON;
    --Variable con cantidad de consorcios
    DECLARE @cantidadConsorcios INT = (SELECT COUNT(*)
    FROM Consorcio.Consorcio)
    DECLARE @i INT=1
    -- Tablas de datos de origen (sin cambios)
    DECLARE @Nombres TABLE (nombre VARCHAR(20));
    INSERT INTO @Nombres
    VALUES
        ('Juan'),
        ('Maria'),
        ('Carlos'),
        ('Monica'),
        ('Jorge'),
        ('Lucia'),
        ('Sofia'),
        ('Damian'),
        ('Martina'),
        ('Diego'),
        ('Barbara'),
        ('Franco'),
        ('Valentina'),
        ('Nicolas'),
        ('Camila');

    DECLARE @Apellidos TABLE (apellido VARCHAR(20));
    INSERT INTO @Apellidos
    VALUES
        ('Perez'),
        ('Gomez'),
        ('Rodriguez'),
        ('Lopez'),
        ('Fernandez'),
        ('Garcia'),
        ('Martinez'),
        ('Pereira'),
        ('Romero'),
        ('Torres'),
        ('Castro'),
        ('Maciel'),
        ('Lipchis'),
        ('Ramos'),
        ('Molina');

    -- Paso1 Crear una TABLA TEMPORAL para almacenar los datos generados y el mapeo (RN)
    IF OBJECT_ID('tempdb..#CuentasGeneradasTemp') IS NOT NULL DROP TABLE #CuentasGeneradasTemp;

    CREATE TABLE #CuentasGeneradasTemp
    (
        rn INT IDENTITY(1,1) PRIMARY KEY,
        CVU_CBU CHAR(22) NOT NULL,
        nombreTitular VARCHAR(50)NOT NULL,
        saldo DECIMAL(10, 2)
    )
    --Paso2: genero valores aleatorios y los inserto en la tabla temporal
    WHILE @i <=@cantidadConsorcios
BEGIN
        INSERT INTO  #CuentasGeneradasTemp
            (CVU_CBU, nombreTitular, saldo)
        VALUES
            (
                --Genero CVU/CBU
                RIGHT('0000000000000000000000' + CAST(ABS(CHECKSUM(NEWID())) % 1000000000000000000000 AS VARCHAR(22)), 22),

                --Genero nombre aleatorio
                (SELECT TOP 1
                    n.nombre
                FROM @Nombres AS n
                ORDER BY NEWID()) + ' ' + 
            (SELECT TOP 1
                    a.apellido
                FROM @Apellidos AS a
                ORDER BY NEWID()),

                --Genero saldo aleatorio
                CAST(ROUND(((RAND(CHECKSUM(NEWID())) * 49000) + 1000), 2) AS DECIMAL(10,2))
	);

        SET @i += 1;
    END

    -- PASO 3: Insertar las cuentas en la tabla permanente
    INSERT INTO Consorcio.CuentaBancaria
        (CVU_CBU, nombreTitular, saldo)
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

IF OBJECT_ID('Operaciones.SP_generadorCuentaBancaria', 'P') IS NOT NULL
PRINT 'Stored Procedure: Operaciones.SP_generadorCuentaBancaria creado exitosamente'
GO

-- ======================================================================================================
-- Rellenar tabla EXPENSA
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

    DECLARE @CVUConsorcio CHAR(22);
    DECLARE @1erVencimiento DATE = DATEFROMPARTS(@Anio, @Mes, 10);
    DECLARE @2doVencimiento DATE = DATEFROMPARTS(@Anio, @Mes, 15);;
    DECLARE @InteresAnterior DECIMAL(18,2);
    DECLARE @IngresosAdeudados DECIMAL(18,2);
    DECLARE @IngresosAdelantados DECIMAL(18,2);

    BEGIN TRY

        INSERT INTO Negocio.Expensa
        (consorcioId,
        fechaPeriodoAnio,
        fechaPeriodoMes,
        saldoAnterior,
        ingresosEnTermino,
        egresos,
        saldoCierre)
    VALUES
        (@ConsorcioID, @Anio, @Mes,
            @SaldoAnteriorConsorcio, @TotalIngresosMes, @EgresosTotales, @SaldoCierre);
        
        SET @NuevaExpensaID = SCOPE_IDENTITY(); 

        -- Obtener CVu del consorcio

        SELECT @CVUConsorcio = [Consorcio].[CuentaBancaria].[CVU_CBU]
    FROM [Consorcio].[CuentaBancaria]
        JOIN [Consorcio].[Consorcio]
        ON Consorcio.CuentaBancaria.CVU_CBU = Consorcio.Consorcio.CVU_CBU
    WHERE Consorcio.Consorcio.[id] = @ConsorcioID;

        -- Obtener saldo anterior del consorcio
        -- LO SACO DE LA CUENTA BANCARIA

        SELECT @SaldoAnteriorConsorcio = ISNULL([saldo], 0)
    FROM [Consorcio].[CuentaBancaria]
    WHERE [CVU_CBU] = @CVUConsorcio

        -- Busco Interes Anterior
        SELECT @InteresAnterior = ISNULL(SUM([interesMora]), 0)
    FROM [Negocio].[DetalleExpensa]
    WHERE [expensaId] = @NuevaExpensaID


        -- Busco el total de ingresos del mes 
        SELECT @TotalIngresosMes = ISNULL(SUM(Pago.importe), 0)
    FROM Pago.Pago
        JOIN Consorcio.UnidadFuncional AS UF
        ON Pago.cbuCuentaOrigen = UF.CVU_CBU
    WHERE UF.consorcioId = @ConsorcioID
        AND YEAR(Pago.fecha) = @Anio
        AND MONTH(Pago.fecha) = @Mes;

        ------------------------------------
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
        SET @SaldoCierre =  @SaldoAnteriorConsorcio + @TotalIngresosMes - @EgresosTotales;

        SELECT @IngresosAdeudados = ISNULL(SUM([importe]),0)
    FROM [Pago].[Pago]
        JOIN Consorcio.UnidadFuncional AS UF
        ON Pago.cbuCuentaOrigen = UF.CVU_CBU
    WHERE UF.consorcioId = @ConsorcioID
        AND YEAR(Pago.fecha) = YEAR(@1erVencimiento)
        AND MONTH(Pago.fecha) = MONTH(@1erVencimiento)
        AND DAY(Pago.fecha) >= DAY(@1erVencimiento);

        SELECT @IngresosAdelantados = ISNULL(SUM([importe]),0)
    FROM [Pago].[Pago]
        JOIN Consorcio.UnidadFuncional AS UF
        ON Pago.cbuCuentaOrigen = UF.CVU_CBU
    WHERE UF.consorcioId = @ConsorcioID
        AND YEAR(Pago.fecha) = YEAR(@2doVencimiento)
        AND MONTH(Pago.fecha) = MONTH(DATEADD(MONTH, -1, @2doVencimiento))
        AND DAY(Pago.fecha) > DAY(@2doVencimiento);

        -- ACTUALIZO LA EXPENSA
        UPDATE Negocio.Expensa
        SET
        fechaPeriodoAnio = @Anio,
        fechaPeriodoMes = @Mes,
        saldoAnterior = @SaldoAnteriorConsorcio,
        ingresosEnTermino = @TotalIngresosMes,
        egresos = @EgresosTotales,
        saldoCierre = @SaldoCierre,
        ingresosAdeudados = @IngresosAdeudados,
        ingresosAdelantados = @IngresosAdelantados
        WHERE [id] = @NuevaExpensaID

        
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

        UPDATE [Consorcio].[CuentaBancaria]
        SET [saldo] = @SaldoCierre
        WHERE [CVU_CBU] = @CVUConsorcio;



        -- Crear detalle de expensas por unidad funcional

        WITH
        DeudaMesAnterior
        AS
        (
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
        totalaPagar,
        primerVencimiento,
        segundoVencimiento)
    SELECT
        @NuevaExpensaID, -- El ID de la nueva expensa
        uf.id, -- El ID de la unidad funcional

        -- Prorrateo Ordinario
        ISNULL((@TotalGastoOrd * (uf.porcentajeExpensas / 100)), 0),

        -- Prorrateo Extraordinario
        ISNULL((@TotalGastoExt * (uf.porcentajeExpensas / 100)), 0),

        -- Saldo anterior abonado 
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
            ) AS TotalPagar,

        @1erVencimiento,
        @2doVencimiento

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




-- Tienen que haberse generado las expensas y aplicarlos pagos antes de correr este SP (En ese orden)
CREATE OR ALTER PROCEDURE Operaciones.ActualizarDetalleExpensa
    @expensaId INT,
    @mail BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @expensaAnterior INT = @expensaId -1;

        -- 1. Actualizar saldoAnteriorAbonado con el pagoRecibido de la expensa anterior
            WITH
        ExpensaAnterior
        AS
        (
            SELECT
                de.idUnidadFuncional,
                de.expensaId,
                de.pagosRecibidos
            FROM Negocio.DetalleExpensa de
            WHERE de.expensaId = @expensaAnterior
        )

        UPDATE de_actual
        SET saldoAnteriorAbonado = ISNULL(ea.pagosRecibidos, 0)
        FROM Negocio.DetalleExpensa de_actual
        JOIN ExpensaAnterior ea on ea.expensaId + 1 = de_actual.expensaId
        WHERE de_actual.expensaId = @expensaId
        AND ea.expensaId = @expensaAnterior
        AND ea.idUnidadFuncional = de_actual.idUnidadFuncional;

        -- 2. Calcular pagosRecibidos por unidad funcional y expensa

        WITH
        PagosAgrupados
        AS
        (
            SELECT
                uf.id AS idUnidadFuncional,
                de.id AS idDetalleExpensa,
                de.expensaId,
                SUM(pa.importeAplicado) AS totalPagos
            FROM Pago.PagoAplicado pa
                INNER JOIN Negocio.DetalleExpensa de ON pa.idDetalleExpensa = de.id
                INNER JOIN Consorcio.UnidadFuncional uf ON de.idUnidadFuncional = uf.id
                INNER JOIN Consorcio.Consorcio c ON uf.consorcioId = c.id
                JOIN Pago.Pago p ON p.id = pa.idPago
            WHERE de.expensaId = @expensaId
            GROUP BY uf.id, de.id, de.expensaId
        )
        UPDATE de
        SET pagosRecibidos = ISNULL(pa.totalPagos, 0)
        FROM Negocio.DetalleExpensa de
        JOIN PagosAgrupados pa ON pa.expensaId = de.expensaId
        WHERE de.id = pa.idDetalleExpensa;


        -- 3. Calcular interés por mora basado en fecha de pago

        WITH
        PrimerPagoPorDetalle
        AS
        (
            SELECT
                pa.idDetalleExpensa,
                MIN(p.fecha) as primeraFechaPago
            FROM Pago.PagoAplicado pa
                INNER JOIN Pago.Pago p ON pa.idPago = p.id
                INNER JOIN Negocio.DetalleExpensa de ON pa.idDetalleExpensa = de.id
                INNER JOIN Negocio.Expensa e ON de.expensaId = e.id
            WHERE e.id = expensaId
            GROUP BY pa.idDetalleExpensa
        )
        UPDATE de
        SET interesMora = 
            CASE 
                WHEN pp.primeraFechaPago > de.segundoVencimiento THEN
                    (de.totalaPagar - de.saldoAnteriorAbonado) * 0.05  -- 5% después del 2do vto
                WHEN pp.primeraFechaPago > de.primerVencimiento AND pp.primeraFechaPago <= de.segundoVencimiento THEN
                    (de.totalaPagar - de.saldoAnteriorAbonado) * 0.02  -- 2% entre 1er y 2do vto
                ELSE 0  -- Sin interés si paga antes del 1er vencimiento
            END
        FROM Negocio.DetalleExpensa de
        INNER JOIN Negocio.Expensa e ON de.expensaId = e.id
        LEFT JOIN PrimerPagoPorDetalle pp ON de.id = pp.idDetalleExpensa
        WHERE de.expensaId = @expensaId
        AND pp.primeraFechaPago IS NOT NULL;  -- Solo donde hay pagos

        -- 4. Si no hay pagos, interés mora = 0
        UPDATE de
        SET interesMora = 0
        FROM Negocio.DetalleExpensa de
        INNER JOIN Negocio.Expensa e ON de.expensaId = e.id
        WHERE de.expensaId = @expensaId
        AND interesMora IS NULL;

        IF @mail = 1
        BEGIN
        EXEC Negocio.SP_EnviarMailPorExpensa @expensaId
    END

        COMMIT TRANSACTION;

        PRINT 'Actualización completada exitosamente para la exepensa: ' + CAST(@expensaId AS VARCHAR);
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        DECLARE @ErrorMessage VARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO



-- SP para automatizar la generación de expensas mensuales en lote
-- Genera las expensas, aplica los pagos y actualiza los detalles de expensa (en ese orden)
CREATE OR ALTER PROCEDURE Negocio.SP_GenerarLoteDeExpensas
AS
BEGIN
    SET NOCOUNT ON;

    -- --- Parámetros del Lote ---
    DECLARE @ConsorcioDesde INT = 1;
    DECLARE @ConsorcioHasta INT = 5;

    DECLARE @MesDesde INT = 3;
    DECLARE @MesHasta INT = 6;

    DECLARE @AnioFijo INT = 2025;
    -- ---------------------------

    DECLARE @ConsorcioActual INT = @ConsorcioDesde;
    DECLARE @MesActual INT;
    DECLARE @ContadorExpensas INT = 1;

    PRINT 'Iniciando la generación en lote de expensas...';
    PRINT '-----------------------------------------------';

    -- Loop 1: Itera por cada Consorcio
    WHILE @ConsorcioActual <= @ConsorcioHasta
    BEGIN

        -- Resetea el contador de mes para cada consorcio
        SET @MesActual = @MesDesde;

        -- Loop 2: Itera por cada Mes
        WHILE @MesActual <= @MesHasta
        BEGIN

            PRINT 'Ejecutando: Consorcio ' + CAST(@ConsorcioActual AS VARCHAR) + 
                  ', Período: ' + CAST(@AnioFijo AS VARCHAR) + '-' + FORMAT(@MesActual, '00');

            -- Ejecuta el SP principal con los valores actuales del loop
            EXEC Negocio.SP_GenerarExpensasMensuales 
                @ConsorcioID = @ConsorcioActual, 
                @Anio = @AnioFijo, 
                @Mes = @MesActual;

            EXEC Operaciones.sp_AplicarPagosACuentas

            EXEC Operaciones.ActualizarDetalleExpensa @ContadorExpensas

            -- Incrementa el mes
            SET @MesActual = @MesActual + 1;
            SET @ContadorExpensas = @ContadorExpensas + 1
        END

        PRINT '--- Consorcio ' + CAST(@ConsorcioActual AS VARCHAR) + ' completado ---';

        -- Incrementa el consorcio
        SET @ConsorcioActual = @ConsorcioActual + 1;
    END

    PRINT '-----------------------------------------------';
    PRINT 'Generación en lote finalizada.';

END
GO

CREATE OR ALTER PROCEDURE Negocio.SP_EnviarMailPorExpensa
    @expensaId INT
AS
BEGIN

    DECLARE @indice INT = 1;
    DECLARE @filasTot INT;

    DECLARE @detallesXexpensa TABLE(
        ID INT IDENTITY (1,1),
        email VARCHAR(150),
        nombre VARCHAR(100),
        apellido VARCHAR(100),
        mes INT,
        anio INT,
        departamento VARCHAR(10),
        consorcio VARCHAR(100),
        vencimiento1 DATE,
        vencimiento2 DATE,
        totalAPagar DECIMAL(10,2),
        InteresMora DECIMAL(10,2),
        SaldoAnteriorAbonado DECIMAL(10,2),
        PagosRecibidos DECIMAL(10,2)
    )

    INSERT INTO @detallesXexpensa
        (
        email,
        nombre,
        apellido,
        mes,
        anio,
        departamento,
        consorcio,
        vencimiento1,
        vencimiento2,
        totalAPagar,
        InteresMora,
        SaldoAnteriorAbonado,
        PagosRecibidos)
    SELECT p.email, p.nombre, p.apellido, e.fechaPeriodoMes, e.fechaPeriodoAnio, uf.departamento,
        c.nombre, de.primerVencimiento, de.segundoVencimiento, de.totalaPagar, de.interesMora,
        de.saldoAnteriorAbonado, de.pagosRecibidos
    FROM [Negocio].[DetalleExpensa] de
        INNER JOIN Negocio.Expensa e on e.id = de.expensaId
        INNER JOIN Consorcio.Consorcio c on c.id = e.consorcioId
        INNER JOIN Consorcio.UnidadFuncional uf on uf.id = de.idUnidadFuncional
        INNER JOIN Consorcio.Persona p on p.CVU_CBU = uf.CVU_CBU
    WHERE de.[expensaId] = @expensaId


    select @filasTot = count(*)
    from @detallesXexpensa

    DECLARE
        @email VARCHAR(150),
        @nombre VARCHAR(100),
        @apellido VARCHAR(100),
        @mes INT,
        @anio INT,
        @departamento VARCHAR(10),
        @consorcio VARCHAR(100),
        @vencimiento1 DATE,
        @vencimiento2 DATE,
        @totalAPagar DECIMAL(10,2),
        @InteresMora DECIMAL(10,2),
        @SaldoAnteriorAbonado DECIMAL(10,2),
        @PagosRecibidos DECIMAL(10,2)

    SELECT
        @email = dx.email,
        @nombre = dx.nombre,
        @apellido = dx.apellido,
        @mes = dx.mes,
        @anio = dx.anio,
        @departamento = dx.departamento,
        @consorcio = dx.consorcio,
        @vencimiento1 = dx.vencimiento1,
        @vencimiento2 = dx.vencimiento2,
        @totalAPagar = dx.totalAPagar,
        @InteresMora = dx.InteresMora,
        @SaldoAnteriorAbonado = dx.SaldoAnteriorAbonado,
        @PagosRecibidos = dx.PagosRecibidos
    FROM @detallesXexpensa dx
    WHERE dx.ID = @indice



    DECLARE 
        @url VARCHAR(256) = N'https://api.sendgrid.com/v3/mail/send',
        @API_KEY VARCHAR(400) = N'API_KEY_AQUI',
        @AuthorizationHeader VARCHAR(512),
        @REMITENTE_EMAIL VARCHAR(100) = N'msquispeuni@gmail.com',
        @REMITENTE_NOMBRE VARCHAR(100) = N'Sistemas de Expensas',
        @ASUNTO VARCHAR(200) = N'Expensa Mensual',
        @CUERPO_HTML VARCHAR(MAX) =  N'<h1>Estimado/a ' + @apellido + ' ' + @nombre + ',</h1><p>Le informamos el detalle de su expensa...</p><h2>DETALLE DE SU EXPENSA:</h2><ul><li>Período: ' + CAST(@mes AS VARCHAR(2)) + '/' + CAST(@anio AS VARCHAR(4)) + '</li><li>Unidad Funcional: ' + @departamento + 'Consorcio: ' + @consorcio + '</li><li>Saldo Anterior Abonado: $' + CAST(@SaldoAnteriorAbonado AS VARCHAR(12)) + '</li><li>Total a Pagar: <b>$' + CAST(@totalAPagar AS VARCHAR(12)) + '</b></li><li>Interés por Mora: $' + CAST(@InteresMora AS VARCHAR(12))  +'</li></li></ul><h2>FECHAS DE VENCIMIENTO:</h2><ul><li>1er Vencimiento: ' + CONVERT(VARCHAR(10), @vencimiento1, 103) + ' - Sin recargo</li><li>2do Vencimiento: ' + CONVERT(VARCHAR(10), @vencimiento2, 103) + ' - Con 2% de recargo</li><li>Posterior al 2do Vto: 5% de recargo</li></ul><p><b> IMPORTANTE:</b></p><ul><li>Los pagos posteriores al 1er vencimiento generarán intereses según lo establecido en el reglamento.</li><li>Ante cualquier duda, contáctenos dentro de los 5 días hábiles.</li><li>Para mas información haga clic <a href="https://homers-webpage.vercel.app">aquí</a>.</li></ul><p>Atentamente,</p><p><b>Administración del Consorcio</b></p>'

    -- CONSTRUCCIÓN DEL JSON
    DECLARE @SAFE_CUERPO_HTML VARCHAR(MAX) = REPLACE(@CUERPO_HTML, '"', '\"');

    DECLARE @PAYLOAD VARCHAR(MAX) = 
        N'{
          "personalizations": [{
            "to": [{"email": "' + @email + N'"}],
            "subject": "' + @ASUNTO + N'"
          }],
          "from": {
            "email": "' + @REMITENTE_EMAIL + N'",
            "name": "' + @REMITENTE_NOMBRE + N'"
          },
          "content": [{
            "type": "text/html",
            "value": "' + @SAFE_CUERPO_HTML + N'"
          }]
        }';

    PRINT N'===== JSON A ENVIAR =====';
    PRINT @PAYLOAD;


    -- LLAMADA A LA API SENDGRID
    DECLARE 
        @Object INT,
        @Status INT,
        @StatusText VARCHAR(200),
        @ResponseText VARCHAR(MAX);


    WHILE @indice <= @filasTot
     BEGIN


        SET @AuthorizationHeader = N'Bearer ' + @API_KEY;

        EXEC sp_OACreate 'MSXML2.XMLHTTP', @Object OUT;

        EXEC sp_OAMethod @Object, 'open', NULL, 'POST', @url, 'false';
        EXEC sp_OAMethod @Object, 'setRequestHeader', NULL, 'Authorization', @AuthorizationHeader;
        EXEC sp_OAMethod @Object, 'setRequestHeader', NULL, 'Content-Type', 'application/json';

        -- Enviar el cuerpo JSON
        EXEC sp_OAMethod @Object, 'send', NULL, @PAYLOAD;

        -- Obtener código de estado y texto
        EXEC sp_OAGetProperty @Object, 'status', @Status OUT;
        EXEC sp_OAGetProperty @Object, 'statusText', @StatusText OUT;
        EXEC sp_OAGetProperty @Object, 'responseText', @ResponseText OUT;

        -- Destruir objeto
        EXEC sp_OADestroy @Object;

        -- RESULTADOS
        PRINT N'===== RESPUESTA DE LA API =====';
        PRINT N'Código HTTP: ' + CAST(@Status AS VARCHAR(10));
        PRINT N'StatusText: ' + ISNULL(@StatusText, N'(sin texto)');
        PRINT N'ResponseText: ' + ISNULL(@ResponseText, N'(vacío)');

        -- Mostrar resultado legible
        SELECT
            Codigo_HTTP = @Status,
            Estado = @StatusText,
            Respuesta = @ResponseText;


        -- INTERPRETACIÓN DEL RESULTADO

        IF @Status = 202
                PRINT N'ÉXITO: El correo fue aceptado por SendGrid.';
            ELSE
                PRINT N'ERROR: La API devolvió un código distinto de 202. Revisá la respuesta.';


        SELECT
            @email = dx.email,
            @nombre = dx.nombre,
            @apellido = dx.apellido,
            @mes = dx.mes,
            @anio = dx.anio,
            @departamento = dx.departamento,
            @consorcio = dx.consorcio,
            @vencimiento1 = dx.vencimiento1,
            @vencimiento2 = dx.vencimiento2,
            @totalAPagar = dx.totalAPagar,
            @InteresMora = dx.InteresMora,
            @SaldoAnteriorAbonado = dx.SaldoAnteriorAbonado,
            @PagosRecibidos = dx.PagosRecibidos
        FROM @detallesXexpensa dx
        WHERE dx.ID = @indice

        SET 
        @CUERPO_HTML  =  N'<h1>Estimado/a ' + @apellido + ' ' + @nombre + ',</h1><p>Le informamos el detalle de su expensa...</p><h2>DETALLE DE SU EXPENSA:</h2><ul><li>Período: ' + CAST(@mes AS VARCHAR(2)) + '/' + CAST(@anio AS VARCHAR(4)) + '</li><li>Unidad Funcional: ' + @departamento + 'Consorcio: ' + @consorcio + '</li><li>Saldo Anterior Abonado: $' + CAST(@SaldoAnteriorAbonado AS VARCHAR(12)) + '</li><li>Total a Pagar: <b>$' + CAST(@totalAPagar AS VARCHAR(12)) + '</b></li><li>Interés por Mora: $' + CAST(@InteresMora AS VARCHAR(12))  +'</li></li></ul><h2>FECHAS DE VENCIMIENTO:</h2><ul><li>1er Vencimiento: ' + CONVERT(VARCHAR(10), @vencimiento1, 103) + ' - Sin recargo</li><li>2do Vencimiento: ' + CONVERT(VARCHAR(10), @vencimiento2, 103) + ' - Con 2% de recargo</li><li>Posterior al 2do Vto: 5% de recargo</li></ul><p><b> IMPORTANTE:</b></p><ul><li>Los pagos posteriores al 1er vencimiento generarán intereses según lo establecido en el reglamento.</li><li>Ante cualquier duda, contáctenos dentro de los 5 días hábiles.</li><li>Para mas información haga clic <a href="https://homers-webpage.vercel.app">aquí</a>.</li></ul><p>Atentamente,</p><p><b>Administración del Consorcio</b></p>'

        -- CONSTRUCCIÓN DEL JSON
        SET @SAFE_CUERPO_HTML = REPLACE(@CUERPO_HTML, '"', '\"');

        SET @PAYLOAD = 
    N'{
      "personalizations": [{
        "to": [{"email": "' + @email + N'"}],
        "subject": "' + @ASUNTO + N'"
      }],
      "from": {
        "email": "' + @REMITENTE_EMAIL + N'",
        "name": "' + @REMITENTE_NOMBRE + N'"
      },
      "content": [{
        "type": "text/html",
        "value": "' + @SAFE_CUERPO_HTML + N'"
      }]
    }';

        PRINT N'===== JSON A ENVIAR =====';
        PRINT @PAYLOAD;


        SET @indice = @indice + 1;
    END

END
GO
