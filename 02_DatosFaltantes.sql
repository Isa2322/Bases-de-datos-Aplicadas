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

-- TIPO DE ROL

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


-- FORMAS DE PAGO

IF OBJECT_ID('SP_CrearYcargar_FormasDePago_Semilla', 'P') IS NOT NULL
    DROP PROCEDURE SP_CrearYcargar_FormasDePago_Semilla
GO

CREATE PROCEDURE SP_CrearYcargar_FormasDePago_Semilla
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


-- ============================================================================
--Rellenar tabla COCHERA
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
-- ============================================================================
--Rellenar tabla BAULERA
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

-- PAGO APLICADO

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

-- =============================================
-- ====cambio en la tabla de aplicar pagos======
-- =============================================

/*

/*
    Resumen de cambios: 
    Ahora los pagos tambien van a la tabla de detalles expnesa
    La varaible quedo pero no la use (REVISAR si hace falta solamente)

    No da errores pero no la use con datos (REVISAR)

	Si alguien lo prueba y funciona bien, que vea si todos los campos de DEtallExpensa
    tienen datos con un select * from Negocio.DetalleExpensa

*/

-- CAmbiaria nombre a aplicarPagos solamente
CREATE OR ALTER PROCEDURE Operaciones.sp_AplicarPagosACuentas
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

--Rellena tabla CuentaBancaria
CREATE OR ALTER PROCEDURE SP_generadorCuentaBancaria
AS
BEGIN

DECLARE @i INT = 1

--Maximo de valores generados
DECLARE @maxi INT = 4 

-- Listas de nombres y apellidos para combinar
DECLARE @Nombres TABLE (nombre VARCHAR(20));
INSERT INTO @Nombres VALUES
('Juan'),('Maria'),('Carlos'),('Monica'),('Jorge'),
('Lucia'),('Sofia'),('Damian'),('Martina'),('Diego'),
('Barbara'),('Franco'),('Valentina'),('Nicolas'),('Camila')

DECLARE @Apellidos TABLE (apellido VARCHAR(20));
INSERT INTO @Apellidos VALUES
('Perez'),('Gomez'),('Rodriguez'),('Lopez'),('Fernandez'),
('Garcia'),('Martinez'),('Pereira'),('Romero'),('Torres'),
('Castro'),('Maciel'),('Lipchis'),('Ramos'),('Molina')

WHILE @i <= @maxi
BEGIN
	-- Seleccionar nombre y apellido aleatorio
		DECLARE @nombre VARCHAR(20) = (
		SELECT TOP 1 nombre FROM @Nombres ORDER BY NEWID())

	DECLARE @apellido VARCHAR(20) = (
		SELECT TOP 1 apellido FROM @Apellidos ORDER BY NEWID())

	INSERT INTO Consorcio.CuentaBancaria (CVU_CBU, nombreTitular, saldo)
	VALUES (
		-- CVU/CBU= 22 digitos aleatorios rellenados con 0 a la izquierda
		RIGHT('0000000000000000000000' + CAST(ABS(CHECKSUM(NEWID())) % 1000000000000000000000 AS VARCHAR(22)), 22),

		-- Nombre Titular= combinacion nombre + apellido
		@nombre + ' ' + @apellido,

		-- Saldo =numero aleatorio entre 1000 y 50000
		CAST(ROUND(((RAND(CHECKSUM(NEWID())) * 49000) + 1000), 2) AS DECIMAL(10,2)))

	SET @i += 1;
END
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
*/

/*CREATE OR ALTER PROCEDURE Negocio.SP_GenerarExpensasMensuales
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
*/
