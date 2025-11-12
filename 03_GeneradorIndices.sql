-- CREACION DE INDICES  separados por esquema_______________________________________________________________________________

-- USO LA BASE DEL TP
USE [Com5600G11]
GO

-- Búsquedas frecuentes por nombre (joins desde staging/archivos)
IF NOT EXISTS (SELECT 1 FROM sys.indexes 
               WHERE name = 'IX_Consorcio_nombre' 
                 AND object_id = OBJECT_ID('Consorcio.Consorcio'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Consorcio_nombre
        ON Consorcio.Consorcio (nombre);
END
GO

-- UnidadFuncional: filtros por consorcio + acceso a CVU/ubicación sin lookups
IF NOT EXISTS (SELECT 1 FROM sys.indexes 
               WHERE name = 'IX_UF_Consorcio'
                 AND object_id = OBJECT_ID('Consorcio.UnidadFuncional'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_UF_Consorcio
        ON Consorcio.UnidadFuncional (consorcioId)
        INCLUDE (CVU_CBU, piso, departamento, numero, metrosCuadrados, porcentajeExpensas, tipo);
END
GO

-- UnidadFuncional: búsquedas por CVU_CBU (join contra Persona o Cuenta)
IF NOT EXISTS (SELECT 1 FROM sys.indexes 
               WHERE name = 'IX_UF_CVUCBU'
                 AND object_id = OBJECT_ID('Consorcio.UnidadFuncional'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_UF_CVUCBU
        ON Consorcio.UnidadFuncional (CVU_CBU)
        INCLUDE (id, consorcioId);
END
GO

-- Persona: joins por CBU/CVU y salida de datos de contacto en reportes
IF OBJECT_ID('Consorcio.Persona','U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes 
                   WHERE name = 'IX_Persona_CBU'
                     AND object_id = OBJECT_ID('Consorcio.Persona'))
    BEGIN
        CREATE NONCLUSTERED INDEX IX_Persona_CBU
            ON Consorcio.Persona (CVU_CBU)
            INCLUDE (dni, nombre, apellido, email, telefono);
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.indexes 
                   WHERE name = 'IX_Persona_CVU'
                     AND object_id = OBJECT_ID('Consorcio.Persona'))
    BEGIN
        CREATE NONCLUSTERED INDEX IX_Persona_CVU
            ON Consorcio.Persona (CVU_CBU)
            INCLUDE (dni, nombre, apellido, email, telefono);
    END;
END
GO

---------------------------------------------------------------
-- NEGOCIO (Expensa / DetalleExpensa / Gastos)
---------------------------------------------------------------

-- Expensa: filtros por consorcio y período (año/mes) + joins por id
IF NOT EXISTS (SELECT 1 FROM sys.indexes 
               WHERE name = 'IX_Expensa_ConsorcioPeriodo'
                 AND object_id = OBJECT_ID('Negocio.Expensa'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Expensa_ConsorcioPeriodo
        ON Negocio.Expensa (consorcioId, fechaPeriodoAnio, fechaPeriodoMes)
        INCLUDE (id, saldoAnterior, ingresosEnTermino, ingresosAdeudados, ingresosAdelantados, egresos, saldoCierre);
END
GO

-- DetalleExpensa: filtros por fecha (reportes) y joins hacia UF/Expensa
IF NOT EXISTS (SELECT 1 FROM sys.indexes 
               WHERE name = 'IX_DetalleExpensa_Fechas_UF_Exp'
                 AND object_id = OBJECT_ID('Negocio.DetalleExpensa'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_DetalleExpensa_Fechas_UF_Exp
        ON Negocio.DetalleExpensa (primerVencimiento, idUnidadFuncional, expensaId)
        INCLUDE (totalaPagar, pagosRecibidos, prorrateoOrdinario, prorrateoExtraordinario, interesMora, segundoVencimiento);
END
GO

-- Gastos ordinarios: consultas por expensa/tipo y búsqueda por factura (ya tiene UQ)
IF OBJECT_ID('Negocio.GastoOrdinario','U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes 
                   WHERE name = 'IX_GastoOrd_Expensa_Tipo'
                     AND object_id = OBJECT_ID('Negocio.GastoOrdinario'))
    BEGIN
        CREATE NONCLUSTERED INDEX IX_GastoOrd_Expensa_Tipo
            ON Negocio.GastoOrdinario (idExpensa, tipoServicio)
            INCLUDE (importeTotal, fechaEmision, nombreEmpresaoPersona, detalle);
    END
END
GO

-- Gastos extraordinarios: consultas por expensa y cuota
IF OBJECT_ID('Negocio.GastoExtraordinario','U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes 
                   WHERE name = 'IX_GastoExt_Expensa_Cuota'
                     AND object_id = OBJECT_ID('Negocio.GastoExtraordinario'))
    BEGIN
        CREATE NONCLUSTERED INDEX IX_GastoExt_Expensa_Cuota
            ON Negocio.GastoExtraordinario (idExpensa, nroCuota)
            INCLUDE (importeTotal, esPagoTotal, fechaEmision, nombreEmpresaoPersona, detalle, totalCuota);
    END
END
GO

---------------------------------------------------------------
-- PAGO (Pagos / PagosAplicados)
---------------------------------------------------------------

-- Pago: filtros por fecha en Reporte 6 y búsquedas por CBU origen
IF NOT EXISTS (SELECT 1 FROM sys.indexes 
               WHERE name = 'IX_Pago_Fecha'
                 AND object_id = OBJECT_ID('Pago.Pago'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Pago_Fecha
        ON Pago.Pago (fecha)
        INCLUDE (id, importe, idFormaPago, cbuCuentaOrigen);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes 
               WHERE name = 'IX_Pago_CBU'
                 AND object_id = OBJECT_ID('Pago.Pago'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Pago_CBU
        ON Pago.Pago (cbuCuentaOrigen)
        INCLUDE (id, fecha, importe, idFormaPago);
END
GO

-- PagoAplicado: recorridos por detalle o por pago (ambas direcciones)
IF NOT EXISTS (SELECT 1 FROM sys.indexes 
               WHERE name = 'IX_PagoAplicado_Detalle'
                 AND object_id = OBJECT_ID('Pago.PagoAplicado'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_PagoAplicado_Detalle
        ON Pago.PagoAplicado (idDetalleExpensa)
        INCLUDE (idPago, importeAplicado);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes 
               WHERE name = 'IX_PagoAplicado_Pago'
                 AND object_id = OBJECT_ID('Pago.PagoAplicado'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_PagoAplicado_Pago
        ON Pago.PagoAplicado (idPago)
        INCLUDE (idDetalleExpensa, importeAplicado);
END
GO
