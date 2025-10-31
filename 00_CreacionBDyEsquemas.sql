EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'Com5600G11'
GO
USE [master]
GO

-- Forzar desconexion de la base de datos
ALTER DATABASE Com5600G11 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE [Com5600G11]
GO

CREATE DATABASE Com5600G11;
go

CREATE SCHEMA Operaciones;
go

CREATE SCHEMA Negocio;
go

CREATE SCHEMA Consorcio;
go

CREATE SCHEMA Pago;
go

/*
SELECT
    name AS NombreEsquema
FROM
    sys.schemas
WHERE
    schema_id < 16000 -- Generalmente filtra los esquemas temporales y del sistema
    AND name NOT IN ('sys', 'INFORMATION_SCHEMA', 'guest', 'db_owner')
ORDER BY
    name; */