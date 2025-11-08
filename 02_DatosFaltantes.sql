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
CREATE OR ALTER PROCEDURE Operaciones.SP_generadorCuentaBancaria
AS
BEGIN
    SET NOCOUNT ON;

    -- Tablas de datos de origen (sin cambios)
    DECLARE @Nombres TABLE (nombre VARCHAR(20));
    INSERT INTO @Nombres VALUES ('Juan'),('Maria'),('Carlos'),('Monica'),('Jorge'),
    ('Lucia'),('Sofia'),('Damian'),('Martina'),('Diego'), ('Barbara'),('Franco'),('Valentina'),('Nicolas'),('Camila');

    DECLARE @Apellidos TABLE (apellido VARCHAR(20));
    INSERT INTO @Apellidos VALUES ('Perez'),('Gomez'),('Rodriguez'),('Lopez'),('Fernandez'),
    ('Garcia'),('Martinez'),('Pereira'),('Romero'),('Torres'), ('Castro'),('Maciel'),('Lipchis'),('Ramos'),('Molina');

    -- 1. Crear una TABLA TEMPORAL para almacenar los datos generados y el mapeo (RN)
    IF OBJECT_ID('tempdb..#CuentasGeneradasTemp') IS NOT NULL DROP TABLE #CuentasGeneradasTemp;

    CREATE TABLE #CuentasGeneradasTemp (
        rn INT PRIMARY KEY,
        CVU_CBU CHAR(22) NOT NULL,
        nombreTitular VARCHAR(50) NOT NULL,
        saldo DECIMAL(10, 2)
    );

    -- 2. Insertar los datos generados en la tabla temporal (Usando la CTE de forma limitada)
    WITH CTE_Generacion AS (
        SELECT
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn,
            -- Generar CBU/CVU
            RIGHT('0000000000000000000000' + 
                  CAST(ABS(CHECKSUM(NEWID())) % 1000000000000000000000 AS VARCHAR(22)), 22) AS CVU_CBU,

            -- Generar Nombre Titular
            (SELECT TOP 1 n.nombre FROM @Nombres AS n ORDER BY NEWID()) + ' ' + 
            (SELECT TOP 1 a.apellido FROM @Apellidos AS a ORDER BY NEWID()) AS nombreTitular,
            
            -- Generar Saldo
            CAST(ROUND(((ABS(CHECKSUM(NEWID())) % 49000) + 1000), 2) AS DECIMAL(10,2)) AS saldo
        
        -- Generar un registro por cada Consorcio existente
        FROM Consorcio.Consorcio
    )
    INSERT INTO #CuentasGeneradasTemp (rn, CVU_CBU, nombreTitular, saldo)
    SELECT rn, CVU_CBU, nombreTitular, saldo
    FROM CTE_Generacion;

    
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


CREATE OR ALTER PROCEDURE Operaciones.sp_CargaConsorciosSemilla
AS
BEGIN
    SET NOCOUNT ON;

    PRINT N'Insertando/Verificando datos semilla en Consorcio.Consorcio...';

    IF NOT EXISTS (SELECT 1 FROM Consorcio.Consorcio WHERE nombre = 'Azcuenaga')
    BEGIN
        INSERT INTO Consorcio.Consorcio (nombre, direccion)
        VALUES ('Azcuenaga', 'Dirección desconocida');
    END

    IF NOT EXISTS (SELECT 1 FROM Consorcio.Consorcio WHERE nombre = 'Torre Central')
    BEGIN
        INSERT INTO Consorcio.Consorcio (nombre, direccion)
        VALUES ('Torre Central', 'Dirección desconocida');
    END

    IF NOT EXISTS (SELECT 1 FROM Consorcio.Consorcio WHERE nombre = 'Edificio Mitre')
    BEGIN
        INSERT INTO Consorcio.Consorcio (nombre, direccion)
        VALUES ('Edificio Mitre', 'Dirección desconocida');
    END

    PRINT N'Carga de datos semilla de Consorcios finalizada.';
END
GO

CREATE OR ALTER PROCEDURE Operaciones.sp_CargaCuentasBancariasSemilla
AS
BEGIN
    SET NOCOUNT ON;

    PRINT N'Insertando/Verificando datos semilla en Consorcio.CuentaBancaria...';

    DECLARE @i INT = 1;
    DECLARE @max INT = 6;

    -- Cuentas para Azcuenaga
    IF NOT EXISTS (SELECT 1 FROM Consorcio.CuentaBancaria WHERE CVU_CBU = '0000003100010000000101')
    BEGIN
        INSERT INTO Consorcio.CuentaBancaria (CVU_CBU)
        VALUES ('0000003100010000000101');
    END

    IF NOT EXISTS (SELECT 1 FROM Consorcio.CuentaBancaria WHERE CVU_CBU = '0000003100010000000102')
    BEGIN
        INSERT INTO Consorcio.CuentaBancaria (CVU_CBU)
        VALUES ('0000003100010000000102');
    END

    IF NOT EXISTS (SELECT 1 FROM Consorcio.CuentaBancaria WHERE CVU_CBU = '0000003100010000000103')
    BEGIN
        INSERT INTO Consorcio.CuentaBancaria (CVU_CBU)
        VALUES ('0000003100010000000103');
    END

    IF NOT EXISTS (SELECT 1 FROM Consorcio.CuentaBancaria WHERE CVU_CBU = '0000003100010000000104')
    BEGIN
        INSERT INTO Consorcio.CuentaBancaria (CVU_CBU)
        VALUES ('0000003100010000000104');
    END

    PRINT '  >> Cuentas bancarias de "Azcuenaga" insertadas (4 cuentas).';

    -- Cuentas para Torre Central
    IF NOT EXISTS (SELECT 1 FROM Consorcio.CuentaBancaria WHERE CVU_CBU = '0000003100020000000201')
    BEGIN
        INSERT INTO Consorcio.CuentaBancaria (CVU_CBU)
        VALUES ('0000003100020000000201');
    END

    IF NOT EXISTS (SELECT 1 FROM Consorcio.CuentaBancaria WHERE CVU_CBU = '0000003100020000000202')
    BEGIN
        INSERT INTO Consorcio.CuentaBancaria (CVU_CBU)
        VALUES ('0000003100020000000202');
    END

    PRINT '  >> Cuentas bancarias de "Torre Central" insertadas (2 cuentas).';

    -- Cuenta para Edificio Mitre
    IF NOT EXISTS (SELECT 1 FROM Consorcio.CuentaBancaria WHERE CVU_CBU = '0000003100030000000301')
    BEGIN
        INSERT INTO Consorcio.CuentaBancaria (CVU_CBU)
        VALUES ('0000003100030000000301');
    END

    PRINT '  >> Cuenta bancaria de "Edificio Mitre" insertada (1 cuenta).';

    PRINT N'Carga de datos semilla de Cuentas Bancarias finalizada.';
END
GO

CREATE OR ALTER PROCEDURE Operaciones.sp_CargaUnidadesFuncionalesSemilla
AS
BEGIN
    SET NOCOUNT ON;

    PRINT N'Insertando/Verificando datos semilla en Consorcio.UnidadFuncional...';

    DECLARE @idAzcuenaga INT;
    DECLARE @idTorreCentral INT;
    DECLARE @idEdificioMitre INT;

    -- Obtener IDs de los consorcios
    SELECT @idAzcuenaga = id FROM Consorcio.Consorcio WHERE nombre = 'Azcuenaga';
    SELECT @idTorreCentral = id FROM Consorcio.Consorcio WHERE nombre = 'Torre Central';
    SELECT @idEdificioMitre = id FROM Consorcio.Consorcio WHERE nombre = 'Edificio Mitre';

    IF @idAzcuenaga IS NULL
    BEGIN
        RAISERROR('Error: El consorcio "Azcuenaga" no existe. Ejecute primero sp_CargaConsorciosSemilla.', 16, 1);
        RETURN;
    END

    -- Verificar que existan las cuentas bancarias
    IF NOT EXISTS (SELECT 1 FROM Consorcio.CuentaBancaria WHERE CVU_CBU = '0000003100010000000101')
    BEGIN
        RAISERROR('Error: Las cuentas bancarias no existen. Ejecute primero sp_CargaCuentasBancariasSemilla.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM Consorcio.UnidadFuncional WHERE CVU_CBU = '0000003100010000000101')
    BEGIN
        INSERT INTO Consorcio.UnidadFuncional (
            CVU_CBU, consorcioId, numero, piso, departamento, metrosCuadrados, porcentajeExpensas
        )
        VALUES (
            '0000003100010000000101', @idAzcuenaga, '1', 'PB', 'A', 45.00, 4.4
        );
    END

    -- UF 2 - PB B (45 m², coeficiente 4.4)
    IF NOT EXISTS (SELECT 1 FROM Consorcio.UnidadFuncional WHERE CVU_CBU = '0000003100010000000102')
    BEGIN
        INSERT INTO Consorcio.UnidadFuncional (
            CVU_CBU, consorcioId, numero, piso, departamento, metrosCuadrados, porcentajeExpensas
        )
        VALUES (
            '0000003100010000000102', @idAzcuenaga, '2', 'PB', 'B', 45.00, 4.4
        );
    END

    -- UF 3 - PB C (45 m², coeficiente 4.4)
    IF NOT EXISTS (SELECT 1 FROM Consorcio.UnidadFuncional WHERE CVU_CBU = '0000003100010000000103')
    BEGIN
        INSERT INTO Consorcio.UnidadFuncional (
            CVU_CBU, consorcioId, numero, piso, departamento, metrosCuadrados, porcentajeExpensas
        )
        VALUES (
            '0000003100010000000103', @idAzcuenaga, '3', 'PB', 'C', 45.00, 4.4
        );
    END

    -- UF 4 - PB D (45 m², coeficiente 4.4)
    IF NOT EXISTS (SELECT 1 FROM Consorcio.UnidadFuncional WHERE CVU_CBU = '0000003100010000000104')
    BEGIN
        INSERT INTO Consorcio.UnidadFuncional (
            CVU_CBU, consorcioId, numero, piso, departamento, metrosCuadrados, porcentajeExpensas
        )
        VALUES (
            '0000003100010000000104', @idAzcuenaga, '4', 'PB', 'D', 45.00, 4.4
        );
    END

    PRINT '  >> Unidades Funcionales de "Azcuenaga" insertadas (4 UFs - PB A/B/C/D, coeficiente 4.4 c/u).';
    
    IF @idTorreCentral IS NOT NULL
    BEGIN
        -- UF 1 - Piso 1 A (60 m²)
        IF NOT EXISTS (SELECT 1 FROM Consorcio.UnidadFuncional WHERE CVU_CBU = '0000003100020000000201')
        BEGIN
            INSERT INTO Consorcio.UnidadFuncional (
                CVU_CBU, consorcioId, numero, piso, departamento, metrosCuadrados, porcentajeExpensas
            )
            VALUES (
                '0000003100020000000201', @idTorreCentral, '1', '1', 'A', 60.00, 52.17
            );
        END

        -- UF 2 - Piso 1 B (55 m²)
        IF NOT EXISTS (SELECT 1 FROM Consorcio.UnidadFuncional WHERE CVU_CBU = '0000003100020000000202')
        BEGIN
            INSERT INTO Consorcio.UnidadFuncional (
                CVU_CBU, consorcioId, numero, piso, departamento, metrosCuadrados, porcentajeExpensas
            )
            VALUES (
                '0000003100020000000202', @idTorreCentral, '2', '1', 'B', 55.00, 47.83
            );
        END

        PRINT '  >> Unidades Funcionales de "Torre Central" insertadas (2 UFs, 52.17% y 47.83%).';
    END
    
    IF @idEdificioMitre IS NOT NULL
    BEGIN
        -- UF 1 - Piso 2 A (70 m²)
        IF NOT EXISTS (SELECT 1 FROM Consorcio.UnidadFuncional WHERE CVU_CBU = '0000003100030000000301')
        BEGIN
            INSERT INTO Consorcio.UnidadFuncional (
                CVU_CBU, consorcioId, numero, piso, departamento, metrosCuadrados, porcentajeExpensas
            )
            VALUES (
                '0000003100030000000301', @idEdificioMitre, '1', '2', 'A', 70.00, 100.00
            );
        END

        PRINT '  >> Unidades Funcionales de "Edificio Mitre" insertadas (1 UF, 100%).';
    END

    PRINT N'Carga de datos semilla de Unidades Funcionales finalizada.';
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
