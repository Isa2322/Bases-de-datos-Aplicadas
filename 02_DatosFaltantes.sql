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


USE [Com5600G11];
GO

-- =============================================
-- CARGA DE GASTOS EXTRAORDINARIOS
-- =============================================

INSERT INTO Negocio.GastoExtraordinario
    (consorcioId, detalle, importeTotal, fechaEmision, nombreEmpresaoPersona, esPagoTotal, nroCuota, totalCuota)
VALUES
-- 🔹 AZCUENAGA (id 1)
(1, 'Reparación estructural del techo', 420000.00, '2024-04-12', 'ConstruRed SRL', 1, NULL, 0),
(1, 'Reacondicionamiento de tanque de agua', 165000.00, '2024-05-18', 'AquaService', 0, 1, 55000.00),

-- 🔹 ALZAGA (id 2)
(2, 'Colocación de portón automático',  380000.00, '2024-04-28', 'TecnoPortones', 1, NULL, 0),
(2, 'Refacción del sistema pluvial', 210000.00, '2024-06-10', 'ObrasPluviales SRL', 1, NULL, 0),

-- 🔹 ALBERDI (id 3)
(3, 'Pintura integral del edificio',  295000.00, '2024-04-25', 'ColorSur Pinturas', 1, NULL, 0),
(3, 'Ampliación del salón de usos múltiples',  520000.00, '2024-06-05', 'ObraFina S.A.', 1, 2, 4),

-- 🔹 UNZUE (id 4)
(4, 'Reemplazo de tablero eléctrico principal', 360000.00, '2024-04-30', 'ElectroRed S.A.', 1, NULL, 0),
(4, 'Reparación de filtraciones en cocheras',  240000.00, '2024-05-22', 'Impermeables S.A.', 0, 1, 40000.00),

-- 🔹 PEREYRA IRAOLA (id 5)
(5, 'Colocación de cámaras de seguridad IP',  310000.00, '2024-04-14', 'SafeCam Systems', 1, NULL, 0),
(5, 'Cambio de cañerías de gas en planta baja',  415000.00, '2024-06-10', 'GasSur SRL', 1, 2, 46111.11);
GO