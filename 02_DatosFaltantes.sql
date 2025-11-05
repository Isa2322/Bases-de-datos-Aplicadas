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
