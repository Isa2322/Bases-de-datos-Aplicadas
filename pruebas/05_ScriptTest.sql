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

/*==============================================================
  SCRIPT DE TESTEO - Base de Datos Com5600G11
  Grupo 11 - Base de Datos Aplicadas
==============================================================*/

USE [Com5600G11];
GO
--Este script esta pensado para ejecutar en el siguiente orden 00_GeneradorObjetos y 01_importaciones y despues lo que esta aca


PRINT '========================================';
PRINT 'INICIO DE CARGA DE DATOS DE PRUEBA';
PRINT '========================================';
PRINT '';

---------------------------------------------------------
-- PASO 1: DATOS MAESTROS BASE
-- Probamos que se carguen correctamente los valores fijos
-- (roles, formas de pago y consorcios semilla)
---------------------------------------------------------
PRINT '--- PASO 1: Cargando datos maestros base ---';

-- 1.1 Tipos de Rol
EXEC Operaciones.CargaTiposRol;
PRINT 'Tipos de Rol cargados';

-- 1.2 Formas de Pago
EXEC Operaciones.SP_CrearYcargar_FormasDePago_Semilla;
PRINT 'Formas de Pago cargadas';

-- 1.3 Consorcios Semilla (5 consorcios)
EXEC Operaciones.sp_CargaConsorciosSemilla;
PRINT 'Consorcios Semilla cargados';


---------------------------------------------------------
-- PASO 2: PERSONAS Y CUENTAS
-- Probamos la generación de personas con roles
-- y la asignación de cuentas bancarias a consorcios
---------------------------------------------------------
PRINT '--- PASO 2: Generando Personas y Cuentas ---';

-- 2.1 Personas Semilla (100 personas con CVU/CBU)
EXEC Operaciones.sp_CargarPersonasSemilla;
PRINT 'Personas generadas';

-- 2.2 Cuentas Bancarias para Consorcios
EXEC Operaciones.SP_generadorCuentaBancaria;
PRINT 'Cuentas Bancarias para Consorcios generadas';

---------------------------------------------------------
-- PASO 3: UNIDADES FUNCIONALES Y ANEXOS
-- Probamos la estructura del edificio: unidades, cocheras, bauleras
---------------------------------------------------------
PRINT '--- PASO 3: Generando Unidades Funcionales ---';

-- 3.1 Unidades Funcionales (10 por consorcio)
EXEC Operaciones.sp_CargaUnidadesFuncionalesSemilla;
PRINT 'Unidades Funcionales generadas';

-- 3.2 Cocheras (1 por UF)
EXEC Operaciones.sp_RellenarCocheras;
PRINT 'Cocheras generadas';

-- 3.3 Bauleras (1 por UF)
EXEC Operaciones.sp_RellenarBauleras;
PRINT 'Bauleras generadas';

---------------------------------------------------------
-- PASO 4: GASTOS
-- Verificamos generación de gastos extraordinarios aleatorios
-- Los gastos ordinarios se crean luego con las expensas
---------------------------------------------------------
PRINT '--- PASO 4: Generando Gastos ---';
EXEC Operaciones.sp_GenerarGastosOrdinarios;
EXEC Negocio.sp_CargarGastosExtraordinarios;
PRINT 'Gastos Extraordinarios generados';

---------------------------------------------------------
-- PASO 5: GENERAR EXPENSAS MENSUALES
-- Probamos el procedimiento de creación de expensas por mes
-- Enero a Octubre 2024 para cada consorcio
---------------------------------------------------------
PRINT '--- PASO 5: Generando Expensas (Enero-Octubre 2024) ---';

DECLARE @ConsorcioID INT;
DECLARE @Mes INT;
DECLARE @Anio INT = 2024;

DECLARE ConsorciosCursor CURSOR FOR
    SELECT id FROM Consorcio.Consorcio;

OPEN ConsorciosCursor;
FETCH NEXT FROM ConsorciosCursor INTO @ConsorcioID;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Mes = 1;
    WHILE @Mes <= 10
    BEGIN
        EXEC Negocio.SP_GenerarExpensasMensuales @ConsorcioID, @Anio, @Mes;
        SET @Mes = @Mes + 1;
    END

    FETCH NEXT FROM ConsorciosCursor INTO @ConsorcioID;
END

CLOSE ConsorciosCursor;
DEALLOCATE ConsorciosCursor;

PRINT 'Expensas generadas para 5 consorcios x 10 meses';

---------------------------------------------------------
-- PASO 6: GENERAR PAGOS SIMULADOS
-- Probamos la carga aleatoria de pagos sobre los detalles de expensa
-- 80% de los registros pagan (total o parcial)
---------------------------------------------------------
SELECT * FROM Pago.FormaDePago;

INSERT INTO Pago.Pago (fecha, importe, cbuCuentaOrigen, idFormaPago)
SELECT 
    -- Fecha del pago: 5-10 días después del vencimiento (primer día del mes siguiente)
    DATEADD(DAY, 
            5 + (ABS(CHECKSUM(NEWID())) % 6),
            DATEFROMPARTS(
                CASE WHEN E.fechaPeriodoMes = 12 THEN E.fechaPeriodoAnio + 1 ELSE E.fechaPeriodoAnio END,
                CASE WHEN E.fechaPeriodoMes = 12 THEN 1 ELSE E.fechaPeriodoMes + 1 END,
                1
            )
    ) AS fecha,
    -- Importe: 70-100% del total a pagar
    CAST(
        DE.totalaPagar * (0.70 + (ABS(CHECKSUM(NEWID())) % 31) / 100.0)
        AS DECIMAL(18,2)
    ) AS importe,
    UF.CVU_CBU AS cbuCuentaOrigen,
    -- Forma de pago aleatoria
    1 + (ABS(CHECKSUM(NEWID())) % 3) AS idFormaPago
FROM Negocio.DetalleExpensa DE
INNER JOIN Consorcio.UnidadFuncional UF ON DE.idUnidadFuncional = UF.id
INNER JOIN Negocio.Expensa E ON DE.expensaId = E.id
WHERE 
    (ABS(CHECKSUM(NEWID())) % 100) < 80; -- 80% de los detalles pagan

DECLARE @TotalPagos INT = @@ROWCOUNT;
PRINT CONCAT( @TotalPagos, ' pagos simulados generados');

---------------------------------------------------------
-- PASO 7: APLICAR PAGOS A EXPENSAS
-- Probamos el procedimiento que vincula los pagos
-- con los detalles de expensa correspondientes
---------------------------------------------------------
PRINT '--- PASO 7: Aplicando Pagos a Detalles de Expensa ---';

EXEC Operaciones.sp_AplicarPagosACuentas;
PRINT 'Pagos aplicados y vinculados a DetalleExpensa';

---------------------------------------------------------
-- RESUMEN FINAL
-- Consultamos la cantidad de registros generados por tabla
-- para validar resultados de la carga
---------------------------------------------------------
PRINT '========================================';
PRINT 'RESUMEN DE CARGA COMPLETADA';
PRINT '========================================';
PRINT '';

SELECT 'TipoRol' AS Tabla, COUNT(*) AS Registros FROM Consorcio.TipoRol
UNION ALL SELECT 'Persona', COUNT(*) FROM Consorcio.Persona
UNION ALL SELECT 'CuentaBancaria', COUNT(*) FROM Consorcio.CuentaBancaria
UNION ALL SELECT 'Consorcio', COUNT(*) FROM Consorcio.Consorcio
UNION ALL SELECT 'UnidadFuncional', COUNT(*) FROM Consorcio.UnidadFuncional
UNION ALL SELECT 'Cochera', COUNT(*) FROM Consorcio.Cochera
UNION ALL SELECT 'Baulera', COUNT(*) FROM Consorcio.Baulera
UNION ALL SELECT 'FormaDePago', COUNT(*) FROM Pago.FormaDePago
UNION ALL SELECT 'Expensa', COUNT(*) FROM Negocio.Expensa
UNION ALL SELECT 'DetalleExpensa', COUNT(*) FROM Negocio.DetalleExpensa
UNION ALL SELECT 'GastoOrdinario', COUNT(*) FROM Negocio.GastoOrdinario
UNION ALL SELECT 'GastoExtraordinario', COUNT(*) FROM Negocio.GastoExtraordinario
UNION ALL SELECT 'Pago', COUNT(*) FROM Pago.Pago
UNION ALL SELECT 'PagoAplicado', COUNT(*) FROM Pago.PagoAplicado;

PRINT '';
PRINT 'CARGA DE DATOS DE PRUEBA COMPLETADA';
PRINT '========================================';
GO

PRINT '========================================';
PRINT 'INICIO DE VISUALIZACIÓN DE DATOS';
PRINT '========================================';
PRINT '';
GO
---------------------------------------------------------
-- SECCIÓN 1: DATOS BASE
---------------------------------------------------------
PRINT '--- 1. DATOS BASE ---';
GO

-- Tipos de Rol
SELECT * FROM Consorcio.TipoRol;
GO
PRINT 'Tipos de Rol cargados';
GO

-- Formas de Pago
SELECT * FROM Pago.FormaDePago;
GO
PRINT 'Formas de Pago cargadas';
GO

---------------------------------------------------------
-- SECCIÓN 2: PERSONAS Y CONSORCIOS
---------------------------------------------------------
PRINT '--- 2. PERSONAS Y CONSORCIOS ---';
GO
SELECT TOP 10 idPersona, nombre, apellido, dni, email, telefono
FROM Consorcio.Persona;

-- Personas (primeros 10 registros)
SELECT TOP 10 
    idPersona,
    nombre,
    apellido,
    dni,
    email,
    CVU_CBU,
    telefono,
    idTipoRol
FROM Consorcio.Persona
ORDER BY idPersona;
GO
PRINT 'Personas cargadas correctamente (se muestran 10)';
GO

---------------------------------------------------------
-- SECCIÓN 3: UNIDADES FUNCIONALES Y ANEXOS
---------------------------------------------------------
PRINT '--- 3. UNIDADES FUNCIONALES Y ANEXOS ---';
GO

SELECT TOP 10 *
FROM Consorcio.UnidadFuncional
ORDER BY id;
GO
PRINT 'Unidades Funcionales (10 primeros registros)';
GO

SELECT TOP 10 *
FROM Consorcio.Cochera;
GO
PRINT 'Cocheras cargadas';
GO

SELECT TOP 10 *
FROM Consorcio.Baulera;
GO
PRINT 'Bauleras cargadas';
GO


---------------------------------------------------------
-- SECCIÓN 4: GASTOS
---------------------------------------------------------
PRINT '--- 4. GASTOS ---';
GO

SELECT TOP 10 *
FROM Negocio.GastoOrdinario
ORDER BY fechaEmision DESC;
GO
PRINT 'Gastos Ordinarios (últimos 10)';
GO

SELECT TOP 10 *
FROM Negocio.GastoExtraordinario
ORDER BY fechaEmision DESC;
GO
PRINT 'Gastos Extraordinarios (últimos 10)';
GO

-- Consorcios
SELECT 
    id,
    nombre,
    CVU_CBU,
    direccion,
    metrosCuadradosTotal
FROM Consorcio.Consorcio
ORDER BY id;
GO
PRINT ' Consorcios cargados';
GO

-- Cuentas Bancarias (primeros 10 registros)
SELECT TOP 10 
    CVU_CBU,
    nombreTitular,
    saldo
FROM Consorcio.CuentaBancaria
ORDER BY nombreTitular;
GO
PRINT 'Cuentas Bancarias cargadas (se muestran 10)';
GO

---------------------------------------------------------
-- SECCIÓN 5: EXPENSAS
---------------------------------------------------------
PRINT '--- 5. EXPENSAS ---';
GO
*****************************************
SELECT TOP 10 *
FROM Negocio.DetalleExpensa
ORDER BY expensaId DESC;
GO
PRINT 'Detalles de Expensas (últimos 10)';
GO
****************************************
---------------------------------------------------------
-- SECCIÓN 6: PAGOS
---------------------------------------------------------
PRINT '--- 6. PAGOS ---';
GO

SELECT TOP 10 *
FROM Pago.Pago
ORDER BY fecha DESC;
GO
PRINT 'Pagos generados (últimos 10)';
GO

---------------------------------------------------------
-- SECCIÓN 7: CONSULTAS RESUMEN
---------------------------------------------------------
PRINT '--- 7. CONSULTAS DE CONTROL Y RESUMEN ---';
GO

-- Conteo por tabla principal
SELECT 'TipoRol' AS Tabla, COUNT(*) AS Registros FROM Consorcio.TipoRol
UNION ALL SELECT 'Persona', COUNT(*) FROM Consorcio.Persona
UNION ALL SELECT 'CuentaBancaria', COUNT(*) FROM Consorcio.CuentaBancaria
UNION ALL SELECT 'Consorcio', COUNT(*) FROM Consorcio.Consorcio
UNION ALL SELECT 'UnidadFuncional', COUNT(*) FROM Consorcio.UnidadFuncional
UNION ALL SELECT 'Cochera', COUNT(*) FROM Consorcio.Cochera
UNION ALL SELECT 'Baulera', COUNT(*) FROM Consorcio.Baulera
UNION ALL SELECT 'FormaDePago', COUNT(*) FROM Pago.FormaDePago
UNION ALL SELECT 'Expensa', COUNT(*) FROM Negocio.Expensa
UNION ALL SELECT 'DetalleExpensa', COUNT(*) FROM Negocio.DetalleExpensa
UNION ALL SELECT 'GastoOrdinario', COUNT(*) FROM Negocio.GastoOrdinario
UNION ALL SELECT 'GastoExtraordinario', COUNT(*) FROM Negocio.GastoExtraordinario
UNION ALL SELECT 'Pago', COUNT(*) FROM Pago.Pago
UNION ALL SELECT 'PagoAplicado', COUNT(*) FROM Pago.PagoAplicado;
GO
PRINT ' Conteo de registros por tabla completado';
GO
