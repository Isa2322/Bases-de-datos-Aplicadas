/* =========================================================================================
   ENTREGA 7 - SEGURIDAD Y CIFRADO
   Materia: 3641 - Bases de Datos Aplicada
   Comisión: 5600
   Grupo: 11
   Fecha: 07/11/2025
   Archivo: 07_Seguridad_Cifrado.sql

   Integrantes:
   - Hidalgo, Eduardo - 41173099
   - Quispe, Milagros Soledad - 45064110
   - Puma, Florencia - 42945609
   - Fontanet Caniza, Camila - 44892126
   - Altamiranda, Isaias Taiel - 43094671
   - Pastori, Ximena - 42300128

   Descripción:
   Implementación de medidas de seguridad requeridas:
   1) Creación de roles y asignación de permisos.
   2) Cifrado de datos sensibles/personales.
   3) Políticas y scripts de respaldo (backup).

========================================================================================= */


USE [Com5600G11];
GO


/* =========================================================================================
   1️ CREACIÓN DE ROLES Y ASIGNACIÓN DE PERMISOS
========================================================================================= */

IF OBJECT_ID('Operaciones.sp_SeguridadCifrado') IS NOT NULL
    DROP PROCEDURE Operaciones.sp_SeguridadCifrado;
GO

CREATE PROCEDURE Operaciones.sp_SeguridadCifrado
AS
BEGIN
    SET NOCOUNT ON;


PRINT '--- Creando roles de seguridad ---';

-- Eliminamos roles previos si existieran
IF EXISTS (SELECT *
    FROM sys.database_principals
    WHERE name = 'AdministrativoGeneral')
    DROP ROLE AdministrativoGeneral;
IF EXISTS (SELECT * 
FROM sys.database_principals
    WHERE name = 'AdministrativoBancario')
    DROP ROLE AdministrativoBancario;
IF EXISTS (SELECT * 
    FROM sys.database_principals
    WHERE name = 'AdministrativoOperativo')
    DROP ROLE AdministrativoOperativo;
IF EXISTS (SELECT *
    FROM sys.database_principals
    WHERE name = 'Sistemas')
    DROP ROLE Sistemas;
GO

-- Creación de roles
CREATE ROLE AdministrativoGeneral;
CREATE ROLE AdministrativoBancario;
CREATE ROLE AdministrativoOperativo;
CREATE ROLE Sistemas;
GO

PRINT '--- Asignando permisos por área ---';

-- Administrativo General: puede modificar las Unidades Funcionales (UF) y ejecutar los SP de operaciones.
GRANT SELECT, INSERT, UPDATE, DELETE ON 
    Consorcio.UnidadFuncional TO
    AdministrativoGeneral;
GRANT EXECUTE ON SCHEMA::Operaciones TO
    AdministrativoGeneral;

-- Administrativo Bancario: tiene permiso para ejecutar el procedimiento de importación de pagos
-- y para leer cosas del esquema Pago (no puede modificar UF).
GRANT EXECUTE ON OBJECT::Pago.sp_ImportacionPago TO
    AdministrativoBancario;
GRANT SELECT ON SCHEMA::Pago TO
    AdministrativoBancario;
GRANT EXECUTE ON SCHEMA::Operaciones TO
    AdministrativoBancario;

-- Administrativo Operativo: puede consultar/actualizar UF (menos privilegios que AdministrativoGeneral)
GRANT SELECT, UPDATE ON Consorcio.UnidadFuncional TO
    AdministrativoOperativo;
GRANT EXECUTE ON SCHEMA::Operaciones TO 
    AdministrativoOperativo;

-- Sistemas: rol técnico. Solo ejecución de SP de operaciones y ver definiciones (para tareas de mantenimiento).
GRANT EXECUTE ON SCHEMA::Operaciones TO 
    Sistemas;
GRANT VIEW DEFINITION TO 
    Sistemas;
GO

PRINT '--- Roles y permisos asignados correctamente ---';


/* =========================================================================================

   CIFRADO DE DATOS SENSIBLES
   Se aplicará cifrado simétrico (AES_256) sobre datos personales de la tabla Persona:
   - DNI
   - Email
   - CVU / CBU

========================================================================================= */

PRINT '--- Creando llaves de cifrado ---';

-- Crear MASTER KEY (solo una vez)
IF NOT EXISTS 
    (SELECT *
    FROM sys.symmetric_keys
    WHERE name LIKE '%DatabaseMasterKey%')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'ClaveFuerte@2024';
END
GO

-- Crear CERTIFICADO
IF NOT EXISTS 
    (SELECT *
    FROM sys.certificates
    WHERE name = 'CertificadoSeguridad')
BEGIN
    CREATE CERTIFICATE CertificadoSeguridad
    WITH SUBJECT = 'Cifrado de datos personales en Consorcio.Persona';
END
GO

-- Crear LLAVE SIMÉTRICA con AES_256
IF NOT EXISTS
    (SELECT *
    FROM sys.symmetric_keys
    WHERE name = 'LlaveCifrado')
BEGIN
    CREATE SYMMETRIC KEY LlaveCifrado
    WITH ALGORITHM = AES_256
    ENCRYPTION BY CERTIFICATE CertificadoSeguridad;
END
GO

PRINT '--- Aplicando cifrado sobre tabla Persona ---';

-- Agregamos columnas cifradas si no existen
IF COL_LENGTH('Consorcio.Persona', 'DNI_Encriptado') IS NULL
    ALTER TABLE Consorcio.Persona 
    ADD DNI_Encriptado VARBINARY(MAX);
IF COL_LENGTH('Consorcio.Persona', 'Email_Encriptado') IS NULL
    ALTER TABLE Consorcio.Persona
    ADD Email_Encriptado VARBINARY(MAX);
IF COL_LENGTH('Consorcio.Persona', 'CVU_Encriptado') IS NULL
    ALTER TABLE Consorcio.Persona
    ADD CVU_Encriptado VARBINARY(MAX);
GO

-- Ciframos los datos
OPEN SYMMETRIC KEY LlaveCifrado DECRYPTION BY CERTIFICATE CertificadoSeguridad;

UPDATE Consorcio.Persona
SET DNI_Encriptado   = EncryptByKey(Key_GUID('LlaveCifrado'), CAST(DNI AS NVARCHAR(20))),
    Email_Encriptado = EncryptByKey(Key_GUID('LlaveCifrado'), CAST(Email AS NVARCHAR(200))),
    CVU_Encriptado   = EncryptByKey(Key_GUID('LlaveCifrado'), CAST(CVU_CBUPersona AS NVARCHAR(30)));

CLOSE SYMMETRIC KEY LlaveCifrado;
GO

PRINT '--- Datos personales cifrados correctamente ---';

-- Creamos una vista que "desencripta" los campos para lectura controlada.

-- IMPORTANTE: asegurar que solo los roles adecuados tengan SELECT sobre esta vista.

IF OBJECT_ID('Consorcio.vw_PersonasLegibles') IS NOT NULL
    DROP VIEW Consorcio.vw_PersonasLegibles;
GO

CREATE VIEW Consorcio.vw_PersonasLegibles
AS
SELECT 
    p.id,
    p.nombre,
    CONVERT(VARCHAR, DecryptByKeyAutoCert(CERT_ID('CertificadoSeguridad'), NULL, DNI_Encriptado)) AS DNI,
    CONVERT(VARCHAR, DecryptByKeyAutoCert(CERT_ID('CertificadoSeguridad'), NULL, Email_Encriptado)) AS Email,
    CONVERT(VARCHAR, DecryptByKeyAutoCert(CERT_ID('CertificadoSeguridad'), NULL, CVU_Encriptado)) AS CVU
FROM Consorcio.Persona p;
GO

GRANT SELECT ON Consorcio.vw_PersonasLegibles TO AdministrativoGeneral, AdministrativoOperativo, Sistemas;
GO




/* =========================================================================================
   POLÍTICA DE BACKUP Y RECUPERACIÓN
========================================================================================= */



PRINT '--- Definiendo política de backup ---';

-- BACKUP COMPLETO (Semanal)

BACKUP DATABASE Com5600G11
TO DISK = 'D:\Backups\Com5600G11_Full.bak'
WITH INIT, NAME = 'Backup completo semanal - Com5600G11',
     COMPRESSION, STATS = 10;


-- BACKUP DIFERENCIAL (Diario)

BACKUP DATABASE Com5600G11
TO DISK = 'D:\Backups\Com5600G11_Diff.bak'
WITH DIFFERENTIAL, NAME = 'Backup diario diferencial - Com5600G11',
     COMPRESSION, STATS = 10;


-- BACKUP DE LOG DE TRANSACCIONES (Cada 4 horas)

BACKUP LOG Com5600G11
TO DISK = 'D:\Backups\Com5600G11_Log.trn'
WITH NOINIT, NAME = 'Backup de logs - cada 4 horas',
     STATS = 5;

PRINT '--- Backups configurados correctamente ---';

/*
    DOCUMENTACIÓN DE POLÍTICA DE RESPALDO:

- Backup completo: cada domingo 00:00 hs
- Backup diferencial: todos los días 02:00 hs
- Backup de logs: cada 4 horas
- RPO (Recovery Point Objective): 4 horas
- RTO (Recovery Time Objective): 2 horas
- Responsable: Rol “Sistemas”
- Almacenamiento secundario: NAS corporativo + copia en nube semanal
- Verificación automática: SQL Server Agent Job con verificación HASHCHECK

Los respaldos se almacenan en D:\Backups\ y se replican a \\NAS\AdminDB\RespaldoMensual
*/

PRINT '--- Fin de script de seguridad y cifrado ---';


END;
GO

-- EJEMPLO DE INVOCACIÓN:
-- EXEC Operaciones.sp_SeguridadCifrado;
