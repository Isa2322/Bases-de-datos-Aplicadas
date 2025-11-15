/*
Base de datos aplicadas
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

/*
	En este script se ejecutan todos los stored procedures que importan datos directamente de los archivos provistos
	y los que rellenan las tablas con los datos faltantes, estan en orden para no generar problemas en la insercion de datos
	Reemplazar la ruta del archivo por la correspondiente segun quien este ejecutando.
*/

USE [Com5600G11]; 
GO

--=============================================================================================================================
-- Seguir las ejecuciones en el orden en que fueron declaradas.
-- Antes de ejecutar los SPs de importacion del archivo de "datos varios" asegurarse de que el mismo se haya convertido a CSV.
--=============================================================================================================================

EXEC Operaciones.sp_CargaTiposRol
GO

EXEC Operaciones.sp_CrearYcargar_FormasDePago
GO

EXEC Operaciones.sp_ImportarPago @rutaArchivo  = 'C:\Users\camil\OneDrive\Escritorio\TP BASES\Bases-de-datos-Aplicadas\consorcios\pagos_consorcios.csv';
GO

EXEC Operaciones.sp_ImportarDatosConsorcios @rutaArch= 'C:\Users\camil\OneDrive\Escritorio\TP BASES\Bases-de-datos-Aplicadas\consorcios\datos varios - Consorcios.csv';
GO

EXEC Operaciones.sp_ImportarInquilinosPropietarios @RutaArchivo = 'C:\Users\camil\OneDrive\Escritorio\TP BASES\Bases-de-datos-Aplicadas\consorcios\Inquilino-propietarios-datos.csv';
GO

EXEC Operaciones.sp_ImportarUFInquilinos @RutaArchivo = 'C:\Users\camil\OneDrive\Escritorio\TP BASES\Bases-de-datos-Aplicadas\consorcios\Inquilino-propietarios-UF.csv';
GO

EXEC Operaciones.SP_generadorCuentaBancaria;
GO

EXEC Operaciones.sp_ImportarUFporConsorcio @RutaArchivo = 'C:\Users\camil\OneDrive\Escritorio\TP BASES\Bases-de-datos-Aplicadas\consorcios\UF por consorcio.txt';
GO

EXEC Operaciones.sp_CargarGastosExtraordinarios;
GO

BEGIN TRY

    BEGIN TRAN;
   --=============================================
    -- Importar Servicios (Gastos Mensuales)
    --============================================

	PRINT 'Ejecutando sp_ImportarGastosMensuales...'
    EXEC Operaciones.sp_ImportarGastosMensuales @ruta = 'C:\Users\camil\OneDrive\Escritorio\TP BASES\Bases-de-datos-Aplicadas\consorcios\Servicios.Servicios.json';
    PRINT 'Gastos Mensuales importados correctamente.';

    --============================================
    -- Importar Proveedores
    --============================================

	PRINT 'Ejecutando sp_ImportarDatosProveedores...';
    EXEC Operaciones.sp_ImportarDatosProveedores @rutaArch = 'C:\Users\camil\OneDrive\Escritorio\TP BASES\Bases-de-datos-Aplicadas\consorcios\datos varios - Proveedores.csv';
    PRINT 'Proveedores importados correctamente.';

    --============================================
    -- Completar Gastos Generales
    --============================================

    PRINT 'Ejecutando CargarGastosGeneralesOrdinarios...';
    EXEC Operaciones.CargarGastosGeneralesOrdinarios;
    PRINT 'Gastos Generales completados correctamente.';

    COMMIT TRAN;
    PRINT 'TRANSACCIÓN COMPLETADA EXITOSAMENTE';

END TRY
BEGIN CATCH

    PRINT 'ERROR EN LA IMPORTACIÓN. HACIENDO ROLLBACK...';

    IF @@TRANCOUNT > 0
        ROLLBACK TRAN;

    PRINT 'Rollback realizado. La tabla GastoOrdinario queda limpia.';

    THROW;
END CATCH;
GO

EXEC Negocio.SP_GenerarLoteDeExpensas 
GO

EXEC Operaciones.sp_RellenarCocheras
GO

EXEC Operaciones.sp_RellenarBauleras
GO

SELECT * FROM Consorcio.TipoRol
SELECT * FROM Consorcio.Persona
SELECT * FROM Consorcio.CuentaBancaria;
SELECT * FROM Consorcio.Consorcio
SELECT * FROM Consorcio.UnidadFuncional
SELECT * FROM Consorcio.Cochera
SELECT * FROM Consorcio.Baulera
SELECT * FROM Negocio.DetalleExpensa
SELECT * FROM Negocio.Expensa
SELECT * FROM Negocio.GastoExtraordinario
SELECT * FROM Negocio.GastoOrdinario
SELECT * FROM Pago.FormaDePago
SELECT * FROM Pago.Pago
SELECT * FROM Pago.FormaDePago




