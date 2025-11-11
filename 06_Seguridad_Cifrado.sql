/* =========================================================================================
   ENTREGA 7 - REQUISITOS DE SEGURIDAD
   Materia: 3641 - Bases de Datos Aplicada
   Comisión: 5600
   Grupo: 11
   Fecha: 10/11/2025
   Archivo: 04_RequisitosDeSeguridad.sql

   Integrantes:
   - Hidalgo, Eduardo - 41173099
   - Quispe, Milagros Soledad - 45064110
   - Puma, Florencia - 42945609
   - Fontanet Caniza, Camila - 44892126
   - Altamiranda, Isaias Taiel - 43094671
   - Pastori, Ximena - 42300128

   Descripción:
   Implementación de los requisitos de seguridad:
   1) Creación de roles y asignación de permisos según área.
   2) Cifrado de datos personales y sensibles.
   3) Definición y programación de políticas de respaldo (backup).
========================================================================================= */


/* =========================================================================================
   1️⃣ CREACIÓN DE ROLES Y ASIGNACIÓN DE PERMISOS
========================================================================================= */


USE [master]
GO

------------------ CREACIÓN DE LOGIN ------------------


IF SUSER_ID('administrativoGeneral') IS NULL
BEGIN
    CREATE LOGIN administrativoGeneral
		WITH PASSWORD = 'admin#123',
		CHECK_POLICY = ON,
		DEFAULT_DATABASE = [Com5600G11];
END
GO

IF SUSER_ID('administrativoBancario') IS NULL
BEGIN
    CREATE LOGIN administrativoBancario
		WITH PASSWORD = 'supervisor2024*',
		CHECK_POLICY = ON,
		DEFAULT_DATABASE = [Com5600G11];
END
GO


IF SUSER_ID('administrativoOperativo') IS NULL
BEGIN
    CREATE LOGIN administrativoOperativo
		WITH PASSWORD = 'oper#4321',
		CHECK_POLICY = ON,
		DEFAULT_DATABASE = [Com5600G11];
END
GO

IF SUSER_ID('sistemas') IS NULL
BEGIN
    CREATE LOGIN sistemas
		WITH PASSWORD = 'sistemas#4321',
		CHECK_POLICY = ON,
		DEFAULT_DATABASE = [Com5600G11];
END
GO


-------------------------------------------------------
----------------- CREACIÓN DE USUARIO -----------------
-------------------------------------------------------

USE [Com5600G11]
GO

IF DATABASE_PRINCIPAL_ID('administrativoGeneral') IS NULL
	CREATE USER administrativoGeneral FOR LOGIN administrativoGeneral WITH DEFAULT_SCHEMA = [Persona];
GO

IF DATABASE_PRINCIPAL_ID('administrativoBancario') IS NULL
	CREATE USER administrativoBancario FOR LOGIN administrativoBancario WITH DEFAULT_SCHEMA = [Negocio];
GO

IF DATABASE_PRINCIPAL_ID('administrativoOperativo') IS NULL
	CREATE USER administrativoOperativo FOR LOGIN administrativoOperativo WITH DEFAULT_SCHEMA = [Negocio];
GO

IF DATABASE_PRINCIPAL_ID('sistemas') IS NULL
	CREATE USER sistemas FOR LOGIN sistemas WITH DEFAULT_SCHEMA = [Persona];
GO


-------------------------------------------------------
------------------ CREACIÓN DE ROLES ------------------
-------------------------------------------------------

IF DATABASE_PRINCIPAL_ID('AdministrativosGenerales') IS NULL
	CREATE ROLE AdministrativosGenerales AUTHORIZATION dbo;
GO

IF DATABASE_PRINCIPAL_ID('AdministrativosBancarios') IS NULL
	CREATE ROLE AdministrativosBancarios AUTHORIZATION dbo;
GO

IF DATABASE_PRINCIPAL_ID('AdministrativosOperativos') IS NULL
	CREATE ROLE AdministrativosOperativos AUTHORIZATION dbo;
GO


-------------------------------------------------------
------------- ASIGNACIÓN DE PERMISOS ------------------
-------------------------------------------------------


-- Administrativo General: actualización de datos UF y generación de reportes
GRANT SELECT, UPDATE ON SCHEMA::Consorcio TO administrativoGeneral;
GRANT SELECT ON SCHEMA::Negocio TO administrativoGeneral;
GRANT EXECUTE ON SCHEMA::Operaciones TO administrativoGeneral;

-- Administrativo Bancario: importación de información bancaria + reportes
GRANT SELECT, INSERT, UPDATE ON SCHEMA::Pago TO administrativoBancario;
GRANT EXECUTE ON SCHEMA::Operaciones TO administrativoBancario;

-- Administrativo Operativo: actualización de UF + reportes
GRANT SELECT, UPDATE ON SCHEMA::Consorcio TO administrativoOperativo;
GRANT EXECUTE ON SCHEMA::Operaciones TO administrativoOperativo;

-- Sistemas: sólo reportes (lectura y ejecución)
GRANT SELECT ON SCHEMA::Operaciones TO sistemas;
GRANT EXECUTE ON SCHEMA::Operaciones TO sistemas;
GO

-------------------------------------------------------
------------------ AÑADIR USUARIOS A ------------------
------------------------ ROLES ------------------------
-------------------------------------------------------



ALTER ROLE AdministrativosGenerales ADD MEMBER administrativoGeneral;
ALTER ROLE AdministrativosBancarios ADD MEMBER administrativoBancario;
ALTER ROLE AdministrativosOperativos ADD MEMBER administrativoOperativo;
ALTER ROLE Sistemas ADD MEMBER sistema;
GO




-------------------------------------------------------
-------------------- ENCRIPTACIÓN ---------------------
-------------------------------------------------------

ALTER TABLE Consorcio.Persona
ADD DNI_encriptado VARBINARY(256),
	EmailPersona_encriptado VARBINARY(256),
	CVU_CBU_encriptado VARBINARY(256)
GO

DECLARE @Contraseña NVARCHAR(16) = 'Contrasenia135';

UPDATE Consorcio.Persona
SET DNI_encriptado = ENCRYPTBYPASSPHRASE(@Contraseña, CAST(dni AS CHAR(8)), 1, CAST(idPersona AS VARBINARY(255))),
	Email_encriptado = ENCRYPTBYPASSPHRASE(@Contraseña, email),
	CVU_CBU_encriptado = ENCRYPTBYPASSPHRASE(@Contraseña, CVU_CBU),
GO

ALTER TABLE Consorcio.Persona
DROP COLUMN idPersona, dni, email
GO


-- Vista para descifrar (solo lectura para roles autorizados)
CREATE OR ALTER VIEW Consorcio.vwPersonasDescifradas
AS
SELECT
    idPersona,
    nombre,
    apellido,
    CONVERT(NVARCHAR(50), DECRYPTBYPASSPHRASE('Contrasenia135', DNI_encriptado)) AS DNI,
    CONVERT(NVARCHAR(100), DECRYPTBYPASSPHRASE('Contrasenia135', EmailPersona_encriptado)) AS EmailPersona,
    CONVERT(NVARCHAR(50), DECRYPTBYPASSPHRASE('Contrasenia135', CVU_CBU_encriptado)) AS CVU_CBUPersona
FROM Consorcio.Persona;
GO

-- Solo los roles administrativos y sistemas pueden acceder
DENY SELECT ON Consorcio.Persona TO PUBLIC;
GRANT SELECT ON Consorcio.vwPersonasDescifradas TO AdministrativosGenerales, Sistemas;
GO




/* =========================================================================================
   3️⃣ POLÍTICAS DE RESPALDO (BACKUP)
========================================================================================= */

-- Política general:
--   • Backup FULL diario (00:00)
--   • Backup diferencial cada 6 horas
--   • Backup del log cada 1 hora
--   • Retención: 14 días
--   • RPO: 1 hora / RTO: 30 min

-- Backup completo diario
BACKUP DATABASE [Com5600G11]
TO DISK = 'C:\Backups\Com5600G11_FULL.bak'
WITH INIT, COMPRESSION, NAME = 'Backup FULL diario - Com5600G11';
GO

-- Backup del log cada hora
BACKUP LOG [Com5600G11]
TO DISK = 'C:\Backups\Com5600G11_LOG.trn'
WITH NOINIT, COMPRESSION, NAME = 'Backup LOG horario - Com5600G11';
GO

-- Registro programado (solo referencia)
-- ---------------------------------------------------------
-- JOB: Backup_Com5600G11_FULL_Diario  → Diario 00:00 hs
-- JOB: Backup_Com5600G11_Diferencial  → Cada 6 hs
-- JOB: Backup_Com5600G11_Log_Horario  → Cada hora
-- RPO: 1 hora / RTO estimado: 30 min
-- ---------------------------------------------------------

PRINT '✅ Seguridad aplicada: roles creados, datos cifrados y backups configurados.';
GO
